************
* SCRIPT: 6_tables.do
* PURPOSE: Create LaTeX tables from the outputted results
************

* Preamble (unnecessary when executing run.do)
do "$Driving/scripts/programs/_config.do"

************
* Code begins
************

clear
set more off
tempfile t table male_female

local reg_settings "parentheses(stderr) asterisk(5 1) sigfig(3)"
local texsave_settings "replace autonumber nofix"

local fn_bracket "Robust, bias-corrected 95\% confidence intervals are reported in brackets."
local fn_asterisk "A */** indicates significance at the 5\%/1\% level using conventional inference."
local fn_familyp "Family-wise \(p\)-values, reported in braces, adjust for the number of outcome variables in each family and for the number of subgroups."

local fn_col2_ols "Column (2) reports OLS estimates from a model employing a bandwidth of 24 months and reports robust standard errors in parentheses."
local fn_col3_mse "Column (3) reports MSE-optimal estimates and reports robust, bias-corrected 95\% confidence intervals in brackets."


* Data tables for Add Health, MDA laws, and ICD codes were created manually
copy "$Driving/data/add_health/appendix_data_addhealth.tex" "$Driving/results/tables/appendix_data_addhealth.tex", replace
copy "$Driving/data/mda/appendix_data_mda.tex" "$Driving/results/tables/appendix_data_mda.tex", replace
copy "$Driving/data/icd_codes/appendix_data_icd_codes.tex" "$Driving/results/tables/appendix_data_icd_codes.tex", replace


* Standardized cleaning of variable names
program drop _all
program clean_varnames 

	local indent "\ \ \ \"

	* Mortality
	replace `1' = "All causes" if `1'=="any"
	replace `1' = "External causes" if `1'=="external"
	replace `1' = "`indent' Motor vehicle accident" if `1'=="MVA"
	replace `1' = "`indent' Suicide and accident" if `1'=="sa"
	replace `1' = "`indent' `indent' Firearm" if `1'=="sa_firearms" | `1'=="firearms"
	replace `1' = "`indent' `indent' Poisoning" if `1'=="sa_poisoning" | `1'=="poisoning"
	replace `1' = "`indent' `indent' `indent' Drug overdose" if `1'=="sa_poisoning_subst" | `1'=="poisoning_subst"
	replace `1' = "`indent' `indent' `indent' Carbon monoxide and other gases" if `1'=="sa_poisoning_gas" | `1'=="poisoning_gas"
	replace `1' = "`indent' `indent' Drowning" if `1'=="sa_drowning" | `1'=="drowning"
	replace `1' = "`indent' `indent' Other" if `1'=="sa_other" | `1'=="other"
	replace `1' = "`indent' Homicide" if `1'=="homicide"
	replace `1' = "`indent' Other external" if `1'=="extother"
	replace `1' = "Internal causes" if `1'=="internal"
	
	* Add Health
	replace `1' = "Has driver's license" if `1'=="DriverLicense"
	replace `1' = "Miles driven (miles/yr) (baseline)" if `1'=="VehicleMiles_150"
	replace `1' = "Miles driven (miles/yr) (alternate)" if `1'=="VehicleMiles_265"
	
	* Heterogeneity	
	replace `1' = subinstr(`1',"WhiteMale",      "White male",     1)
	replace `1' = subinstr(`1',"WhiteFemale",    "White female",   1)
	replace `1' = subinstr(`1',"NonwhiteMale",   "Nonwhite male",  1)
	replace `1' = subinstr(`1',"NonwhiteFemale", "Nonwhite female",1)
	
	replace `1' = "Full sample" if strpos(`1',"All") & !strpos(`1',"causes")
	
	replace `1' = "`indent' MDA is 16"   if `1'=="mda192"
	replace `1' = "`indent' MDA is not 16"   if `1'=="mda_not192"

	replace `1' = "January"   if `1'=="birmonth1" | `1'=="birmonth1_Female"
	replace `1' = "February"  if `1'=="birmonth2" | `1'=="birmonth2_Female"
	replace `1' = "March"     if `1'=="birmonth3" | `1'=="birmonth3_Female"
	replace `1' = "April"     if `1'=="birmonth4" | `1'=="birmonth4_Female"
	replace `1' = "May"       if `1'=="birmonth5" | `1'=="birmonth5_Female"
	replace `1' = "June"      if `1'=="birmonth6" | `1'=="birmonth6_Female"
	replace `1' = "July"      if `1'=="birmonth7" | `1'=="birmonth7_Female"
	replace `1' = "August"    if `1'=="birmonth8" | `1'=="birmonth8_Female"
	replace `1' = "September" if `1'=="birmonth9" | `1'=="birmonth9_Female"
	replace `1' = "October"   if `1'=="birmonth10" | `1'=="birmonth10_Female"
	replace `1' = "November"  if `1'=="birmonth11" | `1'=="birmonth11_Female"
	replace `1' = "December"  if `1'=="birmonth12" | `1'=="birmonth12_Female"
	
end

