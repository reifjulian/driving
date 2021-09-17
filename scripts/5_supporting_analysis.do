************
* SCRIPT: 5_supporting_analysis.do
* PURPOSE: Calculate and confirm miscellaneous statistic; create supplemental figures
************

* Preamble (unnecessary when executing run.do)
do "$Driving/scripts/programs/_config.do"

************
* Code begins
************

clear
set more off

* Note: FARS code is disabled because the raw data are not included in this replication package
local fars 0

* Titles and label formatting
local xtitlesize "size(medlarge)"
local ytitlesize "size(medlarge)"
local xlabsize "labsize(medium)"
local ylabsize "labsize(medium)"
	
* Marker and line fit formatting
local mformat "msize(small)"
local mformat2 "msize(large)"
local lformat "lwidth(thick)"
local lformat2 "lwidth(vthick)"
local legendsize "size(medlarge)"
local legendsize2 "size(small)"


***
* Population size
***

use "$Driving/data/seer/derived/seer_pop1983_2014st.dta", clear
keep if age==16

collapse (sum) pop, by(year) fast
sum pop

* "There was an average of 3.9 million 16-year-olds alive in the United States during 1983-2014."
assert abs(r(mean)-3931562)<1

***
* Unadjusted p-value statement
***

* "A multiple testing correction would need to adjust for many thousands of hypotheses to increase the unadjusted p-value (p<0.00001) above the conventional significance level of 0.05."
use "$Driving/results/intermediate/mortality_rd.dta", clear
keep if y=="cod_sa_poisoning"
keep if scenario=="Female"

assert pval < 0.00001 if rdspec=="rdrobust"

***
* Working for pay outcome (Add Health)
***

* "The MSE-optimal RD estimate from equation (1) is an increase in working for pay of 2.9 percentage points (p=0.411), with a 95% robust bias-corrected confidence interval of [-0.0385, 0.0942]."
use "$Driving/results/intermediate/addhealth_rd.dta", clear
keep if y=="Work4weeks" & rdspec=="rdrobust" & scenario=="All"
replace coef = b_conv if var=="Robust"
assert _N==1
assert abs(coef-.0293628)<0.000001
assert abs(pval-.4107024)<0.000001
assert abs(ci_lower+.0384839)<0.0000001
assert abs(ci_upper-.0941577)<0.0000001

***
* Not enrolled in school outcome (Add Health)
***

* "The MSE-optimal estimate for not enrolled in school is -0.021 percentage points (p=0.829), with a 95% robust bias-corrected confidence interval of [-0.0104, 0.0083]."
use "$Driving/results/intermediate/addhealth_rd.dta", clear
keep if y=="NotEnrolled" & rdspec=="rdrobust" & scenario=="All"
replace coef = b_conv if var=="Robust"
assert _N==1
assert abs(coef+.000211)<0.000001
assert abs(pval-.8289872)<0.000001
assert abs(ci_lower+.010356)<0.0000001
assert abs(ci_upper-.0083)<0.0000001

*****************************************************
****** Appendix Figures: aggregate mortality trends *
*****************************************************

* Main data for analysis
use "$Driving/data/mortality/derived/sex_agegroup_8314.dta", clear

* Restrict to ages 15-19 (i.e., group 2)
keep if agegroup==2

* Causes of death
local vars "cod_any cod_MVA cod_sa cod_sa_poisoning cod_sa_firearms cod_sa_drowning cod_sa_other"
compress
	
* Collapse by year and gender
collapse (sum) `vars' pop, by(year male) fast

* Death rates per 100,000
foreach y in `vars' {
	replace `y'=100000*`y'/pop
}

* Generate cause-by-agegroup categories for figures
gen All_male=cod_any                  if male==1
gen MVA_male=cod_MVA                  if male==1
gen SA_male=cod_sa                    if male==1	
gen poisoning_male=cod_sa_poisoning   if male==1
gen firearm_male=cod_sa_firearms      if male==1
gen drowning_male=cod_sa_drowning     if male==1
gen other_male=cod_sa_other           if male==1
gen All_female=cod_any                if male==0
gen MVA_female=cod_MVA                if male==0	
gen SA_female=cod_sa                  if male==0
gen poisoning_female=cod_sa_poisoning if male==0
gen firearm_female=cod_sa_firearms    if male==0
gen drowning_female=cod_sa_drowning   if male==0
gen other_female=cod_sa_other         if male==0
	
