************
* SCRIPT: 4_analysis.do
* PURPOSE: Estimate RD regressions
************

* Preamble (unnecessary when executing run.do)
do "$Driving/scripts/programs/_config.do"

************
* Code begins
************

clear
set more off
tempfile results male_female
local regsave_settings "tstat pval ci cmdline"

* Set the flag equal to 1 to run that analysis, and equal to 0 otherwise
* Note: mortality analysis cannot be run without first obtaining access to the confidential vital statistics data
* Also requires access to the confidential data for Add Health
local rd_addhealth 1
local rd_mortality 1
local rd_mortality_yearbins 1
local rd_mortality_suicide_acct 1
local rd_mortality_robustness 1
local rd_mortality_placebo 1
local adjustedp 1

***
* Formatting settings for graphs
***
* Titles and label formatting
local xtitlesize "size(medlarge)"
local ytitlesize "size(medlarge)"
local xlabsize "labsize(medium)"
local ylabsize "labsize(medium)"
	
* Marker and line fit formatting
local mformat "msym(oh) mcol(red) msize(medlarge)"
local mformat2 "msym(sh) mcol(blue) msize(medlarge)"
local mformat3 "msym(x) mcol(green) msize(medlarge)"
local lformat "clcolor(black) lwidth(medthick)"
local lformat2 "clcolor(black) lwidth(medthick) lpattern(dash)"
local legendsize "size(medlarge)"