* Destring with a sigfig() option [code taken from regsave_tbl] - used for formatting decimals in the tables
program gtostring

	syntax varlist, sigfig(numlist integer min=1 max=1 >=1 <=20) [force replace gen(passthru)]
	
	if "`sigfig'"!=""   {
		if "`format'"!="" {
			di as error "Cannot specify both the sigfig and format options."
			exit 198					
		}
		local format "%18.`sigfig'gc"
	}
	
	tostring `varlist', `force' `replace' format(`format') `gen'

	qui foreach table of varlist `varlist' {
	
		cap confirm string var `table'
		if !_rc {

			tempvar tmp diff tail numast intvar orig lngth
			
			gen `intvar' = `table'=="."
			gen `orig' = `table'
					
			gen     `tmp' = subinstr(`table',".","",1)
			replace `tmp' = subinstr(`tmp',".","",1)
			replace `tmp' = subinstr(`tmp',"(","",1)
			replace `tmp' = subinstr(`tmp',")","",1)
			replace `tmp' = subinstr(`tmp',"[","",1)
			replace `tmp' = subinstr(`tmp',"]","",1)
			replace `tmp' = subinstr(`tmp',"*","",.)
			replace `tmp' = subinstr(`tmp',"-","",.)
			
			* Remove leading zero's following the decimal point (they don't count towards sig figs)
			gen `lngth' = length(`tmp')
			summ `lngth'
			forval x = `r(max)'(-1)1 {
				replace `tmp' = subinstr(`tmp', "0"*`x',"",1) if substr(`tmp',1,`x')=="0"*`x'
			}
			
			gen `diff' = `sigfig' - length(`tmp')
			gen `tail' = "0"*`diff'
			gen `numast' = length(`table') - length(subinstr(`table', "*", "", .))

			* Leading zero's
			replace `table' = "0"  + `table' if substr(`table',1,1)=="."
			replace `table' = subinstr(`table',"-.","-0.",1)   if substr(`table',1,2)=="-."
			replace `table' = subinstr(`table',"(.","(0.",1)   if substr(`table',1,2)=="(."
			replace `table' = subinstr(`table',"[.","[0.",1)   if substr(`table',1,2)=="[."
			replace `table' = subinstr(`table',"(-.","(-0.",1) if substr(`table',1,3)=="(-."
			replace `table' = subinstr(`table',"[-.","[-0.",1) if substr(`table',1,3)=="[-."

			* Trailing zero's (note: asterisks can't occur with ")" or "]", because those are only for stderrs/tstats/ci)
			replace `table' = `table' +       `tail'                                                 if strpos(`table',".")!=0 & strpos(`table',"*")==0 & substr(`table',1,1)!="(" & substr(`table',1,1)!="[" & !mi(`tail')
			replace `table' = `table' + "." + `tail'                                                 if strpos(`table',".")==0 & strpos(`table',"*")==0 & substr(`table',1,1)!="(" & substr(`table',1,1)!="[" & !mi(`tail')
			
			replace `table' = substr(`table',1,length(`table')-`numast') +       `tail' + "*"*`numast'     if strpos(`table',".")!=0 & strpos(`table',"*")!=0 & substr(`table',1,1)!="(" & substr(`table',1,1)!="[" & !mi(`tail')
			replace `table' = substr(`table',1,length(`table')-`numast') + "." + `tail' + "*"*`numast'     if strpos(`table',".")==0 & strpos(`table',"*")!=0 & substr(`table',1,1)!="(" & substr(`table',1,1)!="[" & !mi(`tail')
			
			replace `table' = subinstr(`table',")",`tail'+")",1) if strpos(`table',".")!=0 & substr(`table',1,1)=="("
			replace `table' = subinstr(`table',"]",`tail'+"]",1) if strpos(`table',".")!=0 & substr(`table',1,1)=="["
			
			* Variables that were stored as integers (or missing) are exact and shouldn't be altered
			replace `table' = `orig' if `intvar'==1
			replace `table' = "" if `table'=="."
					
			drop `tmp' `diff' `tail' `numast' `intvar' `orig'
		}
	}
end

********************************************************
* Annual US deaths per 100,000 population, 1983-2014
********************************************************
local vars "cod_any cod_external cod_internal cod_MVA cod_homicide cod_extother cod_sa cod_sa_firearms cod_sa_poisoning cod_sa_poisoning_subst cod_sa_poisoning_gas cod_sa_drowning cod_sa_other"

local replace replace
local run_male_female = 0
qui foreach scenario in "Female" "Male" "All" {

* Main data extended to ages 10-29
use "$Driving/data/mortality/derived/sex_agegroup_8314.dta", clear

* Subset the data down by gender	
if "`scenario'"=="Male"           keep if male==1
else if "`scenario'"=="Female"    keep if male==0
else if "`scenario'"=="All"      assert !mi(male)
compress 
	
* Collapse over age group
collapse (sum) `vars' pop, by(agegroup) fast
		
* Death rates per 100,000
foreach y in `vars' {
	replace `y'=100000*`y'/pop		
}
drop pop

reshape long cod_, i(agegroup) j(cod) str

preserve
	keep if agegroup==1
	save "`t'", replace
restore, preserve
	forval x = 2/4 {
		keep if agegroup==`x'
		ren cod_ cod_`x'
		merge 1:1 cod using "`t'", assert(match) nogenerate
		save "`t'", replace
		restore, preserve
	}
restore, not

* Label variables
use "`t'", clear
label var cod_ "Ages 10--14"
label var cod_2 "Ages 15--19"
label var cod_3 "Ages 20--24"
label var cod_4 "Ages 25--29"

tostring cod_*, force replace format(%5.2fc)
sortobs cod, values("any" "internal" "external" "MVA" "sa" "sa_firearms" "sa_poisoning" "sa_poisoning_subst" "sa_poisoning_gas" "sa_drowning" "sa_other" "homicide" "extother")

if `run_male_female'==1 append using "`male_female'"
save "`male_female'", replace
local run_male_female = 1
}

clean_varnames cod
drop agegroup
order cod cod_ cod_2 cod_3 cod_4
label var cod "Cause of death"

