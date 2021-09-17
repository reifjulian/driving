************
* SCRIPT: 2_clean_data.do
* PURPOSE: Cleans the multiple cause of death and MDA law datasets
************

* Preamble (unnecessary when executing run.do)
do "$Driving/scripts/programs/_config.do"

************
* Code begins
************

clear
set more off

* Set the flag equal to 1 to run that analysis, and equal to 0 otherwise
* Note: mortality code is disabled because the raw data are not included in this replication package
local mortality 0
local mdalaw8314 1

************************************************
*******  Multiple Cause-of-Death Data   ********
************************************************
if `mortality'==1 {

* Main mortality data
use "$Driving/processed/intermediate/cdc_mortality8314_raw_ageunit.dta", clear

***
* Sex (Male=1 Female=2)
***
destring sex, replace
assert inlist(sex,1,2)
gen male = sex==1
drop sex

***
* Race - code as white/nonwhite
***
* Pre-2003 codes (vary by year somewhat for some races): 00 = Other Asian 01=white 02=black 03=Native American 04-07=Asian 08=Filipino 18=Asian Indian 28=Korean 38=Samoan 48=Vietnamese 58=Guamanian 68=Other Asian 78=Combined Asian
* 2003+ codes: 01=White 02=Black ...
destring race, replace
assert !mi(race)
replace race=2 if race!=1
gen white = race==1
drop race

***
* Month of death
***
destring monthdth, replace
assert inrange(monthdth,1,12)

***
* State of residence
***
* Only US residents are included in sample
assert inrange(staters,1,56)

***
* Age - has already been restricted to between 10 and 30
***
assert inrange(age,10,30)

***
* Month of birth
***
* 99=unknown month of birth
drop if inlist(mo_brth,99,.)
assert inrange(mo_brth,1,12)

***
* Year of birth, construct age in months
***
* Drop unknown years of birth
drop if inlist(yr_brth,9999,.)

* Prior to 1989, year of birth was recorded with two digits. Everyone in this sample is age<30, so in theory all these birthyears should be after 1900.
assert inrange(yr_brth,0,99) if year<1989
replace yr_brth = 1900+yr_brth if year<1989

gen agemo = ym(year,monthdth) - ym(yr_brth, mo_brth)
label var agemo "Age in months"

* In theory agemo and age shouldn't differ by more than one integer year
* We have discrepancies for about 2,800 obs (0.14% of the sample) when we look at ages 10-30 --> drop those discrepancies, which occur predominantly in the older years
count if abs(floor(agemo/12) - age)>1
assert r(N)/_N<0.0014
tab year if abs(floor(agemo/12) - age)>1
drop if abs(floor(agemo/12) - age)>1

*****
** Define causes of death
*****
** Note: ICD-9 codes are used for 1979-1998, and ICD-10 codes for 1999-2014
** Categories: alcohol, drug, MVA, homicide, suicide, and accident based on ICD codes 
gen alcohol_a=0
gen drug_a=0
gen MVA_a=0
gen homicide_a=0
gen suicide_a=0
gen acct_a=0
gen external_a=0

** 1979-1998
replace alcohol_a=1 if inrange(year, 1979, 1998) & (inlist(substr(ucod,1,3), "291","303")|inlist(substr(ucod,1,4), "3050","3575","4255","5353","5710","5711","5712","5713","7903")) 
replace drug_a=1 if inrange(year, 1979, 1998) & (inlist(substr(ucod,1,3), "292","304"))
replace drug_a=1 if inrange(year, 1979, 1998) & (inlist(substr(ucod,1,4), "3321","3576","3051","3052","3053","3054"))
replace drug_a=1 if inrange(year, 1979, 1998) & (inlist(substr(ucod,1,4), "3055","3056","3057","3058","3059"))
replace MVA_a=1 if inrange(year, 1979, 1998) & (inlist(substr(ucod,1,2), "81")|inlist(substr(ucod,1,3), "820","821","822","823","824","825"))
replace homicide_a=1 if inrange(year, 1979, 1998) & (inlist(substr(ucod,1,2), "96"))
replace suicide_a=1 if inrange(year, 1979, 1998) & (inlist(substr(ucod,1,2), "95", "98"))
replace acct_a=1 if inrange(year, 1979, 1998) & (inlist(substr(ucod,1,3), "826","827","828","829"))
replace acct_a=1 if inrange(year, 1979, 1998) & (inlist(substr(ucod,1,2), "80", "83", "84", "85", "86", "88"))
replace acct_a=1 if inrange(year, 1979, 1998) & (inlist(substr(ucod,1,2), "89", "90", "91", "92"))

* First three digits of the ICD codes used in defining external causes for 1979-1998
gen ucod2=substr(ucod, 1, 3) if inrange(year, 1979, 1998)
destring ucod2, replace
replace external_a=1 if inrange(year, 1979, 1998) & (ucod2 >= 800|alcohol_a ==1|drug_a ==1|suicide_a ==1|MVA_a ==1|homicide_a ==1|acct_a==1) 

** 1999-2014
replace alcohol_a=1 if inrange(year, 1999, 2014) & (inlist(substr(ucod,1,3), "F10","K70","T51")|inlist(substr(ucod,1,4), "E244","G312","G621","G721","I426","K292","K852","K860","R780"))  
replace drug_a=1 if inrange(year, 1999, 2014) & (inlist(substr(ucod,1,3), "F11","F12","F13","F14","F15","F16","F17"))
replace drug_a=1 if inrange(year, 1999, 2014) & (inlist(substr(ucod,1,3), "F18","F19","F55","T40","T41","T43"))
replace MVA_a=1 if inrange(year, 1999, 2014) & (inlist(substr(ucod,1,2), "V0","V1","V2","V3","V4","V5","V6","V7","V8")) & (!inlist(substr(ucod,1,3), "V05","V15")) & (!inlist(substr(ucod,1,4), "V806","V812","V813","V814","V815","V816","V817","V818","V819"))
replace homicide_a=1 if inrange(year, 1999, 2014) & (inlist(substr(ucod,1,3), "X85","X86","X87","X88","X89")|inlist(substr(ucod,1,2),"X9","Y0"))
replace suicide_a=1 if inrange(year, 1999, 2014) & (inlist(substr(ucod,1,2), "X6","X7","Y1","Y2")|inlist(substr(ucod,1,3), "X80","X81","X82","X83","X84")|inlist(substr(ucod,1,3), "Y30","Y31","Y32","Y33","Y34")|inlist(substr(ucod,1,4), "Y870"))
replace acct_a=1 if inrange(year, 1999, 2014) & (inlist(substr(ucod,1,2), "V9","X0","X1","X2","X3","X4","X5")|inlist(substr(ucod,1,1), "W")|inlist(substr(ucod,1,3), "V05","V15")|inlist(substr(ucod,1,4), "V806","V812","V813","V814","V815","V816","V817","V818","V819"))
replace external_a=1 if inrange(year, 1999, 2014) & (inlist(substr(ucod,1,1), "V","W","X","Y","Z")|alcohol_a ==1|drug_a ==1|suicide_a ==1|MVA_a ==1|homicide_a ==1|acct_a==1) 

* Mutually exclusive cause of death category
gen cod_homicide=(homicide_a==1)
gen cod_suicide=(homicide_a==0 & suicide_a ==1)
gen cod_MVA=(homicide_a==0 & suicide_a==0 & MVA_a==1) 
gen cod_acct=(homicide_a==0 & suicide_a==0 & MVA_a==0 & acct_a==1)
gen cod_extother=(homicide_a==0 & suicide_a==0 & acct_a==0 & MVA_a==0 & external_a==1)
gen cod_external=external_a
gen cod_any=1

** Mutually exclusive subcategories within suicide
* Poisoning
gen cod_suicide_poisoning=0
replace cod_suicide_poisoning=1 if inrange(year, 1979, 1998) & (inlist(substr(ucod,1,3), "950", "951", "952", "980", "981", "982"))
replace cod_suicide_poisoning=1 if inrange(year, 1999, 2014) & (inlist(substr(ucod,1,2), "X6", "Y1"))

* Substances
gen cod_suicide_poisoning_subst=0
replace cod_suicide_poisoning_subst=1 if inrange(year, 1979, 1998) & (inlist(substr(ucod,1,3), "950", "980"))
replace cod_suicide_poisoning_subst=1 if inrange(year, 1999, 2014) & (inlist(substr(ucod,1,3), "X60", "X61", "X62", "X63", "X64", "X65", "X68", "X69"))
replace cod_suicide_poisoning_subst=1 if inrange(year, 1999, 2014) & (inlist(substr(ucod,1,3), "Y10", "Y11", "Y12", "Y13", "Y14", "Y15", "Y18", "Y19"))

* Gases
gen cod_suicide_poisoning_gas=0
replace cod_suicide_poisoning_gas=1 if inrange(year, 1979, 1998) & (inlist(substr(ucod,1,3), "951", "952", "981", "982"))
replace cod_suicide_poisoning_gas=1 if inrange(year, 1999, 2014) & (inlist(substr(ucod,1,3), "X66", "X67", "Y16", "Y17"))

* Firearms
gen cod_suicide_firearms=0
replace cod_suicide_firearms=1 if inrange(year, 1979, 1998) & (inlist(substr(ucod,1,3), "955", "985"))
replace cod_suicide_firearms=1 if inrange(year, 1999, 2014) & (inlist(substr(ucod,1,3), "X72", "X73", "X74", "X75", "Y22", "Y23", "Y24"))

* Subcategories within other suicides
* Drowning
gen cod_suicide_drowning=0
replace cod_suicide_drowning=1 if inrange(year, 1979, 1998) & (inlist(substr(ucod,1,3), "954", "984"))
replace cod_suicide_drowning=1 if inrange(year, 1999, 2014) & (inlist(substr(ucod,1,3), "X71", "Y21"))

** Mutually exclusive subcategories within accidental deaths
* Poisoning
gen cod_acct_poisoning=0
replace cod_acct_poisoning=1 if inrange(year, 1979, 1998) & (inlist(substr(ucod,1,2), "85", "86"))
replace cod_acct_poisoning=1 if inrange(year, 1999, 2014) & (inlist(substr(ucod,1,2), "X4"))

* Poisoning substances
gen cod_acct_poisoning_subst=0
replace cod_acct_poisoning_subst=1 if inrange(year, 1979, 1998) & (inlist(substr(ucod,1,2), "85"))|(inlist(substr(ucod,1,3), "860", "861", "862", "863", "864", "865", "866"))
replace cod_acct_poisoning_subst=1 if inrange(year, 1999, 2014) & (inlist(substr(ucod,1,3), "X40", "X41", "X42", "X43", "X44", "X45", "X48", "X49"))

* Poisoning gases
gen cod_acct_poisoning_gas=0
replace cod_acct_poisoning_gas=1 if inrange(year, 1979, 1998) & (inlist(substr(ucod,1,3), "867", "868", "869"))
replace cod_acct_poisoning_gas=1 if inrange(year, 1999, 2014) & (inlist(substr(ucod,1,3), "X46", "X47"))

* Firearms
gen cod_acct_firearms=0
replace cod_acct_firearms=1 if inrange(year, 1979, 1998) & (inlist(substr(ucod,1,3), "922"))
replace cod_acct_firearms=1 if inrange(year, 1999, 2014) & (inlist(substr(ucod,1,3), "W32", "W33", "W34"))

** Subcategories within other accidental
* Drowning
gen cod_acct_drowning=0
replace cod_acct_drowning=1 if inrange(year, 1979, 1998) & (inlist(substr(ucod,1,3), "910"))
replace cod_acct_drowning=1 if inrange(year, 1999, 2014) & (inlist(substr(ucod,1,3), "W65", "W66", "W67", "W68", "W69", "W70", "W73", "W74"))

* Define "internal cause" and "other" categories as residuals
gen cod_internal= cod_any - cod_external
gen cod_suicide_other= cod_suicide - (cod_suicide_poisoning + cod_suicide_firearms + cod_suicide_drowning)
gen cod_acct_other= cod_acct - (cod_acct_poisoning + cod_acct_firearms + cod_acct_drowning)

* Suicide + accident subcategories
gen cod_sa=cod_suicide+cod_acct
gen cod_sa_firearms=cod_suicide_firearms+cod_acct_firearms
gen cod_sa_poisoning=cod_suicide_poisoning+cod_acct_poisoning
gen cod_sa_poisoning_subst=cod_suicide_poisoning_subst+cod_acct_poisoning_subst
gen cod_sa_poisoning_gas=cod_suicide_poisoning_gas+cod_acct_poisoning_gas 
gen cod_sa_drowning=cod_suicide_drowning+cod_acct_drowning
gen cod_sa_other=cod_suicide_other+cod_acct_other
	
collapse (sum) cod*, by(staters abbr year monthdth agemo male white) fast

* Verify adding up constraints
assert cod_any == cod_internal + cod_external
assert cod_external == cod_MVA + cod_suicide + cod_homicide + cod_acct + cod_extother
assert cod_suicide == cod_suicide_firearms + cod_suicide_poisoning + cod_suicide_drowning + cod_suicide_other
assert cod_suicide_poisoning == cod_suicide_poisoning_subst + cod_suicide_poisoning_gas
assert cod_acct == cod_acct_firearms + cod_acct_poisoning + cod_acct_drowning + cod_acct_other 
assert cod_acct_poisoning == cod_acct_poisoning_subst + cod_acct_poisoning_gas

order year monthdth abbr staters male white agemo cod_any
sort  year monthdth abbr staters male white agemo

* Label variables
label var cod_any "total deaths"
label var cod_MVA "MVA deaths"
label var cod_homicide "homicides"
label var cod_suicide "suicides"
label var cod_acct "accidents"
label var cod_sa "suicide and accident"
label var cod_extother "other external deaths"
label var cod_external "external deaths"
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
label var cod_internal "internal deaths"
label var male "Gender male indicator"
label var white "Race white indicator"

* Save the data
compress
save "$Driving/processed/intermediate/cdc_mortality_data83to14st.dta", replace

}

******************************************************
***** Minimum driving age laws by state, month *******
******************************************************
if `mdalaw8314'==1 {

