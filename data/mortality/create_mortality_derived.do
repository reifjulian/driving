************
* SCRIPT: create_mortality_derived.do
* PURPOSE: Create derived mortality datasets used by the replication package
* NOTE: This script is provided for documentation purposes only
************

* Preamble (unnecessary when executing run.do)
do "$Driving/scripts/programs/_config.do"

************
* Code begins
************

clear
set more off
tempfile seer_data

cap mkdir "$Driving/data/mortality"
cap mkdir "$Driving/data/mortality/derived"
	
qui foreach scenario in "All" "mda192" "mda_not192" "mda192_Female" "mda_not192_Female" "mda192_Male" "mda_not192_Male" "Male" "Female" {
	
	* Main data for analysis
	use "$Driving/processed/mortality_mda_combined8314st.dta", clear
	
	* Subset the data down according to the heterogeneity specification of interest		
	if      "`scenario'"=="Male"      keep if male==1
	else if "`scenario'"=="Female"    keep if male==0
	else if "`scenario'"=="All"       assert !mi(male)
		
	else if "`scenario'"=="mda192"     keep if mda_months==192
	else if "`scenario'"=="mda_not192" keep if mda_months!=192
		
	else if "`scenario'"=="mda192_Male"     keep if mda_months==192 & male==1
	else if "`scenario'"=="mda_not192_Male" keep if mda_months!=192 & male==1
		
	else if "`scenario'"=="mda192_Female"     keep if mda_months==192 & male==0
	else if "`scenario'"=="mda_not192_Female" keep if mda_months!=192 & male==0
		
	* Causes of death
	unab outcomes : cod_*
	compress

	* Keep 4 years of data before and after MDA
	keep if inrange(agemo_mda, -48, 47)
		
	* Collapse over age in months relative to MDA
	collapse (sum) `outcomes' pop, by(agemo_mda) fast
	
	* Label variables
	label var cod_any "total deaths"
	label var cod_MVA "MVA deaths"
	label var cod_homicide "homicides"
	label var cod_sa "suicide and accident"
	label var cod_extother "other external deaths"
	label var cod_external "external deaths"
	label var cod_sa_firearms "suicide and accident - firearms"
	label var cod_sa_poisoning "suicide and accident - poisoning"
	label var cod_sa_poisoning_gas "suicide and accident - gases"
	label var cod_sa_poisoning_subst "suicide and accident - substances"
	label var cod_sa_drowning "suicide and accident - drowning"
	label var cod_sa_other "suicide and accident - other remainder"
	label var cod_internal "internal deaths"
	label var pop "Population"
	
	* Save the data
	compress
	local output_fn = lower("`scenario'")
	save "$Driving/data/mortality/derived/`output_fn'.dta", replace
}	

***
** MVA and poisoning mortality data by 4-year bins
***

* Number of years in the bin
local num_yrs = 4
	
qui forval yr = 1983(`num_yrs')2013 {
qui foreach scenario in "Male" "Female" {
		
	use "$Driving/processed/mortality_mda_combined8314st.dta", clear
	keep if inrange(year,`yr',`yr'+`num_yrs'-1)
	if "`scenario'"=="Male"           keep if male==1
	else if "`scenario'"=="Female"    keep if male==0

	* Causes of death
	local outcomes "cod_MVA cod_sa_poisoning"	
	compress

	* Keep 4 years of data before and after MDA
	keep if inrange(agemo_mda, -48, 47)
		
	* Collapse over age in months relative to MDA
	collapse (sum) `outcomes' pop, by(agemo_mda) fast

	* Label variables
	label var cod_MVA "MVA deaths"
	label var cod_sa_poisoning "suicide and accident - poisoning"
	label var pop "Population"
		
	* Save the data
	compress
	local output_fn = lower("`scenario'")
	save "$Driving/data/mortality/derived/`output_fn'_`yr'.dta", replace	
}
}

***
** Suicide and accident mortality data
***
	
