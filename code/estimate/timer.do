clear all
* find root folder
here
local here = r(here)

cap log close
log using "`here'/output/timer.log", text replace

use "`here'/temp/analysis_sample.dta", clear
net install csdid, from ("https://raw.githubusercontent.com/friosavila/csdid_drdid/main/code/") replace

tab first_year_foreign, missing
mvencode first_year_foreign, mv(0)

timer on 1
attgt lnQ if ever_foreign & year > 1990 & year < 2017, treatment(foreign) aggregate(e) pre(4) post(4) reps(20) notyet
timer off 1

timer on 2
csdid lnQ if ever_foreign & year > 1990 & year < 2017, ivar(frame_id_numeric) time(year) gvar(first_year_foreign) method(reg) notyet //saverif("csdid_example") replace
estat event, window (-4 4)
timer off 2

timer on 3
attgt lnQ if ever_foreign & year > 1990 & year < 2017, treatment(foreign) aggregate(att) reps(20) notyet
timer off 3

timer on 4
csdid lnQ if ever_foreign & year > 1990 & year < 2017, ivar(frame_id_numeric) time(year) gvar(first_year_foreign) method(reg) notyet //wboot saverif("csdid_example") replace
estat simple
timer off 4

timer on 5
csdid lnQ if ever_foreign & year > 1990 & year < 2017, ivar(frame_id_numeric) time(year) gvar(first_year_foreign) agg(simple) method(reg) notyet //wboot saverif("csdid_example") replace
timer off 5

timer on 6
csdid lnQ if ever_foreign & year > 1990 & year < 2017, ivar(frame_id_numeric) time(year) gvar(first_year_foreign) agg(simple) method(reg) notyet wboot //saverif("csdid_example") replace
timer off 6

timer on 7
csdid lnQ if ever_foreign & year > 1990 & year < 2017, ivar(frame_id_numeric) time(year) gvar(first_year_foreign) method(reg) notyet //wboot saverif("csdid_example") replace
estat simple
estat event, window (-4 4)
timer off 7

di "comparisons"
di "attgt - event time 4 year window"
timer list 1
di "csdid - event time 4 year window"
timer list 2
di "attgt - att"
timer list 3
di "csdid - att (estat method)"
timer list 4
di "csdid - att (agg method)"
timer list 5
di "csdid - att (agg method with wboot)"
timer list 6
di "csdid - att and event time (estat method)"
timer list 7

*csdid lnQ if ever_foreign, ivar(frame_id_numeric) time(year) gvar(first_year_foreign) method(reg) notyet
*capture noisily estat simple

*di _rc
*if _rc == 130 {
*	estat event
*	timer off 3

*	timer list 1
*	timer list 2
*	timer list 3
*}

log close
