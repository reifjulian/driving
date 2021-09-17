************
* SCRIPT: create_addhealth_derived.do
* PURPOSE: Create derived Add Health datasets used by the replication package
* NOTE: This script is provided for documentation purposes only
************

* Preamble (unnecessary when executing run.do)
do "$Driving/scripts/programs/_config.do"

************
* Code begins
************

clear
set more off

local addhealth_raw 0
tempfile tmp tmp2 

***
* Clean raw Add Health data
***
if `addhealth_raw==1' {

	* AddHealth confidential data are stored on a local drive, located at "$AddHealth"
	use "$AddHealth/wave1.dta", clear
	
	* Add pseudo state identifiers to Wave 1
	merge 1:1 aid using "$AddHealth/nhood1.dta"

	* Rename variables of interest for consistency between Wave 1 and Wave 2
	* Wave 1 and Wave 2 variable names usually differ
	ren h1gi1m bmonth
	ren h1gi1y byear
	ren h1gi6a race
	ren h1ee10 DriverLicense
	ren h1ee11 milesdriven
	ren h1ee3 work
	ren h1gi21 noschool

	* Merge on sampling weights	for Wave 1
	keep aid imonth iyear bmonth byear race DriverLicense w1state bio_sex work milesdriven noschool
	merge 1:1 aid using "$AddHealth/weights1.dta", nogenerate
	save `tmp', replace
		
	* Merge on Wave 2	
	use "$AddHealth/wave2.dta", clear
	merge 1:1 aid using "$AddHealth/nhood2.dta"

	* Rename variables of interest for consistency between Wave 1 and Wave 2
	* Wave 1 and Wave 2 variable names usually differ
	ren imonth2 imonth
	ren iyear2 iyear
	ren h2gi1m bmonth
	ren h2gi1y byear
	ren h2ee10 DriverLicense
	ren h2ee11 milesdriven
	ren h2ee3 work
	ren h2gi10 noschool

	* Merge on sampling weights	for Wave 2	
	keep aid imonth iyear bmonth byear DriverLicense w2state bio_sex2 work milesdriven noschool
	merge 1:1 aid using "$AddHealth/weights2.dta", nogenerate
	append using `tmp'
	save `tmp2', replace

	* Flag for incomplete observations not suited for analysis
	* Flag=1 if missing state identifiers, sample weights, month/year of month, or having too few observations to determine MDA
	gen flag=0

	* Pseudo state identifiers
	gen staters=w1state
	replace staters=w2state if staters==.
	replace flag=1 if staters==.

	* Sampling weights
	gen gweight=gswgt1
	replace gweight=gswgt2 if gweight==.
	replace flag=1 if gweight==.

	* Unknown birth months and years
	replace flag=1 if inlist(bmonth, 96, 98, .)
	replace flag=1 if inlist(byear, 96, 98, .)

	* States with too few observations (less than 20)
	replace flag=1 if inlist(staters, 1, 2, 4, 5, 10, 13, 18, 35)

	* White indicator for 1996 using 1995
	replace race=. if !inlist(race, 0, 1)
	sort aid iyear
	bysort aid (race): gen white=race[1]

	* Male indicator
	gen male=bio_sex
	replace male=bio_sex2 if male==.
	replace male=. if !inlist(male, 1, 2)
	replace male=0 if male==2

	* Adjustment: 6 observations from Wave I coded as 1994 instead of 1995
	replace iyear=iyear+1900
	replace byear=byear+1900 
	replace iyear=1995 if iyear==1994
	drop if iyear==.

	* Ages in months
	gen agemo = ym(iyear,imonth) - ym(byear, bmonth)

	***
	* Determine MDAs (note: this is based on driver licensing RD plots)
	***
	* States with MDA 16
	gen agemo_mda=agemo-192 if !inlist(staters, 7, 9, 17, 22, 27, 31, 32, 39)
		
	* States with MDA 15
	replace agemo_mda=agemo-180 if inlist(staters, 9, 22, 27, 31, 32, 39)

	* One state with MDA 17
	replace agemo_mda=agemo-204 if staters==17

	* One state with MDA 15 in 1995 and MDA 16 in 1996
	replace agemo_mda=agemo-180 if staters==7 & iyear==1995
	replace agemo_mda=agemo-192 if staters==7 & iyear==1996

	* Identify missing answers for driver's license and other variables
	* Set legitimate skips to zeros
	replace DriverLicense=. if DriverLicense==6|DriverLicense==8
	replace DriverLicense=0 if DriverLicense==7
	replace milesdriven=. if !inrange(milesdriven, 1, 4)&milesdriven!=7
	replace milesdriven=1 if milesdriven==7
	replace work=. if !inrange(work, 0, 1)
	replace noschool=. if inlist(noschool, 96, 98)
	replace noschool=0 if noschool==97
		
	***
	** Construct outcome variables
	***
	* Imputed miles driven weekly (150 for 100+ miles)
	gen VehicleMiles_150=0 if milesdriven==1&milesdriven!=.
	replace VehicleMiles_150=25 if milesdriven==2&milesdriven!=.
	replace VehicleMiles_150=75 if milesdriven==3&milesdriven!=.
	replace VehicleMiles_150=150 if milesdriven==4&milesdriven!=.

	* Imputed miles driven weekly (265 for 100+ miles, based on per capita VMT from FHWA)
	gen VehicleMiles_265=0 if milesdriven==1&milesdriven!=.
	replace VehicleMiles_265=25 if milesdriven==2&milesdriven!=.
	replace VehicleMiles_265=75 if milesdriven==3&milesdriven!=.
	replace VehicleMiles_265=265 if milesdriven==4&milesdriven!=.

	* Convert to miles driven yearly
	replace VehicleMiles_150=VehicleMiles_150*(365/7)
	replace VehicleMiles_265=VehicleMiles_265*(365/7)

	* Ever worked for pay during last 4 weeks
	gen Work4weeks=(work==1&work!=.)
	replace Work4weeks=. if work==.

	* Not enrolled in school nor graduated: suspended, expelled, dropped out, sick, injured, on leave, preganant, other
	gen NotEnrolled=(inlist(noschool, 1, 2, 3, 4, 5, 7, 8) & noschool!=. & iyear==1996)
	replace NotEnrolled=1 if inlist(noschool, 1, 2, 3, 5, 6) & noschool!=. & iyear==1995
	replace NotEnrolled=. if noschool==.

	drop race bio_sex bio_sex2 w1state w2state gswgt1 gswgt2 aid imonth bmonth byear psuscid work milesdriven noschool 
		
	* Label variables
	label var agemo_mda "Age in months relative to MDA"
	label var agemo "Age in months"
	label var white "White indicator"
	label var male "Male indicator"
	label var staters "Pseudo state identifier"
	label var gweight "Grand sampling weights"
	label var DriverLicense "Driver's license indicator"
	label var VehicleMiles_150 "Imputed miles driven yearly (150 for 100+ miles)"
	label var VehicleMiles_265 "Imputed miles driven yearly (265 for 100+ miles)"
	label var Work4weeks "Work during last 4 weeks"
	label var NotEnrolled "Not enrolled nor graduated"
	label var iyear "Survey year"
	label var flag "Flag for missing state identifier, weight, birth month/year, or unknown MDA"
			
	* Save the data
	compress
	save "$Driving/data/add_health/addhealth_data.dta", replace
}