* Create panels
ingap 1 14 27
replace cod = "A. All" in 1 if mi(cod)
replace cod = "B. Males" in 15 if mi(cod)
replace cod = "C. Females" in 29 if mi(cod)
ingap 14 28, after

* Output table
local title "Annual US deaths per 100,000 population, 1983--2014"
local fn "Notes: Death counts come from the National Vital Statistics. Population estimates come from the Surveillance, Epidemiology, and End Results (SEER) Program."

texsave using "$Driving/results/tables/appendix_data_mortality.tex", varlabels marker("tab:appendix_data_mortality")  size(small) bold("A. " "B. " "C. ") title("`title'") hlines(1 16 31) footnote("`fn'") `texsave_settings'

*******************************************************************
*  Effect of driving eligibility on teenage driving and mortality
*******************************************************************

* Main mortality RD estimates
use "$Driving/results/intermediate/mortality_rd.dta", clear

* Add Health RD estimates
append using "$Driving/results/intermediate/addhealth_rd.dta"

* For rdrobust, we will use the point estimate from "conventional" estimate and inference from "robust" bias-correction
keep if inlist(var,"Robust")
replace coef = b_conv if var=="Robust"

* Variable formatting
gtostring ci_lower ci_upper, force replace sigfig(3)
gen ci = "[" + ci_lower + ", " + ci_upper + "]"

* Adjusted p-values
merge 1:1 var y rdspec scenario using "$Driving/results/intermediate/adjustedp.dta", nogenerate keep(match master)

* Remove "cod_" from the variable y
replace y = subinstr(y,"cod_","",1)

preserve

local run_no = 0
qui foreach y in extother homicide sa_other sa_drowning sa_poisoning_gas sa_poisoning_subst sa_poisoning sa_firearms sa MVA external internal any VehicleMiles_265 VehicleMiles_150 DriverLicense {

	* MSE-optimal: full sample
	regsave_tbl if y=="`y'" & rdspec=="rdrobust" & scenario=="All", name(full) `reg_settings'
	keep if inlist(var,"Robust_coef","ci","psidak")
	replace var = "`y'_coef" if var=="Robust_coef"
	replace var = "`y'_ci" if var=="ci"
	replace var = "`y'_adjp" if var=="psidak"

	if `run_no'==1 append using "`table'"
	gen sortorder = _n
	local run_no = 1	
	save "`table'", replace
	restore, preserve

	* MSE-optimal: males
	regsave_tbl if y=="`y'" & rdspec=="rdrobust" & scenario=="Male", name(male) `reg_settings'
	keep if inlist(var,"Robust_coef","ci","psidak")
	replace var = "`y'_coef" if var=="Robust_coef"
	replace var = "`y'_ci" if var=="ci"
	replace var = "`y'_adjp" if var=="psidak"
	merge 1:1 var using "`table'", assert(match using) nogenerate
	save "`table'", replace
	restore, preserve
	
	* MSE-optimal: females
	regsave_tbl if y=="`y'" & rdspec=="rdrobust" & scenario=="Female", name(female) `reg_settings'
	keep if inlist(var,"Robust_coef","ci","psidak")
	replace var = "`y'_coef" if var=="Robust_coef"
	replace var = "`y'_ci" if var=="ci"
	replace var = "`y'_adjp" if var=="psidak"
	merge 1:1 var using "`table'", assert(match using) nogenerate
	save "`table'", replace
	restore, preserve

	* Mean (same for OLS and rdrobust)
	keep if y=="`y'" & rdspec=="rdrobust" & inlist(scenario,"All","Male","Female")
	keep mean_y scenario
	ren mean_y mean_y_
	gen var = "`y'_coef"
	reshape wide mean_y_, i(var) j(scenario) str
	merge 1:1 var using "`table'", assert(match using) nogenerate
	sort sortorder
	drop sortorder
	save "`table'", replace
	restore, preserve
}

restore, not
use "`table'", clear

drop if inlist(var,"DriverLicense_adjp","VehicleMiles_150_adjp","VehicleMiles_265_adjp")

***
* Table formatting
***

order var mean_y_All full mean_y_Male male mean_y_Female female
gtostring mean_y*, force replace sigfig(3)
replace mean_y_All    = "" if mean_y_All=="."
replace mean_y_Male   = "" if mean_y_Male=="."
replace mean_y_Female = "" if mean_y_Female=="."

