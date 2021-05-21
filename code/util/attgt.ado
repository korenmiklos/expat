program attgt, eclass
	syntax varlist [if] [in], treatment(varname) [aggregate(string)] [absorb(varlist)] [pre(integer 2)] [post(integer 2)] [notyet] [debug]
	marksample touse
	** First determine outcome and xvars
	gettoken y xvar:varlist	

	* boostrap
	local B 20

	* read method of aggregation
	if ("`aggregate'"=="") {
		local aggregate gt
	}
	assert inlist("`aggregate'", "gt", "g", "t", "ge", "e", "att")
	* read panel structure
	xtset
	local i = r(panelvar)
	local time = r(timevar)
	markout `touse' `i' `time' `treatment'

	tempvar group _alty_ _y_ flip
	tempname b v att
	quietly egen `group' = min(cond(`treatment', `time'-1, .)) if `touse', by(`i')
	quietly summarize `time'
	local min_time = r(min)
	
	* build fixed effects to include
	* user fixed effects have to be interacted with `post'
	local a i
	if ("`absorb'"!="") {
		foreach word in `absorb' {
			local a "`a' `post'##`word'"
		}
	}
	else {
		local a `i' `post'
	}

	* estimate ATT(g,t) as eq 2.6 in https://pedrohcgs.github.io/files/Callaway_SantAnna_2020.pdf
	quietly levelsof `group' if `touse', local(gs)
	quietly levelsof `time' if `touse', local(ts)

	* create design matrix
	foreach g in `gs' {
		foreach t in `ts' {
		if (`g'!=`t') & (`g'>`min_time') {
			* within (g,t), panel has to be balanced
			mata: st_local("leadlag1", lead_lag(`g', `t'))
			mata: st_local("leadlag2", lead_lag(`t', `g'))
			local timing (`time'==`g' & `leadlag1'.`time'==`t') | (`time'==`t' & `leadlag2'.`time'==`g')

			local treated (`group'==`g') & (`timing')
			if ("`tyet'"=="") {
				* never treated
				local control missing(`group') & (`timing')
			}
			else {
				* not yet treated
				local control (missing(`group') | (`group' >= max(`g', `t'))) & (`timing')
			}
			quietly count if `treated' & `touse'
			local n_treated = r(N)/2
			quietly count if `control' & `touse'
			local n_control = r(N)/2
			local n_`g'_`t' = `n_treated'

			tempvar treated_`g'_`t' control_`g'_`t'
			quietly generate `treated_`g'_`t'' = cond(`time'==`t', +1/`n_treated', -1/`n_treated') if `treated' & `touse'
			quietly generate `control_`g'_`t'' = cond(`time'==`t', +1/`n_control', -1/`n_control') if `control' & `touse'
		}
		}
	}

	if ("`aggregate'"=="e") {
		forvalues enumeric = -`pre'/`post' {
			mata: st_local("e", minus(`enumeric'))
			display "`e' `enumeric'"
			tempvar wte_`e' wce_`e'
			quietly generate `wte_`e'' = 0
			quietly generate `wce_`e'' = 0
			foreach g in `gs' {
				foreach t in `ts' {
				if (`g'!=`t') & (`g'>`min_time') {
					quietly replace `wte_`e'' = `wte_`e'' + `treated_`g'_`t'' if `t'-`g'==`enumeric' & !missing(`treated_`g'_`t'') & `touse'
					quietly replace `wce_`e'' = `wce_`e'' + `control_`g'_`t'' if `t'-`g'==`enumeric' & !missing(`control_`g'_`t'') & `touse'
				}
				}
			}
		if ("`debug'"!="") {
			display "`e'"
			tabulate `wte_`e'', missing
			tabulate `wce_`e'', missing
		}
		}
	}
	if ("`aggregate'"=="gt") {
			foreach g in `gs' {
				foreach t in `ts' {
				if (`g'!=`t') & (`g'>`min_time') {
					local tweights `tweights' treated_`g'_`t'
					local cweights `cweights' control_`g'_`t'
				}
				}
			}
	}


	* aggregate across known weights
	quietly generate `_alty_' = .
	quietly generate `_y_' = .
	quietly generate byte `flip' = 0
	local nw : word count `tweights'
	forvalues n = 1/`nw' {
		local tw : word `n' of `tweights'
		local cw : word `n' of `cweights'

		mata: sum_product("co", "`y' ``cw''")
		mata: sum_product("tr", "`y' ``tw''")
		matrix `att' = `tr' - `co'

		* wild bootstrap with Rademacher weights requires flipping the error term
		quietly replace `_alty_' = 2*`tr' - `y' if ``tw'' >0 & !missing(``tw'') & `touse'

		* try iid wild bootstrsap
		forvalues i = 1/`B' {
			quietly replace `flip' = cond(uniform()<0.5, 1, 0) if `touse' & !missing(`u')
			quietly replace `_y_' = cond(`flip', `_alty_', `y') if `touse' & !missing(`u')
			mata: sum_product("_tr_", "`_y_' ``tw''")
			display "`=`_tr_'-`co''"
		}

		matrix `b' = nullmat(`b'), `att'
		matrix `v' = nullmat(`v'), 0.0
		local colname `colname' `tw'
	}
	matrix `v' = diag(`v')
	matrix colname `b' = `colname'
	*matrix coleq   `b' = `eqname'
	matrix colname `v' = `colname'
	*matrix coleq   `v' = `eqname'
	matrix rowname `v' = `colname'
	*matrix roweq   `v' = `eqname'

	ereturn post `b' `v'
	ereturn local cmd csadid
	ereturn local cmdline csadid `0'
	display "Callaway Sant'Anna (2021)"
	ereturn display

end

mata:
string scalar lead_lag(real scalar g, real scalar t)
{
	if (t > g) {
		return("F" + strofreal(t - g))
	}
	else {
		return("L" + strofreal(g - t))
	}
}

string scalar minus(real scalar t)
{
	if (t >= 0) {
		return(strofreal(t))
	}
	else {
		return("m" + strofreal(-t))
	} 
}

void sum_product(string scalar output, string matrix vars)
{
	X = 0
	st_view(X, ., vars, 0)
	st_local(output, strofreal(colsum(X[1...,1] :* X[1...,2])))
}
end