* Data on minimum driving age laws for restricted license
clear
import excel "$Driving/data/mda/mda_laws_monthly_1983_2014.xlsx", firstrow

** Minimum driving ages in months
foreach y in "1" "2" "3" "4" {
	
	* Recode minimum driving ages (e.g., change 16.01 to 193 months)
	gen minmda`y'=mda`y'
	
	* Change mda`y' to strings
	tostring mda`y', replace
	
	replace minmda`y'=minmda`y'*12
	replace minmda`y'=16*12+1 if mda`y'=="16.01"
	replace minmda`y'=16*12+3 if mda`y'=="16.03"
	replace minmda`y'=16*12+4 if mda`y'=="16.04"	
	replace minmda`y'=16*12+6 if mda`y'=="16.06"

	replace minmda`y'=15*12+3 if mda`y'=="15.03"	
	replace minmda`y'=15*12+6 if mda`y'=="15.06"
	replace minmda`y'=15*12+9 if mda`y'=="15.09"

	replace minmda`y'=14*12+3 if mda`y'=="14.03"	
	replace minmda`y'=14*12+6 if mda`y'=="14.06"
			
}

** Create full set of state, year, and month
gen start = date("1983-01-15", "YMD")
gen end = date("2015-01-15", "YMD")

* State
gen start_m = mofd(start)
gen ep_end_m = mofd(end)