qui foreach scenario in "Male" "Female" {
		
	use "$Driving/processed/mortality_mda_combined8314nt.dta", clear
	if "`scenario'"=="Male"           keep if male==1
	else if "`scenario'"=="Female"    keep if male==0

	* Causes of death
	local outcomes "cod_suicide* cod_acct* cod_sa*"	
	compress

	* Keep 4 years of data before and after MDA
	keep if inrange(agemo_mda, -48, 47)
		
	* Collapse over age in months relative to MDA
	collapse (sum) `outcomes' pop, by(agemo_mda) fast

	label var cod_suicide "suicides"
	label var cod_acct "accidents"
	label var cod_sa "suicide and accident"
	label var cod_suicide_firearms "suicides - firearms"
	label var cod_suicide_poisoning "suicides - poisoning"
	label var cod_suicide_poisoning_gas "suicides - gases"
	label var cod_suicide_poisoning_subst "suicides - substances"
	label var cod_suicide_drowning "suicides - drowning"
	label var cod_suicide_other "suicides - other remainder"
	label var cod_acct_firearms "accidental - firearms"
	label var cod_acct_poisoning "accidental - poisoning"
	label var cod_acct_poisoning_gas "accidental - gases"
	label var cod_acct_poisoning_subst "accidental - substances"
	label var cod_acct_drowning "accidental - drowning"
	label var cod_acct_other "accidental - other remainder"
	label var cod_sa_firearms "suicide and accident - firearms"
	label var cod_sa_poisoning "suicide and accident - poisoning"
	label var cod_sa_poisoning_gas "suicide and accident - gases"
	label var cod_sa_poisoning_subst "suicide and accident - substances"
	label var cod_sa_drowning "suicide and accident - drowning"
	label var cod_sa_other "suicide and accident - other remainder"
	label var pop "Population"
	
	* Save the data
	compress
	local output_fn = lower("`scenario'")
	save "$Driving/data/mortality/derived/sa_`output_fn'.dta", replace		
}

***
** Mortality data with ages extended to 10-29
***

* SEER population data
use "$Driving/data/seer/derived/seer_pop1983_2014st.dta", clear

collapse (sum) pop, by(year male age) fast
save "`seer_data'", replace

* Main data for analysis with ages extended to 10-29
use "$Driving/processed/intermediate/cdc_mortality_data83to14st.dta", clear
gen age = floor(agemo/12)

* Group into ages 10-14, 15-19, 20-24, and 25-29
keep if inrange(age,10,29)
gen agegroup=1
replace agegroup=2 if inrange(age, 15, 19)
replace agegroup=3 if inrange(age, 20, 24)
replace agegroup=4 if inrange(age, 25, 29)
assert !mi(agegroup)
	
* Causes of death
local outcomes "cod_any cod_external cod_internal cod_MVA cod_homicide cod_extother cod_sa cod_sa_firearms cod_sa_poisoning cod_sa_poisoning_subst cod_sa_poisoning_gas cod_sa_drowning cod_sa_other"

* Merge on SEER data
* Collapse over gender and age group by year
collapse (sum) `outcomes', by(year male age agegroup) fast
merge 1:1 year male age using "`seer_data'", assert(using match) keep(match) nogenerate
drop age

* Label variables
label var cod_any "total deaths"
label var cod_MVA "MVA deaths"
label var cod_homicide "homicides"
label var cod_sa "suicide and accident"
label var cod_extother "other external deaths"
label var cod_external "external deaths"
label var cod_sa_firearms "suicide and accident - firearms"
label var cod_sa_poisoning "suicide and accident - poisoning"
label var cod_sa_poisoning_gas "suicide and accident - gases"
label var cod_sa_poisoning_subst "suicide and accident - substances"
label var cod_sa_drowning "suicide and accident - drowning"
label var cod_sa_other "suicide and accident - other remainder"
label var cod_internal "internal deaths"
label var pop "Population"
label var agegroup "Age group indicator (1=10-14;2=15-19;3=20-24;4=25-29)"

* Save the data
compress
save "$Driving/data/mortality/derived/sex_agegroup_8314.dta", replace		

** EOF