foreach v in male female full {
	replace `v' = "\(<\)0.0001" if real(`v')<0.0001 & strpos(var,"adjp")
	replace `v' = "\(<\)0.001" if real(`v')<0.001 & strpos(var,"adjp")	
	replace `v' = "\(<\)0.01" if real(`v')<0.01 & strpos(var,"adjp")	
	replace `v' = "\{"+ `v' +"\}" if strpos(var,"adjp")
	label var `v' "RD"
}

replace var = "" if strpos(var,"_ci")
replace var = "" if strpos(var,"_adjp")
replace var = subinstr(var,"_coef","",1)
clean_varnames var
replace var = "\addlinespace[1ex] " + var if !mi(var)

* Create panels
ingap 1 7
replace var = "A. Driving" in 1 if mi(var)
replace var = "B. Mortality" in 8 if mi(var)

* Label variables
label var full "RD"
label var male "RD"
label var female "RD"
label var mean_y_All "Mean"
label var mean_y_Male "Mean"
label var mean_y_Female "Mean"
label var var "Outcome variable"

* Output table
local title "Effect of driving eligibility on teenage driving and mortality"
local headerlines "& \multicolumn{2}{c}{Full sample} & \multicolumn{2}{c}{Male} & \multicolumn{2}{c}{Female}" "\cmidrule(lr){2-3} \cmidrule(lr){4-5} \cmidrule(lr){6-7}"
local fn "Notes: The driving estimates in Panel A are based on weighted responses to the 1995--1996 Add Health surveys. The mortality estimates in Panel B, which are measured in deaths per 100,000 person-years, are based on death counts from the 1983--2014 National Vital Statistics and population data from the 1983--2014 Surveillance, Epidemiology, and End Results (SEER) Program.  Columns (1), (3), and (5) report means of the dependent variable one year before reaching the minimum driving age (MDA). Columns (2), (4), and (6) report MSE-optimal estimates of \(\beta\) from equation (\ref{E - RD1}). `fn_bracket' `fn_asterisk' `fn_familyp'"

texsave using "$Driving/results/tables/rd_mortality.tex", varlabels marker("tab:rd_mortality") size(scriptsize) align(lCcCcCc) headerlines("`headerlines'") bold("A. " "B. ") title("`title'") hlines(1 8) footnote("`fn'", size(scriptsize)) `texsave_settings'

******************************************************************
* Effect of driving eligibility on female suicides and accidents   
******************************************************************

* RD estimates for female suicides and accidents
use "$Driving/results/intermediate/mortality_rd_suicide_acct.dta", clear
keep if scenario=="Female" & rdspec=="rdrobust"
drop scenario

* For rdrobust, we will use the point estimate from "conventional" estimate and inference from "robust" bias-correction
replace coef = b_conv if var=="Robust"

* Variable formatting
gtostring ci_lower ci_upper, force replace sigfig(3)
gen ci = "[" + ci_lower + ", " + ci_upper + "]"

replace y = subinstr(y,"cod_","",1)

tempfile table_acct table_suicide table_sa

preserve

foreach t in "acct" "suicide" "sa" {
local run_no = 0
qui foreach y in `t' `t'_firearms `t'_poisoning `t'_poisoning_subst `t'_poisoning_gas `t'_drowning `t'_other {

	* MSE-optimal
	regsave_tbl if y=="`y'" & rdspec=="rdrobust", name(rdrobust) `reg_settings'
	keep if inlist(var,"Robust_coef","ci")
	replace var = "`y'" if var=="Robust_coef"
	replace var = "`y'_ci" if var=="ci"
	if `run_no'==1 append using "`table_`t''"
	gen sortorder = _n
	local run_no = 1
	save "`table_`t''", replace
	restore, preserve

	* Mean
	keep if y=="`y'"
	keep mean_y
	gen var = "`y'"
	merge 1:1 var using "`table_`t''", assert(match using) nogenerate
	sort sortorder
	drop sortorder
	save "`table_`t''", replace
	restore, preserve
}
}

***
* Table formatting
***

restore, not
use "`table_acct'", clear
rename (mean_y rdrobust) (mean_y_acct rdrobust_acct)
replace var = "total" if var=="acct"
replace var = "total_ci" if var=="acct_ci"
replace var = subinstr(var,"acct_","",1)
save "`table'", replace

use "`table_suicide'", clear
rename (mean_y rdrobust) (mean_y_suicide rdrobust_suicide)
replace var = "total" if var=="suicide"
replace var = "total_ci" if var=="suicide_ci"
replace var = subinstr(var,"suicide_","",1)
merge 1:1 var using "`table'", assert(match) nogenerate
save "`table'", replace

use "`table_sa'", clear
rename (mean_y rdrobust) (mean_y_sa rdrobust_sa)
replace var = "total" if var=="sa"
replace var = "total_ci" if var=="sa_ci"
replace var = subinstr(var,"sa_","",1)
merge 1:1 var using "`table'", assert(match) nogenerate

order var mean_y_suicide rdrobust_suicide mean_y_acct rdrobust_acct mean_y_sa rdrobust_sa
gtostring mean_y*, force replace sigfig(3)