gen epend_m=1
stset ep_end_m, failure(epend_m) origin(start_m) id(staters)
stsplit month, every(1)

* Year
gen year=ceil((month+1)/12)+1982
replace month=month+1

* Month
forvalues i=1/32 {
	replace month=month-12 if month>=13
}

** Minimum driving age by state, year, and month
** Apply MDA laws by month & MDA changes, using effective dates of the laws
gen mda_months=minmda1
replace mda_months=minmda2 if eff_date_u2!=. & year>yofd(eff_date_u2)
replace mda_months=minmda2 if eff_date_u2!=. & year==yofd(eff_date_u2) & month>month(eff_date_u2)
replace mda_months=minmda2 if eff_date_u2!=. & year==yofd(eff_date_u2) & month==month(eff_date_u2) & day(eff_date_u2)<=15

replace mda_months=minmda3 if eff_date_u3!=. & year>yofd(eff_date_u3)
replace mda_months=minmda3 if eff_date_u3!=. & year==yofd(eff_date_u3) & month>month(eff_date_u3)
replace mda_months=minmda3 if eff_date_u3!=. & year==yofd(eff_date_u3) & month==month(eff_date_u3) & day(eff_date_u3)<=15

replace mda_months=minmda4 if eff_date_u4!=. & year>yofd(eff_date_u4)
replace mda_months=minmda4 if eff_date_u4!=. & year==yofd(eff_date_u4) & month>month(eff_date_u4)
replace mda_months=minmda4 if eff_date_u4!=. & year==yofd(eff_date_u4) & month==month(eff_date_u4) & day(eff_date_u4)<=15

ren month monthdth

* Keep relevant variables
keep staters year monthdth mda_months
sort staters year monthdth

* Label variables
label variable monthdth "Month of death"
label variable year "Year of death"
label variable staters "State fips code"
label variable mda_months "MDA in months"

* Save the data
compress
save "$Driving/processed/intermediate/mdalaws_monthly8314.dta", replace

}


** EOF