***
* Standardized preperation code for the RD regressions
***
cap program drop prep_data_rd
program define prep_data_rd

	syntax , bandwidth(integer)
	
	isid agemo_mda
	
	* Death rates per 100,000 person-years (divide population by 12 age-months)
	* Account for the fact that there are 12 ages in months in a single calendar month (e.g. 16y0m, 16y1m,.., 16y11m in January 1998) 
	* Note: all death rate vars begin with "cod"
	cap unab death_rate_vars : cod*
	qui foreach  y of local death_rate_vars {
		replace `y'=100000*`y'/(pop/12)
		label var `y' "Deaths per 100,000"
	}	
	
	* Above MDA indicator
	gen post=(agemo_mda>=0)
	
	* Construct weights for triangular kernel with bandwidth of 13
	local bw = `bandwidth'
	gen tri_wgt = 0
	qui forval x = 0/`=`bw'-1' {
		replace tri_wgt=(`bw'-`x')/`bw' if agemo_mda==`x'
	}
	qui forval x = 2/`bw' {
		replace tri_wgt=(`bw'-`x'+1)/`bw' if agemo_mda==-(`x'-1)
	}
	
	* Indicator for first month of driving eligibility
	gen firstmonth=(agemo_mda==0)
end

*****************************************
* RD estimates for Add Health outcomes 
*****************************************
if `rd_addhealth'==1 {

	*****
	** Heterogeneity regressions (including the main regression)
	*****

	local replace replace	
	local run_male_female = 0
	qui foreach scenario in "All" "Male" "Female" {
		
		* Add Health data
		local input_filename = lower("`scenario'")
		use "$Driving/data/add_health/derived/`input_filename'.dta", clear	

		local outcomes "DriverLicense VehicleMiles_150 VehicleMiles_265 Work4weeks NotEnrolled"	
		
		* Prep data for RD
		prep_data_rd, bandwidth(13)	
		
		* RD regressions (OLS and MSE-optimal)
		foreach y of varlist `outcomes' {
			
			* Skip outcome-scenario combinations not illustrated in paper
			if ( inlist("`y'","Work4weeks","NotEnrolled") & !inlist("`scenario'","All") ) | ( inlist("`y'","VehicleMiles_265") & !inlist("`scenario'","All","Male","Female") ) continue
			
			* Outcome average
			summ `y' if inrange(agemo_mda, -12,-1)
			local mean_y = r(mean)
			
			* Save OLS estimates for select outcomes	
			reg `y' i.post##c.(agemo_mda) i.firstmonth [aweight=tri_wgt], robust
			predict `y'_hat
			if inlist("`y'","DriverLicense","VehicleMiles_150","VehicleMiles_265") {
				regsave using "`results'", addlabel(y,"`y'",rdspec,ols, mean_y, `mean_y', scenario,"`scenario'") `regsave_settings' `replace'
				local replace append
			}
			
			* Save data to use later for a plot with both males and females
			if inlist("`y'","DriverLicense","VehicleMiles_150") & inlist("`scenario'","Male","Female") {
				preserve
					keep if inrange(agemo_mda, -12, 12)	
					keep `y' `y'_hat agemo_mda
					ren (`y' `y'_hat) (`y'_`scenario' `y'_hat_`scenario')
					
					if `run_male_female'==1 merge 1:1 agemo_mda using "`male_female'", assert(match) nogenerate
					save "`male_female'", replace
					local run_male_female = 1
				restore
			}
		
			rdbwselect `y' agemo_mda, p(1) kernel(triangular) covs(firstmonth) c(0)
			rdrobust `y' agemo_mda, p(1) kernel(triangular) covs(firstmonth) c(0) h(`e(h_mserd)') b(`e(b_mserd)') all
			regsave Robust using "`results'", addlabel(y,"`y'",rdspec,rdrobust, b_conv,`=scalar(_b[Conventional])', mean_y, `mean_y', scenario,"`scenario'") `regsave_settings' append
		}

		* Figures - skip figures not illustrated in paper
		keep if inrange(agemo_mda, -12, 12)	

		foreach y in `outcomes' {
			if inlist("`y'","DriverLicense") | !inlist("`scenario'","All") continue
			local filename "`=lower("`y'")'"
		
			graph twoway (scatter `y' agemo_mda, `mformat') (line `y'_hat agemo_mda if agemo_mda <= -1, `lformat') (line `y'_hat agemo_mda if agemo_mda > 0, `lformat')  ///
						, xtitle("Age (in months) since MDA", `xtitlesize') ytitle("", `ytitlesize') xlabel(-12(2)12, `xlabsize') ylabel(, `ylabsize') graphregion(fcolor(white)) legend(off)
			graph export "$Driving/results/figures/rd_`filename'.pdf", as(pdf) replace
		}
	}
	
	* Output regression results
	use "`results'", clear
	save "$Driving/results/intermediate/addhealth_rd.dta", replace
	
	* Output figure for driver's license and vehicle miles driven (male/female on same plot)
	use "`male_female'", clear
	
	* Driver's license
	graph twoway (scatter DriverLicense_Male agemo_mda, `mformat') (line DriverLicense_hat_Male agemo_mda if agemo_mda <= -1, `lformat') (line DriverLicense_hat_Male agemo_mda if agemo_mda > 0, `lformat')  ///
				 (scatter DriverLicense_Female agemo_mda, `mformat2') (line DriverLicense_hat_Female agemo_mda if agemo_mda <= -1, `lformat2') (line DriverLicense_hat_Female agemo_mda if agemo_mda > 0, `lformat2') ///	
				, xtitle("Age (in months) since MDA", `xtitlesize') ytitle("", `ytitlesize') xlabel(-12(2)12, `xlabsize') ylabel(, `ylabsize') graphregion(fcolor(white))  legend(cols(4) order(1 "Males" 2 "" 4 "Females" 5 "") `legendsize')
	graph export "$Driving/results/figures/rd_license_male_female.pdf", as(pdf) replace

	* Vehicle miles driven
	format *Male %12.0fc
	graph twoway (scatter VehicleMiles_150_Male agemo_mda, `mformat') (line VehicleMiles_150_hat_Male agemo_mda if agemo_mda <= -1, `lformat') (line VehicleMiles_150_hat_Male agemo_mda if agemo_mda > 0, `lformat')  ///
				 (scatter VehicleMiles_150_Female agemo_mda, `mformat2') (line VehicleMiles_150_hat_Female agemo_mda if agemo_mda <= -1, `lformat2') (line VehicleMiles_150_hat_Female agemo_mda if agemo_mda > 0, `lformat2') ///	
				, xtitle("Age (in months) since MDA", `xtitlesize') ytitle("", `ytitlesize') xlabel(-12(2)12, `xlabsize') ylabel(0(500)2500, `ylabsize') graphregion(fcolor(white))  legend(cols(4) order(1 "Males" 2 "" 4 "Females" 5 "") `legendsize')
	graph export "$Driving/results/figures/rd_vmd150_male_female.pdf", as(pdf) replace		
}

********************************
* Main RD mortality estimates
********************************
if `rd_mortality'==1 {
	
	*****
	** Heterogeneity regressions (including the main regression)
	*****
	
	local replace replace
	local run_male_female = 0
	qui foreach scenario in "All" "mda192" "mda_not192" "mda192_Female" "mda_not192_Female" "mda192_Male" "mda_not192_Male" "Male" "Female" {
	
		* Main data for analysis
		local input_filename = lower("`scenario'")
		use "$Driving/data/mortality/derived/`input_filename'.dta", clear
		
		* Causes of death
		unab outcomes : cod_*

		* Prep data for RD	
		prep_data_rd, bandwidth(13)
		
		* RD regressions (OLS and MSE-optimal)
		foreach y of varlist `outcomes' {
			
			* Skip outcome-scenario combinations not illustrated in paper
			if !inlist("`y'","cod_MVA","cod_sa_poisoning") & (strpos("`scenario'","mda")|strpos("`scenario'","birmonth")|!inlist("`scenario'","All","Male","Female")) continue

			* Outcome average
			summ `y' if inrange(agemo_mda, -12,-1)
			local mean_y = r(mean)
			
			summ `y' if inrange(agemo_mda, -1,-1)
			local mean_y_month = r(mean)
			
			reg `y' i.post##c.(agemo_mda) i.firstmonth [aweight= tri_wgt], robust
			predict `y'_hat
			regsave using "`results'", addlabel(y,"`y'",rdspec,ols, mean_y, `mean_y', mean_y_month, `mean_y_month', scenario,"`scenario'") `regsave_settings' `replace'
			local replace append
			
			* Save data to use later for a plot with both males and females
			if inlist("`y'","cod_any","cod_MVA") & inlist("`scenario'","Male","Female") {
				preserve
					keep if inrange(agemo_mda, -12, 12)	
					keep `y' `y'_hat agemo_mda
					ren (`y' `y'_hat) (`y'_`scenario' `y'_hat_`scenario')
					
					if `run_male_female'==1 merge 1:1 agemo_mda using "`male_female'", assert(match) nogenerate
					save "`male_female'", replace
					local run_male_female = 1
				restore
			}			
		
			rdbwselect `y' agemo_mda, p(1) kernel(triangular) covs(firstmonth) c(0)
			rdrobust `y' agemo_mda, p(1) kernel(triangular) covs(firstmonth) c(0) h(`e(h_mserd)') b(`e(b_mserd)') all
			
			regsave Robust using "`results'", addlabel(y,"`y'",rdspec,rdrobust, b_conv, `=scalar(_b[Conventional])', mean_y, `mean_y', mean_y_month, `mean_y_month', scenario,"`scenario'") `regsave_settings' append
		}
	
		* Figures - skip scenarios not illustrated in paper
		keep if inrange(agemo_mda, -12, 12)
			
		if !inlist("`scenario'", "Male", "Female") continue
		local filename `=lower("`scenario'")'
			
		* Figure: all causes, external, internal
		graph twoway (scatter cod_any agemo_mda, `mformat') (line cod_any_hat agemo_mda if agemo_mda <= -1, `lformat') (line cod_any_hat agemo_mda if agemo_mda > 0, `lformat') ///
					 (scatter cod_external agemo_mda, `mformat2') (line cod_external_hat agemo_mda if agemo_mda <= -1, `lformat') (line cod_external_hat agemo_mda if agemo_mda > 0, `lformat') /// 
					 (scatter cod_internal agemo_mda, `mformat3') (line cod_internal_hat agemo_mda if agemo_mda <= -1, `lformat') (line cod_internal_hat agemo_mda if agemo_mda > 0, `lformat') ///
					 , xtitle("Age (in months) since MDA", `xtitlesize') ytitle("Deaths per 100,000", `ytitlesize') xlabel(-12(2)12, `xlabsize') ylabel(, `ylabsize' gmax gmin) graphregion(fcolor(white)) legend(order(1 "All" 4 "External" 7 "Internal") `legendsize')
		if inlist("`scenario'", "Male", "Female") graph export "$Driving/results/figures/rd_any_ext_int_`filename'.pdf", as(pdf) replace
		
		* Figures by heterogeneity specifications
		foreach y of varlist `outcomes' {
			local filename : subinstr local y "cod_" ""	
			local filename `=lower("`filename'_`scenario'")'
			
			
			* Output figures illustrated in paper
			if ( strpos("`scenario'","mda") ) continue
			if inlist("`y'","cod_any","cod_external","cod_internal","cod_MVA","cod_homicide")|inlist("`y'","cod_sa","cod_sa_firearms","cod_sa_other","cod_acct_poisoning","cod_suicide_poisoning") continue
			graph twoway (scatter `y' agemo_mda,  `mformat') (line `y'_hat agemo_mda if agemo_mda <= -1, `lformat') (line `y'_hat agemo_mda if agemo_mda > 0, `lformat')  ///
    			 , xtitle("Age (in months) since MDA") ytitle("Deaths per 100,000") xlabel(-12(2)12) graphregion(fcolor(white)) legend(off)				 			
			graph export "$Driving/results/figures/rd_`filename'.pdf", as(pdf) replace
			
		}
	}
	
	* Output regression results
	use "`results'", clear
	save "$Driving/results/intermediate/mortality_rd.dta", replace
	
	* Output main figure for all causes and MVA (male/female on same plot)
	use "`male_female'", clear
	
	* All causes
	graph twoway (scatter cod_any_Male agemo_mda, `mformat') (line cod_any_hat_Male agemo_mda if agemo_mda <= -1, `lformat') (line cod_any_hat_Male agemo_mda if agemo_mda > 0, `lformat')  ///
				 (scatter cod_any_Female agemo_mda, `mformat2') (line cod_any_hat_Female agemo_mda if agemo_mda <= -1, `lformat2') (line cod_any_hat_Female agemo_mda if agemo_mda > 0, `lformat2') ///
				, xtitle("Age (in months) since MDA", `xtitlesize') ytitle("Deaths per 100,000", `ytitlesize') xlabel(-12(2)12, `xlabsize') ylabel(20(15)80, `ylabsize') graphregion(fcolor(white)) legend(cols(4) order(1 "Males" 2 "" 4 "Females" 5 "") `legendsize')
	graph export "$Driving/results/figures/rd_any_male_female.pdf", as(pdf) replace
	
	* MVA
	graph twoway (scatter cod_MVA_Male agemo_mda, `mformat') (line cod_MVA_hat_Male agemo_mda if agemo_mda <= -1, `lformat') (line cod_MVA_hat_Male agemo_mda if agemo_mda > 0, `lformat')  ///
				 (scatter cod_MVA_Female agemo_mda, `mformat2') (line cod_MVA_hat_Female agemo_mda if agemo_mda <= -1, `lformat2') (line cod_MVA_hat_Female agemo_mda if agemo_mda > 0, `lformat2') ///	
				, xtitle("Age (in months) since MDA", `xtitlesize') ytitle("Deaths per 100,000", `ytitlesize') xlabel(-12(2)12, `xlabsize') ylabel(, `ylabsize') graphregion(fcolor(white))  legend(cols(4) order(1 "Males" 2 "" 4 "Females" 5 "") `legendsize')
	graph export "$Driving/results/figures/rd_mva_male_female.pdf", as(pdf) replace	
}

***************************************************************
* RD mortality over time estimates, separately by male/female
***************************************************************

if `rd_mortality_yearbins'==1 {
	
	* Number of years in the bin
	local num_yrs = 4
	
	local replace replace
	qui forval yr = 1983(`num_yrs')2013 {
	qui foreach scenario in "Male" "Female" {
		
		* Main data for analysis
		local input_filename = lower("`scenario'")
		use "$Driving/data/mortality/derived/`input_filename'_`yr'.dta", clear
		
		* Causes of death
		local outcomes "cod_MVA cod_sa_poisoning"	

		* Prep data for RD		
		prep_data_rd, bandwidth(13)
		
		* RD regressions (MSE-optimal)
		foreach y of varlist `outcomes' {
			
			* Outcome average
			summ `y' if inrange(agemo_mda, -12,-1)
			local mean_y = r(mean)
			
			summ `y' if inrange(agemo_mda, -1,-1)
			local mean_y_month = r(mean)
			
			* OLS used for fitted lines only
			reg `y' i.post##c.(agemo_mda) i.firstmonth [aweight = tri_wgt], robust
			predict `y'_hat
		
			rdbwselect `y' agemo_mda, p(1) kernel(triangular) covs(firstmonth) c(0)
			rdrobust `y' agemo_mda, p(1) kernel(triangular) covs(firstmonth) c(0) h(`e(h_mserd)') b(`e(b_mserd)') all
			
			regsave Robust using "`results'", addlabel(y,"`y'",rdspec,rdrobust, b_conv, `=scalar(_b[Conventional])', mean_y, `mean_y', mean_y_month, `mean_y_month', scenario,"`scenario'",years,"`yr'") `regsave_settings' `replace'
			local replace append
		}
	}
	}

	* Figures - for MVA and poisoning by sex
	foreach y in cod_MVA cod_sa_poisoning {
	foreach scen in Male Female {
    
		* RD mortality over time estimates
		use "`results'", clear
	
		keep if y=="`y'"
		keep if scenario=="`scen'"
		keep if var=="Robust"
		replace coef = b_conv if var=="Robust"
	
		if "`scen'" == "Male" local color "red"
		if "`scen'" == "Female" local color "blue"
		
		local filename "`=lower("`y'_`scen'")'"
		
		* Output figure
		graph twoway (connected coef years,  clcolor(`color') clpattern(solid) lwidth(thick) msym(circle) mcol(`color') msize(large)) ///
					 (line ci_lower years,  clcolor(`color') clpattern(dash) lwidth(medium) ) ///
					 (line ci_upper years,  clcolor(`color') clpattern(dash) lwidth(medium) ) ///
					 , xtitle("Year", `xtitlesize') ytitle("Deaths per 100,000", `ytitlesize') xlabel(1983(4)2013, `xlabsize') ylabel(, `ylabsize') graphregion(fcolor(white)) legend(order(1 "`scen' estimate" 2 "95% confidence interval") `legendsize') yline(0)
		graph export "$Driving/results/figures/yearbins_`filename'.pdf", as(pdf) replace
	}
	}
	
}

*******************************************************
* RD estimates separately for suicides and accidents
*******************************************************
if `rd_mortality_suicide_acct'==1 {
	
	local replace replace
	qui foreach scenario in "Male" "Female" {
		
		* Main data for analysis
		local input_filename = lower("`scenario'")
		use "$Driving/data/mortality/derived/sa_`input_filename'.dta", clear

		* Causes of death
		local outcomes "cod_suicide* cod_acct* cod_sa*"	

		* Prep data for RD			
		prep_data_rd, bandwidth(13)
		
		* RD regressions (MSE-optimal)
		foreach y of varlist `outcomes' {
			
			* Outcome average
			summ `y' if inrange(agemo_mda, -12,-1)
			local mean_y = r(mean)
			
			summ `y' if inrange(agemo_mda, -1,-1)
			local mean_y_month = r(mean)
			
			* OLS used for fitted lines only
			reg `y' i.post##c.(agemo_mda) i.firstmonth [aweight = tri_wgt], robust
			predict `y'_hat
		
			rdbwselect `y' agemo_mda, p(1) kernel(triangular) covs(firstmonth) c(0)
			rdrobust `y' agemo_mda, p(1) kernel(triangular) covs(firstmonth) c(0) h(`e(h_mserd)') b(`e(b_mserd)') all
			
			regsave Robust using "`results'", addlabel(y,"`y'",rdspec,rdrobust, b_conv, `=scalar(_b[Conventional])', mean_y, `mean_y', mean_y_month, `mean_y_month', scenario,"`scenario'",years,"`yr'")  `regsave_settings' `replace'
			local replace append
		}		
	}
	
	* Output regression results
	use "`results'", clear
	save "$Driving/results/intermediate/mortality_rd_suicide_acct.dta", replace
}

