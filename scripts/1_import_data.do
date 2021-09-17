************
* SCRIPT: 1_import_data.do
* PURPOSE: imports the raw data and saves it in Stata readable format
************

* Preamble (unnecessary when executing run.do)
do "$Driving/scripts/programs/_config.do"

************
* Code begins
************

clear
set more off
tempfile tmp

* Set the flag equal to 1 to run that analysis, and equal to 0 otherwise
* Note: mortality and FARS codes are disabled because the raw data are not included in this replication package
local mortality 0
local fars 0
local fhwa 1

*************************************************
******** Multiple Cause-of-Death Data ***********
*************************************************
if `mortality'==1 {

** Read in multiple cause-of-death data
local years     "1983       1984      1985       1986        1987      1988       1989       1990        1991         1992       1993        1994      1995       1996        1997      1998       1999        2000       2001       2002        2003	    2004       2005       2006        2007      2008       2009        2010       2011       2012        2013       2014"
local age       "age        age       age        age         age       age	      age        age         age          age        age         age       age        age         age       age	       age         age        age        age         age        age        age        age         age       age	       age         age        age        age         age        age"
local sex       "sex        sex       sex        sex         sex       sex        sex        sex         sex          sex        sex         sex       sex        sex         sex       sex        sex         sex        sex        sex         sex        sex        sex        sex         sex       sex        sex         sex        sex        sex         sex        sex"
local staters   "statersf   statersf  statersf   statersf    statersf  statersf   statersf   statersf    statersf     statersf   statersf    statersf  statersf   statersf    statersf  statersf   statersf    statersf   statersf   statersf    statersf   statersf   statersf   statersf    statersf  statersf   statersf    statersf   statersf   statersf    statersf   statersf"
local race      "race       race      race       race        race      race       race       race        race         race       race        race      race       race        race      race       race        race       race       race        racer5     racer5     race       race        race      race       race        race       race       race        racer5     racer5"
local ucod      "ucod       ucod      ucod       ucod        ucod      ucod       ucod       ucod        ucod         ucod       ucod        ucod      ucod       ucod        ucod      ucod       ucod        ucod       ucod       ucod        ucod       ucod       ucod       ucod        ucod      ucod       ucod        ucod       ucod       ucod        ucod       ucod"
local monthdth  "monthdth   monthdth  monthdth   monthdth    monthdth  monthdth   monthdth   monthdth    monthdth     monthdth   monthdth    monthdth  monthdth   monthdth    monthdth  monthdth   monthdth    monthdth   monthdth   monthdth    monthdth   monthdth   monthdth   monthdth    monthdth  monthdth   monthdth    monthdth   monthdth   monthdth    monthdth   monthdth"
local mo_brth   "mo_brth    mo_brth   mo_brth    mo_brth     mo_brth   mo_brth    mo_brth    mo_brth     mo_brth      mo_brth    mo_brth     mo_brth   mo_brth    mo_brth     mo_brth   mo_brth    mo_brth     mo_brth    mo_brth    mo_brth     mo_brth    mo_brth    mo_brth    mo_brth     mo_brth   mo_brth    mo_brth     mo_brth    mo_brth    mo_brth     mo_brth    mo_brth"
local yr_brth  	"yr_brth    yr_brth   yr_brth    yr_brth     yr_brth   yr_brth    yr_brth    yr_brth     yr_brth      yr_brth    yr_brth     yr_brth   yr_brth    yr_brth     yr_brth   yr_brth    yr_brth     yr_brth    yr_brth    yr_brth     yr_brth    yr_brth    yr_brth    yr_brth     yr_brth   yr_brth    yr_brth     yr_brth    yr_brth    yr_brth     yr_brth    yr_brth"
local ageunit   "ageunit    ageunit   ageunit    ageunit     ageunit   ageunit	  ageunit    ageunit     ageunit      ageunit    ageunit     ageunit   ageunit    ageunit     ageunit   ageunit	   ageunit     ageunit    ageunit    ageunit     ageunit    ageunit    ageunit    ageunit     ageunit   ageunit	   ageunit     ageunit    ageunit    ageunit     ageunit    ageunit"

* Specify the optional variable sets to be imported
local import_vars "age sex staters race ucod monthdth mo_brth yr_brth ageunit"

local run_no = 0
local num_surveys: word count `years'
qui forval index = 1/`num_surveys' {

	tokenize `years'
	local year "``index''"
	noi di "Year: `year'"
		
	* Specify variables to keep from this dataset
	local tokeep
	foreach locals_list in `import_vars' {
		tokenize ``locals_list''
		if "``index''"!="XXX" local tokeep "`tokeep' ``index''"
	}
	
	* Pre-2003
	if `year'<2003 {
		cd "$MortalityDataMOB/`year'"	
		qui do mort`year'.do
		
		* Note: statersf is usually the NVS state code in these years. But in these confidential files, it is in fact the stfips code
		* Thare are some "00" codes; by comparing to public file, we deduced that these are all foreign residents (ie from Canada, Mexico, etc) 
		destring statersf, replace
		ren statersf stfips
		drop if stfips==0
		assert inrange(stfips,1,56)
		merge m:1 stfips using "$Driving/data/fips/state_fips_codes.dta", keepusing(abbr) nogenerate assert(match using) keep(match)
		ren stfips statersf
	}
	
	* Formatting change in 2003
	if `year'>=2003 {
	
		cd "$MortalityDataMOB/`year'"
		qui do mort`year'.do
		
		* statersf changes to a two-letter abbreviation beginning in 2003
		ren statersf abbr
		
		* Drop foreign residents
		drop if inlist(abbr,"ZZ","XX","YY")
		
		* Drop territories
		drop if inlist(abbr,"AS","FM","GU","MP","PR","PW","UM","VI")	
		
		* Merge on stfips codes
		merge m:1 abbr using "$Driving/data/fips/state_fips_codes.dta", keepusing(stfips) nogenerate assert(match using) keep(match)
		ren stfips statersf
				
		cap replace sex = "1" if sex=="M"
		cap replace sex = "2" if sex=="F"

	}
	
	keep `tokeep' abbr
	gen year = `year'
	label var year "Year of death"
	
	* Rename vars and append onto main dataset
	foreach locals_list in `import_vars' {
		tokenize ``locals_list''
		if "``index''"!="XXX" ren ``index'' `locals_list'
	}
	
	***
	* Clean age var, and keep only under age 30
	***
	destring age ageunit, replace
	assert !mi(age)
	
	* ageunit
	* 1983-2002: 0=years less than 100; 1=years 100 or more; 2=Months; 3=weeks; 4=Days; 5=Hours; 6=minutes; 9=Age not stated
	* 2003+:                            1=years;             2=Months;          4=Days; 5=Hours; 6=minutes; 9=Age not stated
	assert inlist(ageunit,0,1,2,3,4,5,6,9)        if year<2003
	assert inlist(ageunit,1,2,4,5,6,9)            if year>=2003
	
	assert inrange(age,1,100)                     if ageunit==0
	assert inrange(age,0,11) | inlist(age,99,999) if ageunit==2
	assert inrange(age,1,3)  | inlist(age,99,999) if ageunit==3
	assert inrange(age,0,31) | inlist(age,99,999) if ageunit==4
	assert inrange(age,0,23) | inlist(age,99,999) if ageunit==5
	assert inrange(age,0,59) | inlist(age,99,999) if ageunit==6
	assert inlist(age,99,999)                     if ageunit==9
	
	* If ageunit=1 and year<2003, then this person is over 100 years old --> edit age variable accordingly
	assert inrange(age,0,33) if ageunit==1 & year<2003
	replace age = age+100    if ageunit==1 & year<2003
	
	* Drop infants and missing ages
	drop if inlist(ageunit,2,3,4,5,6,9)
	drop if age==999
	
	* Keep only people between ages 10 and 30
	assert inrange(age,1,133)
	keep if inrange(age,10,30)
	drop ageunit
	
	***
	* Append and save
	***
	if `run_no'==1 append using "`tmp'"
	compress
	save "`tmp'", replace
		
	local run_no = 1
}

