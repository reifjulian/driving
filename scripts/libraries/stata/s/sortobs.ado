*! sortobs 1.1 16sep2010 by Julian Reif

* 1.1: added before and after options. Removed reverse option

program define sortobs, nclass
	version 8.2
	
	syntax [varname(default=none)], VALues(string asis) [first last before(string) after(string)]
	
	************************
	***  ERROR CHECKING  ***
	************************
	
	* before() error checking
	if (`"`before'"' != "" & `"`after'"' != "") {
		dis as error "before() may not be combined with after()"
		exit 198
	}
	if (`"`before'"' != "" & `"`first'"' != "") {
		dis as error "before() may not be combined with first()"
		exit 198
	}
	if (`"`before'"' != "" & `"`last'"' != "") {
		dis as error "before() may not be combined with last()"
		exit 198
	}

	* after() error checking 
	if (`"`after'"' != "" & `"`first'"' != "") {
		dis as error "after() may not be combined with first()"
		exit 198
	}
	if (`"`after'"' != "" & `"`last'"' != "") {
		dis as error "after() may not be combined with last()"
		exit 198
	}

	* first/last error checking 
	if ("`first'" != "" & "`last'" != "") {
		dis as error "first may not be combined with last"
		exit 198
	}
	
	* Count number of observations
	qui count
	local num_obs = `r(N)'
	
	* string/numlist error checking
	if "`varlist'"=="" {
		numlist `"`values'"', integer
		foreach opt in before after {
			if `"``opt''"'!="" {
				confirm integer number ``opt''
				if !inrange(``opt'',1,`num_obs') {
					di as error "invalid number for `opt'()"
					exit 198
				}
			}
		}
	}
		
	****************************
	*** 	Sorting			 ***
	****************************
	
	tempvar row_num index

	* first is the default if no location options specified
	if `"`first'`last'`before'`after'"'=="" local first "first"	

	* If user specified strings then convert them to numlists
	if "`varlist'"!="" {
		qui gen `row_num' = .
		tokenize `"`values'"'

		qui while `"`1'"'!= "" {
			replace `row_num' = .
			
			* Error check the input. Allow non-unique values
			cap confirm string var `varlist'
			if _rc==0 qui count if `varlist' == `"`1'"'
			else qui count if `varlist' == `1'
			if `r(N)' == 0 {
				di as error "`1' is not a valid value for `varlist'"
				exit 198
			}

			* Store the row number(s)
			if _rc==0 replace `row_num' = _n if `varlist'== `"`1'"'
			else replace `row_num' = _n if `varlist'== `1'
			levels `row_num' if !mi(`row_num'), local(val)
			local my_numlist "`my_numlist' `val'"	
			macro shift
		}
		
		* Convert before() or after() to row nums if applicable; enforce uniqueness
		qui foreach opt in before after {
			qui replace `row_num' = .
			if "``opt''"!="" {
				qui count if `varlist'=="``opt''"
				if `r(N)'!=1 {
					di as error `"``opt'' is not a valid value"'
					exit 198
				}
				replace `row_num' = _n if `varlist'==`"``opt''"'
				levels `row_num' if !mi(`row_num'), local(`opt')
			}
		}
	}
	else {
		numlist "`values'", integer
		local my_numlist "`r(numlist)'"
	}

	local num_vars: word count `my_numlist'

	qui gen `index' = .	
	
	* Define first row for sorted variables
	if "`first'"!="" local first_row = 1
	else if "`last'"!="" local first_row = `num_obs' - `num_vars' + 1
	else if "`before'"!="" local first_row = `before' - `num_vars'
	else if "`after'"!="" local first_row = `after'+1

	* Count number of vars being sorted
	local end_row = `first_row' + `num_vars'
	
	* Order the rows
	tokenize "`my_numlist'"
	local counter = 1
	while "`1'"!= "" {
		qui replace `index' = `counter' in `1'
		local counter = `counter'+1
		macro shift
	}
	
	* Order observations before and after the specified the values
	if "`last'"!="" qui replace `index' = 0 if mi(`index')
	else if "`before'"!="" qui replace `index' = 0 if mi(`index') & _n < `before'
	else if "`after'"!="" qui replace `index' = 0 if mi(`index') & _n <= `after' 
	
	qui replace `index' = `counter' if mi(`index')
	
	* Sort values
	sort `index', stable
end
** EOF