************************************************************
* Robustness checks (different polynomials and bandwidths)
************************************************************
if `rd_mortality_robustness'==1 {
	
	local replace replace
	qui foreach scenario in "All" "Male" "Female" {
		
		* Main data for analysis
		local input_filename = lower("`scenario'")
		use "$Driving/data/mortality/derived/`input_filename'.dta", clear
		
		* Causes of death
		local outcomes "cod_any cod_MVA cod_sa_poisoning"	

		* Prep data for RD				
		prep_data_rd, bandwidth(13)

		* RD regressions
		foreach y of varlist `outcomes' {
			
			* Outcome average
			summ `y' if inrange(agemo_mda, -12,-1)
			local mean_y = r(mean)
			
			* Robustness: different polynomials
			foreach order_poly in 1 2 3 {
				
				* Estimate and store optimal bandwidths
				rdbwselect `y' agemo_mda, p(`order_poly') kernel(triangular) covs(firstmonth) c(0)
				local bw=`e(h_mserd)'
				local bw_bias=`e(b_mserd)'

				rdrobust `y' agemo_mda, p(`order_poly') kernel(triangular) covs(firstmonth) c(0) h(`bw') b(`bw_bias') all
				regsave Robust using "`results'", addlabel(y, "`y'", rdspec, rdrobust, b_conv, `=scalar(_b[Conventional])', mean_y, `mean_y', scenario,"`scenario'", order_poly, "`order_poly'", bw, "`bw'", bw_bias, "`bw_bias'") `regsave_settings' `replace'
				local replace append
			}
			
			* Robustness: alternative bandwidths MSE-optimal CCT (common, two), CER-optimal CCT (common, two)
			foreach bws in "mserd" "msetwo" "cerrd" "certwo" {
				
				* Estimate and store optimal bandwidths for the estimate and for the bias-corrected confidence intervals
				rdbwselect `y' agemo_mda, p(1) kernel(triangular) covs(firstmonth) c(0) bwselect("`bws'")
				
				* Common bandwidths (left=right)
				if "`bws'"=="mserd" | "`bws'"=="cerrd" {
					local belowbw      = `e(h_`bws')'
					local belowbw_bias = `e(b_`bws')'
					
					local abovebw "`belowbw'"
					local abovebw_bias "`belowbw_bias'"
				}
				
				* Different bandwidth for left and right
				else if "`bws'"=="msetwo" | "`bws'"=="certwo" {
					local belowbw      = `e(h_`bws'_l)'
					local abovebw      = `e(h_`bws'_r)'
					local belowbw_bias = `e(b_`bws'_l)'
					local abovebw_bias = `e(b_`bws'_r)'
					
					* rdrobust selects an optimal left bandwidth < 5 for one scenario, but then generates an error because the bandwidth is too small. Override by setting equal to 5.
					if "`bws'"=="certwo" & "`scenario'"=="Female" & "`y'"=="cod_sa_poisoning" {
						local belowbw "5.001"
					}					
				}
				
				local h_bw "`belowbw' `abovebw'"
				local b_bw "`belowbw_bias' `abovebw_bias'"

				rdrobust `y' agemo_mda, p(1) kernel(triangular) covs(firstmonth) c(0) h(`h_bw') b(`b_bw') all
				regsave Robust using "`results'", addlabel(y,"`y'",rdspec,rdrobust, b_conv, `=scalar(_b[Conventional])', mean_y, `mean_y', scenario,"`scenario'", bwselection, "`bws'", belowbw, `belowbw', abovebw, `abovebw', belowbw_bias, `belowbw_bias', abovebw_bias, `abovebw_bias' ) `regsave_settings' append
			}
		}	
	}
	
	* Output regression results
	use "`results'", clear
	save "$Driving/results/intermediate/mortality_rd_robustness.dta", replace
}