***
* Create derived datasets
***
cap mkdir "$Driving/data/add_health/derived"

qui foreach scenario in "All" "Male" "Female" {
		
	* Add Health data
	use "$Driving/data/add_health/addhealth_data.dta", clear
	
	* Drop observations with missing data
	drop if flag==1
	
	if      "`scenario'"=="Male"      keep if male==1
	else if "`scenario'"=="Female"    keep if male==0	
	else if "`scenario'"=="All"       assert !mi(male)
		
	else error 1	

	local outcomes "DriverLicense VehicleMiles_150 VehicleMiles_265 Work4weeks NotEnrolled"	

	* Keep 4 years of data before and after MDA
	keep if inrange(agemo_mda, -48, 47)
		
	* Collapse over age in months relative to MDA
	collapse (mean) `outcomes' [pw=gweight], by(agemo_mda) fast

	* Label variables
	label var DriverLicense "Driver's license indicator"
	label var VehicleMiles_150 "Imputed miles driven yearly (150 for 100+ miles)"
	label var VehicleMiles_265 "Imputed miles driven yearly (265 for 100+ miles)"
	label var Work4weeks "Work during last 4 weeks"
	label var NotEnrolled "Not enrolled nor graduated"
	
	* Save the data
	compress
	local output_fn = lower("`scenario'")
	save "$Driving/data/add_health/derived/`output_fn'.dta", replace
}	


** EOF
