clear all
here
local here = r(here)

use "`here'/temp/analysis_sample.dta", clear

local LHS lnL lnQL TFP_cd RperK exporter import_capital import_material export_same_country import_capital_same_country import_material_same_country
local dummies teaor08_2d##year
local treatments foreign foreign_hire has_expat
local options keep(`treatments') tex(frag) dec(3)  nocons nonotes addtext(Ind-year FE, YES)

local fmode replace
foreach Y of var `LHS' {
	reghdfe `Y' `treatments', a(`dummies') cluster(originalid)
	outreg2 using "`here'/output/table/cross_section.tex", `fmode' `options'
	local fmode append
}