sortobs var, values("total" "total_ci" "firearms" "firearms_ci" "poisoning" "poisoning_ci" "poisoning_subst" "poisoning_subst_ci" "poisoning_gas" "poisoning_gas_ci" "drowning" "drowning_ci" "other" "other_ci")
replace var = "Total suicides/accidents" if var=="total"
replace var = "" if strpos(var,"_ci")
clean_varnames var
replace var = subinstr(var,"\ \ \ \","",1)

* Label variables
foreach v in suicide acct sa {
	label var rdrobust_`v' "RD"
	label var mean_y_`v' "Mean"
}
label var var "Cause of death"

* Output table
local title "Effect of driving eligibility on female suicides and accidents"
local headerlines "& \multicolumn{2}{c}{Female suicides} & \multicolumn{2}{c}{Female accidents} & \multicolumn{2}{c}{Female suicides and accidents}"  "\cmidrule(lr){2-3} \cmidrule(lr){4-5}  \cmidrule(lr){6-7}"
local fn "Notes: This table reports MSE-optimal estimates of \(\beta\) from equation (\ref{E - RD1}). The dependent variable is deaths per 100,000 person-years. Columns (1), (3), and (5) report means of the dependent variable one year before reaching the minimum driving age (MDA). Columns (5)--(6) reproduce the numbers reported in Columns (5)--(6) of Table \ref{tab:rd_mortality}. The estimates in Columns (2) and (4) do not necessarily add up to the estimate in Column (6) because bandwidths are not constant across different regressions. `fn_bracket' `fn_asterisk' Familywise \(p\)-values are not reported in this exploratory analysis."
local model rdrobust
texsave var mean_y_suicide `model'_suicide mean_y_acct `model'_acct mean_y_sa `model'_sa using "$Driving/results/tables/rd_mortality_sa_female.tex", varlabels marker("tab:rd_mortality_sa_mse") headerlines("`headerlines'") title("`title'") footnote("`fn'") landscape align(lCcCcCc) size(small) `texsave_settings'

**********************************************************************
* Effect of driving eligibility on mortality for different subgroups
**********************************************************************

* Main mortality RD estimates
use "$Driving/results/intermediate/mortality_rd.dta", clear

* For rdrobust, we will use the point estimate from "conventional" estimate and inference from "robust" bias-correction
keep if inlist(var,"1.post","Robust")
replace coef = b_conv if var=="Robust"

* Variable formatting
gtostring ci_lower ci_upper, force replace sigfig(3)
gen ci = "[" + ci_lower + ", " + ci_upper + "]"

* We will use male/female results in two different tables, so create a duplicate
expand 2 if inlist(scenario,"Female","Male"), gen(dup)
replace scenario = "mda_Female" if scenario=="Female" & dup==1
replace scenario = "mda_Male" if scenario=="Male" & dup==1

preserve

local run_no = 0
foreach y in cod_MVA cod_sa_poisoning {
qui foreach scen in "mda_not192_Female" "mda192_Female" "mda_Female" "mda_not192_Male" "mda192_Male" "mda_Male" {
	
	* OLS
	regsave_tbl if scenario=="`scen'" & y=="`y'" & rdspec=="ols", name(ols) `reg_settings'
	keep if inlist(var,"1.post_coef", "1.post_stderr")
	replace var = "`y'_`scen'" if var=="1.post_coef"
	replace var = "`y'_`scen'_ci" if var=="1.post_stderr"
	if `run_no'==1 append using "`table'"
	gen sortorder = _n
	local run_no = 1
	save "`table'", replace
	restore, preserve

	* MSE-optimal
	regsave_tbl if scenario=="`scen'" & y=="`y'" & rdspec=="rdrobust", name(rdrobust) `reg_settings'
	keep if inlist(var,"Robust_coef","ci")
	replace var = "`y'_`scen'" if var=="Robust_coef"
	replace var = "`y'_`scen'_ci" if var=="ci"
	merge 1:1 var using "`table'", assert(match using) nogenerate
	save "`table'", replace
	restore, preserve

	* Mean (same for OLS and rdrobust)
	keep if scenario=="`scen'" & y=="`y'" & rdspec=="ols"
	keep mean_y
	gen var = "`y'_`scen'"
	merge 1:1 var using "`table'", assert(match using) nogenerate	
	sort sortorder
	drop sortorder
	
	save "`table'", replace
	restore, preserve
}
}

restore, not
use "`table'", clear

***
* Table formatting
***

order var mean_y ols rdrobust
tostring mean_y, force replace format(%5.3fc)
replace mean_y = "" if mean_y=="."

gen     table = "MVA" if strpos(var,"cod_MVA")
replace table = "sa_poisoning_subst" if strpos(var,"cod_sa_poisoning_subst")
replace table = "sa_poisoning" if strpos(var,"cod_sa_poisoning") & !strpos(var,"cod_sa_poisoning_subst")
gen mdascen = strpos(var,"mda")!=0
assert !mi(table)
preserve

