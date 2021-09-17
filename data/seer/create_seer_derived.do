************
* SCRIPT: create_seer_derived.do
* PURPOSE: Create derived SEER dataset used by the replication package
* NOTE: This script is provided for documentation purposes only
************

* Preamble (unnecessary when executing run.do)
do "$Driving/scripts/programs/_config.do"

************
* Code begins
************

clear
set more off

* 1969-2016 population
cd "$SEER"
unzipfile us.1969_2016.singleages.zip, replace
infile using "us.1969_2016.singleages.dct", using("us.1969_2016.singleages.txt") clear
rm us.1969_2016.singleages.txt

ren stfips staters
	
* Drop unnecessary years to save space (keep only 1983-2014)
keep if inrange(year, 1983, 2014)
	
* Prior to 1990, race only had three categories: white(=1), black(=2), other(=3)
* Starting in 1990, the "other" category was further divided into American Indian/Alaska Native(=3) and Asian/Pacific Islander(=4)
* Simply make race a binary measure (white or non-white)
assert !mi(race)
replace race=2 if race!=1
gen white = race==1
	
* Sex: 1=Male 2=Female
assert inlist(sex,1,2)
gen male = sex==1
	
collapse (sum) pop, by(year staters abbr age male white) fast

* Keep only people between ages 10 and 30
assert inrange(age,0,85)
keep if inrange(age,10,30)

* Label variables
label var year "Year"
label var abbr "State postal abbreviation"
label var staters "State fips code"
label var age "Age"
label var white "Race white indicator"
label var male "Gender male indicator"
label var pop "Population"
	
* Save the data
compress
save "$Driving/data/seer/derived/seer_pop1983_2014st.dta", replace


**EOF