* Label variables
label var mo_brth "Month of birth"
label var yr_brth "Year of birth"
label var abbr "State of residence postal abbreviation"
label var staters "State of residence fips code"
label var monthdth "Calendar month of death"
label var sex "Male=1 Female=2"
label var age "Age in years"
label var ucod "ICD code"
label var race "Race (white=1;nonwhite=2,3,..)"

* Save the data
compress		
save "$Driving/processed/intermediate/cdc_mortality8314_raw_ageunit.dta", replace	

}

***************************************************
******* Fatality Analysis Reporting System ********
***************************************************
if `fars'==1 {

* Read in the FARS data
local years     "1983  1984  1985  1986  1987  1988  1989  1990  1991  1992  1993  1994  1995  1996  1997  1998  1999  2000  2001  2002  2003  2004  2005  2006  2007  2008  2009  2010  2011  2012  2013  2014"

local run_no = 0
local num_surveys: word count `years'

** Person data
qui forval index = 1/`num_surveys' {

	tokenize `years'
	local year "``index''"
	noi di "Year: `year'"
		
	* Specify variables to keep from this dataset
	local tokeep "state age month per_typ st_case inj_sev"
	
	use "$FARS/person/`year'", clear	
	
	keep `tokeep'
	gen year = `year'
	label var year "Year of crash"
	
	***
	* Append and save
	***
	if `run_no'==1 append using "`tmp'"
	compress
	save "`tmp'", replace
		
	local run_no = 1
	
	ren state staters
}

* Save the data
compress		
save "$Driving/processed/intermediate/fars_raw_data8314_person.dta", replace

}

***************************************************
******** Federal Highway Administration ***********
***************************************************
if `fhwa'==1 {

* Licensed driver counts by age from FHWA
import excel "$Driving/data/fhwa/licensed_drivers_1964-2014_ages16-19.xlsx", firstrow clear

* Drop unnecessary years to save space (keep only 1983-2014)
keep if inrange(year, 1983, 2014)

* Label variables
label var year "Year"
label var total_16 "Drivers aged 16"
label var total_17 "Drivers aged 17"
label var total_18 "Drivers aged 18"
label var total_19 "Drivers aged 19"

* Save the data
compress		
save "$Driving/processed/intermediate/licensed_drivers_1983to2014.dta", replace

}


** EOF