foreach t in "MVA" "sa_poisoning" {

	keep if table=="`t'"

	replace var = "" if strpos(var,"_ci")

	local indent "\ \ \ \"
	replace var = "`indent' " + var if strpos(var,"cod_MVA_") & !strpos(var,"mda")
	replace var = "`indent' " + var if strpos(var,"cod_sa_poisoning_subst_") & !strpos(var,"mda")
	replace var = "`indent' " + var if strpos(var,"cod_sa_poisoning_") & !strpos(var,"mda")
	
	replace var = subinstr(var,"cod_MVA_","",1)
	replace var = subinstr(var,"cod_sa_poisoning_subst_","",1)
	replace var = subinstr(var,"cod_sa_poisoning_","",1)
	
	* Create panels
	ingap 1 7
	replace var = "Male" in 1 if mi(var)
	replace var = "Female" in 8 if mi(var)

	replace mdascen = 1 in 1
	replace mdascen = 1 in 8

	replace var = "`indent' Full sample" if var=="mda_Male" | var=="mda_Female"
	replace var = subinstr(var,"_Male","",1) if mdascen==1 
	replace var = subinstr(var,"_Female","",1) if mdascen==1 
	clean_varnames var
	
	* Label variables
	label var ols "OLS"
	label var rdrobust "MSE optimal"
	label var mean_y "Mean"
	label var var "Subgroup"
	drop table

	if "`t'"=="MVA" local outcome "motor vehicle fatalities"
	else if "`t'"=="sa_poisoning" local outcome "poisoning deaths"
	local name = lower("`t'")

	* All table have same footnote
	local fn "Notes: This table reports estimates of \(\beta\) from equation (\ref{E - RD1}) for different subgroups. The dependent variable is deaths per 100,000 person-years. Column (1) reports means of the dependent variable one year before reaching the minimum driving age (MDA). `fn_col2_ols' `fn_col3_mse' `fn_asterisk'"
	
	* Heterogeneity by state MDA table
	local title "Effect of driving eligibility on `outcome' by state minimum driving age"
	local headerlines "& & \multicolumn{2}{c}{RD estimate}" "\cmidrule(lr){3-4}"
	texsave var-rdrobust if mdascen==1 using "$Driving/results/tables/rd_subgroup_mda_`name'.tex", varlabels marker("tab:rd_`name'_heterogeneity_mda") headersep(2ex) headerlines("`headerlines'") title("`title'") footnote("`fn'", size(scriptsize)) size(footnotesize) `texsave_settings'	
	
	restore, preserve
}
restore, not

*********************************************************************************************
* Effect of driving eligibility on mortality using different bandwidth selection procedures
*********************************************************************************************

* Mortality RD estimates for robustness checks
use "$Driving/results/intermediate/mortality_rd_robustness.dta", clear
keep if !mi(bwselection)
drop order_poly bw bw_bias

* For rdrobust, we will use the point estimate from "conventional" estimate and inference from "robust" bias-correction
replace coef = b_conv

* Variable formatting
gtostring ci_lower ci_upper, force replace sigfig(3)
replace belowbw=round(belowbw, 1)
replace abovebw=round(abovebw, 1)
gtostring belowbw abovebw, force replace sigfig(1)
gen ci = "[" + ci_lower + ", " + ci_upper + "]"
gen bw= "--" + belowbw + "/+" + abovebw
replace bw= "\(\pm\)" + abovebw if inlist(bwselection, "mserd", "cerrd")

preserve

local run_no = 0
foreach y in sa_poisoning MVA any {
qui foreach scen in "Female" "Male" "All" {

	* MSE-optimal common
	regsave_tbl if scenario=="`scen'" & y=="cod_`y'" & rdspec=="rdrobust" & bwselection=="mserd", name(mserd) `reg_settings'
	
	keep if inlist(var,"Robust_coef","ci","bw")
	replace var = "`y'_`scen'" if var=="Robust_coef"
	replace var = "`y'_`scen'_ci" if var=="ci"
	replace var = "`y'_`scen'_bw" if var=="bw"
	if `run_no'==1 append using "`table'"
	gen sortorder = _n
	local run_no = 1	
	save "`table'", replace
	restore, preserve

	* MSE-optimal twoway
	regsave_tbl if scenario=="`scen'" & y=="cod_`y'" & rdspec=="rdrobust" & bwselection=="msetwo", name(msetwo) `reg_settings'
	keep if inlist(var,"Robust_coef","ci","bw")
	replace var = "`y'_`scen'" if var=="Robust_coef"
	replace var = "`y'_`scen'_ci" if var=="ci"
	replace var = "`y'_`scen'_bw" if var=="bw"
	merge 1:m var using "`table'", assert(match using) nogenerate
	save "`table'", replace
	restore, preserve
	
	* CER-optimal common
	regsave_tbl if scenario=="`scen'" & y=="cod_`y'" & rdspec=="rdrobust" & bwselection=="cerrd", name(cerrd) `reg_settings'
	keep if inlist(var,"Robust_coef","ci","bw")
	replace var = "`y'_`scen'" if var=="Robust_coef"
	replace var = "`y'_`scen'_ci" if var=="ci"
	replace var = "`y'_`scen'_bw" if var=="bw"
	merge 1:m var using "`table'", assert(match using) nogenerate
	save "`table'", replace
	restore, preserve

	* CER-optimal two
	regsave_tbl if scenario=="`scen'" & y=="cod_`y'" & rdspec=="rdrobust" & bwselection=="certwo", name(certwo) `reg_settings'
	keep if inlist(var,"Robust_coef","ci","bw")
	replace var = "`y'_`scen'" if var=="Robust_coef"
	replace var = "`y'_`scen'_ci" if var=="ci"
	replace var = "`y'_`scen'_bw" if var=="bw"
	merge 1:m var using "`table'", assert(match using) nogenerate
	save "`table'", replace
	restore, preserve
	
	* Mean (same for different BW selection methods)
	keep if scenario=="`scen'" & y=="cod_`y'" & bwselection=="mserd"
	keep mean_y
	gen var = "`y'_`scen'"
	merge 1:m var using "`table'", assert(match using) nogenerate	
	sort sortorder
	drop sortorder
	
	save "`table'", replace
	restore, preserve
}	
}

restore, not
use "`table'", clear

***
* Table formatting
***

order var mean_y mserd msetwo cerrd certwo
gtostring mean_y, force replace sigfig(3)
replace mean_y = "" if mean_y=="."

replace var = "" if strpos(var,"_ci")
replace var = "" if strpos(var,"_bw")
replace var = subinstr(var,"MVA_","",1)
replace var = subinstr(var,"sa_poisoning_","",1)
replace var = subinstr(var,"any_","",1)
clean_varnames var
replace var = "\addlinespace[1ex] " + var if !mi(var)

* Create panels
ingap 1 10 19 
replace var = "A. All deaths" in 1 if mi(var)
replace var = "B. Motor vehicle fatalities" in 11 if mi(var)
replace var = "C. Poisoning deaths" in 21 if mi(var)

* Label variables
label var mserd "MSE optimal (1)"
label var msetwo "MSE optimal (2)"
label var cerrd "CER optimal (1)"
label var certwo "CER optimal (2)"
label var mean_y "Mean"
label var var "Subgroup"

