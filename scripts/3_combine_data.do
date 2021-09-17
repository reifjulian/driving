************
* SCRIPT: 3_combine_data.do
* PURPOSE: Create the final datasets used in the analyses
************

* Preamble (unnecessary when executing run.do)
do "$Driving/scripts/programs/_config.do"

************
* Code begins
************

clear
set more off
tempfile tmp seer_data

* Set the flag equal to 1 to run that analysis, and equal to 0 otherwise
* Note: mortality and FARS codes are disabled because the raw data are not included in this replication package
local mortality_state 0
local fars 0
local fhwa 1

*************************************************************************
****** State-level (and national-level) mortality data ages 10-21 *******
*************************************************************************
if `mortality_state'==1 {

***
** Prep the SEER data and the mortality data by limiting to ages of interest
***
use "$Driving/data/seer/derived/seer_pop1983_2014st.dta", clear	

* Keep relevant ages: 10-21 years
keep if inrange(age,10,21)
assert !mi(pop)

save "`seer_data'", replace

use "$Driving/processed/intermediate/cdc_mortality_data83to14st.dta", clear

* Keep relevant ages: 10-21 years
keep if inrange(agemo,10*12,22*12-1)
assert inrange(floor(agemo/12),10,21)

save `tmp', replace

***
* Generate full set of state, year, month of death, agemo, gender, and race interactions
* This is necessary to ensure we obtain an accurate estimate of the total population when we later merge with the SEER data
* The additional observations will account for bins with 0 deaths (but nonzero population)
***
duplicates drop staters, force
keep staters 

* age in months (ages 10-21)
set obs `=22*12-1 - 10*12 + 1'
gen agemo = 10*12-1 + _n
assert inrange(floor(agemo/12),10,21)

gen male      = _n-1 in 1/2
gen white     = _n-1 in 1/3
gen monthdth  = _n   in 1/12

compress

fillin monthdth staters male white agemo
drop _fillin

* Drop any missing observations from the fillin
unab vars: *
foreach v of local vars {
	drop if mi(`v')
}
compress

* Duplicate to create copies for years 1983-2014
tempfile t
save "`t'", replace
gen int year = 1983
forval yr = 1984/2014 {
	append using "`t'"
	replace year = `yr' if mi(year)
}

* Merge on mortality cause-of-death data
merge 1:1 year monthdth staters male white agemo using "`tmp'", assert(master match) nogenerate

foreach v of varlist cod* {
	replace `v' = 0 if mi(`v')
}

* Age in years (floor, not rounded)
gen int age = floor(agemo/12)

* Merge on SEER population data, and drop observations that have zero population and 0 deaths
merge m:1 year staters male white age using "`seer_data'", assert(master match)
drop if _merge==1 & cod_any==0
drop _merge

* Merge on the MDA law data
merge m:1 staters year monthdth using "$Driving/processed/intermediate/mdalaws_monthly8314.dta", assert(match) nogenerate

* The dataset is at the year-month level, but SEER data are annual -> Divide the population by 12
replace pop=pop/12

* Age in months relative to MDA
gen agemo_mda = agemo - mda_months

* Label variables
label var year "Year"
label var agemo "Age in months"
label var agemo_mda "Age (in months) since MDA"
label var mda_months "MDA in months"
label var male "Gender male indicator"
label var white "Race white indicator"

* Identify month of birth (1-12)
gen brthdt = ym(year,monthdth) - agemo
gen mo_brth = month(brthdt)
assert inrange(mo_brth,1,12)
label var mo_brth "Month of birth (1-12)"

* Save the data
drop age monthdth brthdt
compress
order year staters male white agemo agemo_mda mo_brth pop cod_any
sort  year staters male white agemo agemo_mda

* State-level file (larger) is used for heterogeneity/robustness analysis only: drop causes of death that we don't use in that analysis
preserve
	keep year-mo_brth pop cod_any cod_internal cod_external cod_MVA cod_sa cod_MVA cod_sa_poisoning cod_sa_poisoning_subst cod_sa_poisoning_gas cod_extother cod_homicide cod_sa_other cod_sa_drowning cod_sa_firearms mda_months
	
	collapse (sum) cod* pop, by(year-mo_brth mda_months) fast
	compress
	save "$Driving/processed/mortality_mda_combined8314st.dta", replace
restore, preserve

	* National-level file (small) - main one used in analysis
	collapse (sum) cod* pop, by(agemo_mda male) fast
	compress
	save "$Driving/processed/mortality_mda_combined8314nt.dta", replace
}

****************************************
************** FARS data ***************
****************************************
if `fars'==1 {

* Combine FARS person data with MDA law data
use "$Driving/processed/intermediate/fars_raw_data8314_person.dta", clear
ren month monthdth
merge m:1 staters year monthdth using "$Driving/processed/intermediate/mdalaws_monthly8314.dta", assert(match using) keep(match) nogenerate
drop monthdth

* Label variables
label var staters "State fips code"
label var st_case "Consecutive number"
label var age "Age"
label var per_typ "Person type"
label var inj_sev "Injury severity"

* Save the data
save "$Driving/processed/fars_8314.dta", replace
}

****************************************
************** FHWA  data **************
****************************************
if `fhwa'==1 {

* SEER population
use "$Driving/data/seer/derived/seer_pop1983_2014st.dta", clear
keep if inrange(age, 16, 19)
	
* Create population variable for each age group
gen pop_16=pop
replace pop_16=0 if age!=16
gen pop_17=pop
replace pop_17=0 if age!=17
gen pop_18=pop
replace pop_18=0 if age!=18
gen pop_19=pop
replace pop_19=0 if age!=19
		
local vars "pop_16 pop_17 pop_18 pop_19"
collapse (sum) `vars', by(year) fast
	
keep year pop_16 pop_17 pop_18 pop_19

* Merge FHWA data
merge 1:1 year using "$Driving/processed/intermediate/licensed_drivers_1983to2014.dta"
keep if _merge==3
drop _merge

* Label variables
label var pop_16 "Population aged 16"
label var pop_17 "Population aged 17"
label var pop_18 "Population aged 18"
label var pop_19 "Population aged 19"
	
* Save the data
save "$Driving/processed/fhwa_8314.dta", replace

}


** EOF