* All causes, MVA, suicide and accident
graph twoway (line All_male year,  clcolor(blue) clpattern(solid) `lformat' msym(oh) mcol(blue) `mformat') /// 
			 (line MVA_male year,  clcolor(red) clpattern(dash) `lformat' msym(sh) mcol(red) `mformat') ///
			 (line SA_male year, clcolor(green) clpattern(dot) `lformat2' msym(X) mcol(green) `mformat' yaxis(2)) ///
			 , xtitle("Year", `xtitlesize') xlabel(1983 1985 1990 1995 2000 2005 2010 2014, `xlabsize' angle(vertical)) ytitle("Deaths per 100,000", `ytitlesize') ylabel(0(20)140, `ylabsize' gmax gmin) ytitle("Deaths per 100,000", `ytitlesize' axis(2)) ylabel(0(6)36, `ylabsize' axis(2)) graphregion(fcolor(white)) legend(order(1 "All causes" 2 "Motor vehicle accident" 3 "Suicide and accident (right axis)") `legendsize2') 
graph export "$Driving/results/figures/appendix_mort_trends_male.pdf", as(pdf) replace	

graph twoway (line All_female  year, clcolor(blue) clpattern(solid) `lformat' msym(oh) mcol(blue) `mformat') /// 
			 (line MVA_female  year, clcolor(red) clpattern(dash) `lformat' msym(sh) mcol(red) `mformat') ///
			 (line SA_female year, clcolor(green) clpattern(dot) `lformat2' msym(X) mcol(green) `mformat' yaxis(2)) ///
			 , xtitle("Year", `xtitlesize') xlabel(1983 1985 1990 1995 2000 2005 2010 2014, `xlabsize' angle(vertical)) ytitle("Deaths per 100,000", `ytitlesize') ylabel(0(20)60, `ylabsize' gmax gmin) ytitle("Deaths per 100,000", `ytitlesize' axis(2)) ylabel(0(2)8, `ylabsize' axis(2)) graphregion(fcolor(white)) legend(order(1 "All causes" 2 "Motor vehicle accident" 3 "Suicide and accident (right axis)") `legendsize2') 
graph export "$Driving/results/figures/appendix_mort_trends_female.pdf", as(pdf) replace

* Poisoning, firearms, drowning, other
foreach y in poisoning firearm drowning other {

	graph twoway (line `y'_male year, clcolor(red) clpattern(dash) `lformat' msym(sh) mcol(red) `mformat') ///
				 (line `y'_female year, clcolor(blue) clpattern(solid) `lformat' msym(oh) mcol(blue) `mformat') ///
				 , xtitle("Year", `xtitlesize') xlabel(1983 1985 1990 1995 2000 2005 2010 2014, `xlabsize' angle(vertical)) ytitle("Deaths per 100,000", `ytitlesize') graphregion(fcolor(white)) ylabel(, `ylabsize' gmax gmin) legend(order(1 "Males" 2 "Females") `legendsize') 
	graph export "$Driving/results/figures/appendix_mort_trends_`y'.pdf", as(pdf) replace

}

********************************************************************
******* Appendix Figure: fraction of teenagers with license (FHWA) *
********************************************************************

* FHWA licensed drivers data
use "$Driving/processed/fhwa_8314.dta", clear
	
* Calculate age-specific licensing rates
gen age16_yr=total_16/pop_16*1000
gen age17_yr=total_17/pop_17*1000
gen age18_yr=total_18/pop_18*1000
gen age19_yr=total_19/pop_19*1000	


graph twoway (line age16_yr year,  clcolor(green) clpattern(solid) `lformat' msym(X) mcol(green) `mformat') ///
			 (line age17_yr year,  clcolor(red) clpattern(dash) `lformat' msym(sh) mcol(red) `mformat') ///
			 (line age18_yr year,  clcolor(orange) clpattern(dot) `lformat2' msym(th) mcol(orange) `mformat') ///
			 (line age19_yr year,  clcolor(purple) clpattern(dash_dot) `lformat' msym(dh) mcol(purple) `mformat') ///
			 , xtitle("Year", `xtitlesize') ylabel(0(.2).9, `ylabsize') xlabel(1983 1985 1990 1995 2000 2005 2010 2014, `xlabsize' angle(vertical))  graphregion(fcolor(white)) legend(order(1 "Age 16" 2 "Age 17" 3 "Age 18" 4 "Age 19") `legendsize') 
graph export "$Driving/results/figures/appendix_license_trends_ages1619.pdf", as(pdf) replace

*******************************************
****** Driving fatality statistics (FARS) *
*******************************************
if `fars'==1 {

* FARS data
use "$Driving/processed/fars_8314.dta", clear

* Determine first year of driving eligibility
gen mda_age = floor(mda_months/12)

* Teenage driver killed within first year of driving eligibility
gen teenagedriver_decs = (age==mda_age & per_typ==1 & inj_sev==4)

* Identify accidents involving a killed teenage driver
bysort staters year st_case: egen tdriver_decs = sum(teenagedriver_decs)

* Identify others killed
gen others_decs = (teenagedriver_decs==0 & tdriver_decs>=1 & inj_sev==4)

preserve

	* Sum over accidents involving teenage driver/s 
	collapse (sum) others_decs if tdriver_decs>=1, by(staters year st_case) fast

	***
	* "on average an additional 0.24 people died for every car accident where a newly eligible teen driver died at the wheel."
	***
	sum others_decs
	assert abs(r(mean)-.2412298)<0.0001

restore 

* Teenage driver within first year of driving eligibility
gen teenagedriver = (age==mda_age & per_typ==1)

* Identify accidents involving teenage drivers
bysort staters year st_case: egen tdriver = sum(teenagedriver)

* Identify others killed in accidents involving teenage driver/s with no teenage driver killed
gen deaths_ntdriver = (inj_sev==4 & tdriver>=1 & tdriver_decs==0)

* Identify all deaths in accidents involving teenage driver death/s
gen deaths_tdriver = (inj_sev==4 & tdriver_decs>=1)

* Sum over accidents
collapse (sum) deaths_ntdriver deaths_tdriver, fast

****
* "among all fatal car accidents involving a newly eligible teenage driver at the wheel, the accidents where that teenage driver died account for only 45% of the total fatalities."
****
assert ((deaths_tdriver / (deaths_tdriver + deaths_ntdriver)) -.45139108 )< 0.0001
}

**********************************************
******** Appendix Figures: placebo estimates *
**********************************************

* For MVA and poisoning by sex
qui foreach scenario in "All" "Male" "Female" {
	foreach cod in "cod_MVA" "cod_sa_poisoning" {
		
		* Placebo RD estimates
		use "$Driving/results/intermediate/mortality_rd_placebo.dta", clear
			
		* Subset the data down according to the heterogeneity specification of interest
		keep if scenario=="`scenario'"
		local filename "`=lower("`cod'_`scenario'")'"
		
		* Output figures
		if "`cod'"=="cod_MVA" {
			summ tstat if y=="`cod'" & placebo_cutoff==0
			local rd_actual_`cod' = r(mean)				
			hist tstat if y=="`cod'", freq xline(`rd_actual_`cod'', lp(dash) lc(blue)) width(.2) xtitle("t-statistic") graphregion(fcolor(white)) fcolor(red) fintensity(inten70) lcolor(black)
			graph export "$Driving/results/figures/placebo_`filename'.pdf", as(pdf) replace
		}	
		if "`cod'"=="cod_sa_poisoning" {
			summ tstat if y=="`cod'" & placebo_cutoff==0
			local rd_actual_`cod' = r(mean)				
			hist tstat if y=="`cod'", freq xline(`rd_actual_`cod'', lp(dash) lc(blue)) width(.2) xtitle("t-statistic") graphregion(fcolor(white)) fcolor(red) fintensity(inten70) lcolor(black)
			graph export "$Driving/results/figures/placebo_`filename'.pdf", as(pdf) replace	
		}
	}
}

********************************************
******** Compulsory school attendance laws *
********************************************

* Compulsory attendance ages
import excel "$Driving/data/schoolage/schoolage_laws_1994_2014.xls", firstrow clear

reshape long yr, i(staters) j(year)  
ren yr comp_age

* Minimum age for dropping out out of school
gen min_age=substr(comp_age, -2, 2)
destring min_age, replace
assert inrange(min_age,16,18) if !mi(min_age)

replace min_age=min_age*12
label var min_age "Minimum school leaving age (months)"

* Add MDA law data
merge 1:m staters year using "$Driving/processed/intermediate/mdalaws_monthly8314.dta", assert(using match) nogenerate keep(match)

* Identify exact matches
assert !mi(mda_months )
gen match = mda_months==min_age if !mi(min_age)

* "For those 13 years, 52% of our state-year observations have a minimum school leaving age equal to 16 years. The MDA in 31% of states is the same as the minimum school leaving age during those 13 years. However, the minimum school leaving age is not equal to the MDA in any state where the MDA is not 16 years." 
count if min_age==192
assert abs(r(N)/_N - .52036199) < 0.0001
summ match
assert abs(r(mean)-0.3087121)<0.0001
assert match==0 if mda_months!=192
assert mda_months==192 if match==1

*************************************************
******** Appendix Figure: trends in teenage VMT *
*************************************************

* Data on vehicle miles traveled per licensed driver
import excel "$Driving/data/nhts/nhts_1983_2017.xlsx", firstrow clear
format *1619 %12.0fc

* Output figure for ages 16-19
graph twoway (connected both_1619 year, clcolor(green) clpattern(dot) `lformat' msym(O) mcol(green) `mformat2') ///
			 (connected male_1619 year,  clcolor(red) clpattern(dash) `lformat' msym(O) mcol(red) `mformat2') ///
		     (connected female_1619 year,  clcolor(blue) clpattern(solid) lwidth(thick) msym(O) mcol(blue) `mformat2') /// 
			 , xtitle("Year", `xtitlesize') xlabel(1983 1990 1995 2001 2009 2017, `xlabsize' angle(vertical)) ytitle("VMT per licensed driver", `ytitlesize') ylabel(0(2000)10000, `ylabsize' gmax gmin) graphregion(fcolor(white)) legend(order(1 "All" 2 "Male" 3 "Female") `legendsize') 
graph export "$Driving/results/figures/appendix_vmt_trends_ages1619.pdf", as(pdf) replace	
	
	
** EOF