* Output table
local title "Effect of driving eligibility on mortality using different bandwidth selection procedures"
local headerlines "& & & \multicolumn{2}{c}{RD estimate}" "\cmidrule(lr){3-6}"
local fn "Notes: The dependent variable is deaths per 100,000 person-years. Column (1) reports means of the dependent variable one year before reaching the minimum driving age (MDA). Columns (2)--(5) report estimates of \(\beta\) from equation (\ref{E - RD1}) using different bandwidths. The MSE-optimal method selects a bandwidth that minimizes the mean squared error (MSE) of the point estimator. The coverage error rate (CER) optimal method selects a bandwidth that minimizes the asymptotic CER of the robust bias-corrected confidence interval.  Column (2) reports estimates from our preferred specification, MSE optimal (1), which selects one common bandwidth on each side of the cutoff. Columns (3)--(5) report estimates using different bandwidth selection procedures: MSE optimal with different bandwidths on each side of the cutoff, CER optimal with one common bandwidth, and CER optimal with different bandwidths on each side of the cutoff. `fn_bracket' The selected bandwidths (rounded to the nearest month) are reported below the confidence interval. `fn_asterisk'"

texsave using "$Driving/results/tables/rd_mortality_altbws.tex", varlabels marker("tab:rd_mortality_altbws") size(scriptsize) align(lCcCcCc) headerlines("`headerlines'") bold("A. " "B. " "C. ") title("`title'") hlines(1 11 21)  footnote("`fn'", size(scriptsize)) `texsave_settings'

****************************************************************************************
* Effect of driving eligibility on mortality using different polynomial approximations
****************************************************************************************

* Mortality RD estimates for robustness checks
use "$Driving/results/intermediate/mortality_rd_robustness.dta", clear
drop if mi(order_poly)

* For rdrobust, we will use the point estimate from "conventional" estimate and inference from "robust" bias-correction
replace coef = b_conv

* Variable formatting
gtostring ci_lower ci_upper, force replace sigfig(3)
gen ci = "[" + ci_lower + ", " + ci_upper + "]"

preserve

local run_no = 0
foreach y in sa_poisoning MVA any {
qui foreach scen in "Female" "Male" "All" {

	* MSE-optimal linear
	regsave_tbl if scenario=="`scen'" & y=="cod_`y'" & rdspec=="rdrobust" & order_poly==1, name(linear) `reg_settings'
	keep if inlist(var,"Robust_coef","ci")
	replace var = "`y'_`scen'" if var=="Robust_coef"
	replace var = "`y'_`scen'_ci" if var=="ci"
	if `run_no'==1 append using "`table'"
	gen sortorder = _n
	local run_no = 1	
	save "`table'", replace
	restore, preserve

	* MSE-optimal quadratic
	regsave_tbl if scenario=="`scen'" & y=="cod_`y'" & rdspec=="rdrobust" & order_poly==2, name(quadratic) `reg_settings'
	keep if inlist(var,"Robust_coef","ci")
	replace var = "`y'_`scen'" if var=="Robust_coef"
	replace var = "`y'_`scen'_ci" if var=="ci"
	merge 1:m var using "`table'", assert(match using) nogenerate
	save "`table'", replace
	restore, preserve
	
	* MSE-optimal cubic
	regsave_tbl if scenario=="`scen'" & y=="cod_`y'" & rdspec=="rdrobust" & order_poly==3, name(cubic) `reg_settings'
	keep if inlist(var,"Robust_coef","ci")
	replace var = "`y'_`scen'" if var=="Robust_coef"
	replace var = "`y'_`scen'_ci" if var=="ci"
	merge 1:m var using "`table'", assert(match using) nogenerate
	save "`table'", replace
	restore, preserve
	
	* Mean (same for different orders of polynomials)
	keep if scenario=="`scen'" & y=="cod_`y'" & order_poly==1
	keep mean_y
	gen var = "`y'_`scen'"
	merge 1:m var using "`table'", assert(match using) nogenerate	
	sort sortorder
	drop sortorder
	
	save "`table'", replace
	restore, preserve
}	
}

restore, not
use "`table'", clear

***
* Table formatting
***

order var mean_y linear quadratic cubic
gtostring mean_y, force replace sigfig(3)
replace mean_y = "" if mean_y=="."

replace var = "" if strpos(var,"_ci")
replace var = "" if strpos(var,"_bw")
replace var = subinstr(var,"MVA_","",1)
replace var = subinstr(var,"sa_poisoning_","",1)
replace var = subinstr(var,"any_","",1)
clean_varnames var
replace var = "\addlinespace[1ex] " + var if !mi(var)

* Create panels
ingap 1 7 13 
replace var = "A. All deaths" in 1 if mi(var)
replace var = "B. Motor vehicle fatalities" in 8 if mi(var)
replace var = "C. Poisoning deaths" in 15 if mi(var)

* Label variables
label var linear "Linear"
label var quadratic "Quadratic"
label var cubic "Cubic"
label var mean_y "Mean"
label var var "Subgroup"

* Output table
local title "Effect of driving eligibility on mortality using different polynomial approximations"
local headerlines "& & & \multicolumn{1}{c}{RD estimate}" "\cmidrule(lr){3-5}"
local fn "Notes: The dependent variable is deaths per 100,000 person-years. Column (1) reports means of the dependent variable one year before reaching the minimum driving age (MDA). Columns (2)--(4) report estimates of \(\beta\) from equation (\ref{E - RD1}) using different polynomial approximations: linear (our preferred specification), quadratic, and cubic. `fn_bracket' `fn_asterisk'"

