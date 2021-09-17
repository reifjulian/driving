**********************
* OVERVIEW
*   This script generates tables and figures for the paper:
*       "Teenage Driving, Mortality, and Risky Behaviors" (Jason Huh and Julian Reif)
*   All raw data are stored in /data
*   All tables are outputted to /results/tables
*   All figures are outputted to /results/figures
* 
* SOFTWARE REQUIREMENTS
*   Analyses run on Windows using Stata version 16
*
* TO PERFORM A CLEAN RUN, DELETE THE FOLLOWING TWO FOLDERS:
*   /processed
*   /results
**********************

* User must define this global macro to point to the folder path that includes this run.do script
global Driving ""

* Confirm that the global for the project root directory was defined
assert !missing("$Driving")

* Initialize log and record system parameters
clear
set more off
cap mkdir "$Driving/scripts/logs"
cap log close
local datetime : di %tcCCYY.NN.DD!-HH.MM.SS `=clock("$S_DATE $S_TIME", "DMYhms")'
local logfile "$Driving/scripts/logs/`datetime'.log.txt"
log using "`logfile'", text

di "Begin date and time: $S_DATE $S_TIME"
di "Stata version: `c(stata_version)'"
di "Updated as of: `c(born_date)'"
di "Variant:       `=cond( c(MP),"MP",cond(c(SE),"SE",c(flavor)) )'"
di "Processors:    `c(processors)'"
di "OS:            `c(os)' `c(osdtl)'"
di "Machine type:  `c(machine_type)'"

* All required Stata packages are available in the /libraries/stata folder
tokenize `"$S_ADO"', parse(";")
while `"`1'"' != "" {
  if `"`1'"'!="BASE" cap adopath - `"`1'"'
  macro shift
}
adopath ++ "$Driving/scripts/libraries/stata"
mata: mata mlib index

* Stata version control
version 16

* Create directories for output files
cap mkdir "$Driving/processed"
cap mkdir "$Driving/processed/intermediate"
cap mkdir "$Driving/results"
cap mkdir "$Driving/results/figures"
cap mkdir "$Driving/results/intermediate"
cap mkdir "$Driving/results/tables"

* Run all project scripts
do "$Driving/scripts/1_import_data.do"
do "$Driving/scripts/2_clean_data.do"
do "$Driving/scripts/3_combine_data.do"
do "$Driving/scripts/4_analysis.do"
do "$Driving/scripts/5_supporting_analysis.do"
do "$Driving/scripts/6_tables.do"

* End log
di "End date and time: $S_DATE $S_TIME"
log close

** EOF