***********************
* Placebo analysis
***********************
if `rd_mortality_placebo'==1 {
	
	local replace replace
	qui foreach scenario in "All" "Male" "Female" {
	
		* Main data for analysis
		local input_filename = lower("`scenario'")
		use "$Driving/data/mortality/derived/`input_filename'.dta", clear

		* Causes of death
		local outcomes "cod_MVA cod_sa_poisoning"	
		
		* Prep data for RD	
		prep_data_rd, bandwidth(13)		
		
		preserve
		
		* RDs using placebo cutoffs on each side of the actual cutoff using half the data (plus cutoff=0 for comparison)
		foreach cutoff of numlist -36/-12 0 12/36 {

			restore, preserve
			
			* Exclude cutoff=0 from placebo tests because of measurement error issues
			if `cutoff'<0 drop if agemo_mda >= 0
			if `cutoff'>0 drop if agemo_mda <= 0
			
			* Indicator for first month of driving eligibility with placebo cutoffs
			gen firstmonth_p=(agemo_mda==`cutoff')
			
			* RD regressions (MSE-optimal only)
			foreach y of varlist `outcomes' {

				rdbwselect `y' agemo_mda, p(1) kernel(triangular) covs(firstmonth) c(`cutoff')
				local h_bw = max(`e(h_mserd)',5.01)
				local b_bw = max(`e(b_mserd)',5.01)
				
				rdrobust `y' agemo_mda, p(1) kernel(triangular) covs(firstmonth_p) c(`cutoff') h(`h_bw') b(`b_bw') all
				
				regsave Robust using "`results'", addlabel(y,"`y'",rdspec,rdrobust,b_conv,`=scalar(_b[Conventional])',placebo_cutoff,"`cutoff'",scenario,"`scenario'") `regsave_settings' `replace'
				local replace append
			}
		}
		restore, not
	}
	
	* Output regression results
	use "`results'", clear
	save "$Driving/results/intermediate/mortality_rd_placebo.dta", replace
	
}

*********************************
* Multiple hypothesis testing   
*********************************
if `adjustedp' {
	
	* Multiple hypothesis code comes from wyoung.ado (Jones, Molitor, and Reif 2019)
	program drop _all
	program define calc_adjustedp

		ren pval p

		* Include k in the sort to break ties
		gen k = _n
		sort group p k

		tempname j
		by group: gen `j' = _N-_n+1
			
		by group: gen double pbonf = min(p*`j',1) if _n==1
		by group: replace    pbonf = min(max(p*`j',pbonf[_n-1]),1) if _n>1

		by group: gen double psidak = min((1-(1-p)^(`j')),1) if _n==1
		by group: replace    psidak = min(max((1-(1-p)^(`j')),psidak[_n-1]),1) if _n>1
		
		by group: gen num_H0 = _N
		
		label var coef "Coefficient"
		label var y "Outcome variable"
		label var p "Unadjusted"
		label var pbonf "Bonferroni-Holm"
		label var psidak "Sidak-Holm"	
		label var num_H0 "Number of hypotheses"
	end	
	
	***
	* Mortality outcomes
	***
	use "$Driving/results/intermediate/mortality_rd.dta", clear
	isid var y scenario
	keep if inlist(scenario,"All","Male","Female")

	* For rdrobust, we will use the point estimate from "conventional" estimate and inference from "robust" bias-correction
	keep if inlist(var,"Robust","1.post")
	replace coef = b_conv if var=="Robust"

	* Keep relevant variables in family. Family defined as RD spec (robust/OLS) X subgroup(all or male/female)
	drop if strpos(y,"_acct") | strpos(y,"_suicide")
	gen group     = 10 if var=="Robust"
	replace group = 20 if var=="1.post"
	replace group = group+1 if scenario=="All"
	
	calc_adjustedp
	keep rdspec var y scenario num_H0 pbonf psidak
	tempfile adjustedp
	save "`adjustedp'", replace

	***
	* Add health outcomes
	***
	use "$Driving/results/intermediate/addhealth_rd.dta", clear
	keep if inlist(scenario,"All","Male","Female")
	isid var y scenario

	* For rdrobust, we will use the point estimate from "conventional" estimate and inference from "robust" bias-correction
	keep if inlist(var,"Robust","1.post")
	replace coef = b_conv if var=="Robust"
	
	* Adjust done for RD spec (robust/OLS), and subgroup (full or M/F)
	drop if inlist(y,"Work4weeks","DriverLicense","VehicleMiles_150","VehicleMiles_265")
	gen group     = 100 if var=="Robust"
	replace group = 200 if var=="1.post"
	replace group = group + 10 if scenario=="All"
	
	* Output adjusted p-values
	calc_adjustedp
	keep rdspec var y scenario num_H0 pbonf psidak
	append using "`adjustedp'"
	save "$Driving/results/intermediate/adjustedp.dta", replace
}


** EOF