texsave using "$Driving/results/tables/rd_mortality_polys.tex", varlabels marker("tab:rd_mortality_polys") size(footnotesize) align(lCcCcCc) headerlines("`headerlines'") bold("A. " "B. " "C. ") title("`title'") hlines(1 8 15)  footnote("`fn'", size(scriptsize)) `texsave_settings'

***********************************************************************
* OLS: Effect of driving eligibility on teenage driving and mortality
***********************************************************************

* Main mortality RD estimates
use "$Driving/results/intermediate/mortality_rd.dta", clear

* Add Health RD estimates
append using "$Driving/results/intermediate/addhealth_rd.dta"
replace scenario = "All" if mi(scenario)

keep if inlist(var,"1.post")

* Adjusted p-values
merge 1:1 var y rdspec scenario using "$Driving/results/intermediate/adjustedp.dta", nogenerate keep(match master)

* Remove "cod_" from the variable y
replace y = subinstr(y,"cod_","",1)

preserve

local run_no = 0
qui foreach y in extother homicide sa_other sa_drowning sa_poisoning_gas sa_poisoning_subst sa_poisoning sa_firearms sa MVA external internal any VehicleMiles_265 VehicleMiles_150 DriverLicense {

	* OLS: full sample
	regsave_tbl if y=="`y'" & rdspec=="ols" & scenario=="All", name(full) `reg_settings'
	keep if inlist(var,"1.post_coef","1.post_stderr","psidak")
	replace var = "`y'_coef" if var=="1.post_coef"
	replace var = "`y'_stderr" if var=="1.post_stderr"
	replace var = "`y'_adjp" if var=="psidak"

	if `run_no'==1 append using "`table'"
	gen sortorder = _n
	local run_no = 1	
	save "`table'", replace
	restore, preserve

	* OLS: males
	regsave_tbl if y=="`y'" & rdspec=="ols" & scenario=="Male", name(male) `reg_settings'
	keep if inlist(var,"1.post_coef","1.post_stderr","psidak")
	replace var = "`y'_coef" if var=="1.post_coef"
	replace var = "`y'_stderr" if var=="1.post_stderr"
	replace var = "`y'_adjp" if var=="psidak"
	merge 1:1 var using "`table'", assert(match using) nogenerate
	save "`table'", replace
	restore, preserve
	
	* OLS: females
	regsave_tbl if y=="`y'" & rdspec=="ols" & scenario=="Female", name(female) `reg_settings'
	keep if inlist(var,"1.post_coef","1.post_stderr","psidak")
	replace var = "`y'_coef" if var=="1.post_coef"
	replace var = "`y'_stderr" if var=="1.post_stderr"
	replace var = "`y'_adjp" if var=="psidak"
	merge 1:1 var using "`table'", assert(match using) nogenerate
	save "`table'", replace
	restore, preserve

	* Mean (same for OLS and rdrobust)
	keep if y=="`y'" & rdspec=="ols" & inlist(scenario,"All","Male","Female")
	keep mean_y scenario
	ren mean_y mean_y_
	gen var = "`y'_coef"
	reshape wide mean_y_, i(var) j(scenario) str
	merge 1:1 var using "`table'", assert(match using) nogenerate
	sort sortorder
	drop sortorder
	save "`table'", replace
	restore, preserve
}

restore, not
use "`table'", clear
drop if inlist(var,"DriverLicense_adjp","VehicleMiles_150_adjp","VehicleMiles_265_adjp")

***
* Table formatting
***

order var mean_y_All full mean_y_Male male mean_y_Female female
gtostring mean_y*, force replace sigfig(3)
replace mean_y_All    = "" if mean_y_All=="."
replace mean_y_Male   = "" if mean_y_Male=="."
replace mean_y_Female = "" if mean_y_Female=="."

foreach v in male female full {
	replace `v' = "\(<\)0.0001" if real(`v')<0.0001 & strpos(var,"adjp")
	replace `v' = "\(<\)0.001" if real(`v')<0.001 & strpos(var,"adjp")
	replace `v' = "\(<\)0.01" if real(`v')<0.01 & strpos(var,"adjp")	
	replace `v' = "\{"+ `v' +"\}" if strpos(var,"adjp")
	label var `v' "RD"
}

replace var = "" if strpos(var,"_stderr")
replace var = "" if strpos(var,"_adjp")
replace var = subinstr(var,"_coef","",1)
clean_varnames var
replace var = "\addlinespace[1ex] " + var if !mi(var)

* Create panels
ingap 1 7
replace var = "A. Driving" in 1 if mi(var)
replace var = "B. Mortality" in 8 if mi(var)

* Label variables
label var full "RD"
label var male "RD"
label var female "RD"
label var mean_y_All "Mean"
label var mean_y_Male "Mean"
label var mean_y_Female "Mean"
label var var "Outcome variable"

* Output table
local title "OLS estimates of effect of driving eligibility on teenage driving and mortality"
local headerlines "& \multicolumn{2}{c}{Full sample} & \multicolumn{2}{c}{Male} & \multicolumn{2}{c}{Female}" "\cmidrule(lr){2-3} \cmidrule(lr){4-5} \cmidrule(lr){6-7}"
local fn "Notes: This table replicates Table \ref{tab:rd_mortality} but uses an OLS estimator with a bandwidth of 24 months instead of an MSE-optimal estimator. Columns (1), (3), and (5) report means of the dependent variable one year before reaching the minimum driving age (MDA). Columns (2), (4), and (6) report OLS estimates of \(\beta\) from equation (\ref{E - RD1}). Robust standard errors are reported in parentheses.  `fn_asterisk' `fn_familyp'"

texsave using "$Driving/results/tables/rd_mortality_ols.tex", size(scriptsize) align(lCcCcCc) headerlines("`headerlines'") varlabels marker("tab:rd_mortality_ols")  bold("A. " "B. ") title("`title'") hlines(1 8) footnote("`fn'", size(scriptsize)) `texsave_settings'


** EOF
