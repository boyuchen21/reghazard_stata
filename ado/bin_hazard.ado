*! version 1.0.2 06May2025
cap program drop bin_hazard
program define bin_hazard
    // 1) Parse input: first var is outcome (y), rest are covariates
    syntax varlist(min=1) , [lower(real 5) upper(real 25) width(real 0.25)]
  
		// split varlist into yvar and covars
		local nvars : word count `varlist'
		tokenize `varlist'
		local yvar "`1'"
		macro shift
		local covars "`*'"

		capture confirm numeric variable `yvar'
		if _rc {
			display as error "`yvar' must be numeric"
			exit 198
		}

		// sanity check: no missing categories in covariates
		if "`covars'" != "" {
			foreach v of local covars {
				capture confirm string variable `v'
				if !_rc {
					qui drop if `v' == ""
					di "drop `v' with empty string"
				} 
				else {
					qui drop if `v' == .
					di "drop `v' with missing values"
				}
			}
		}
		qui{

		 // ensure (upper-lower) is divisible by width
		local ratio = `=(`upper' - `lower') / `width''
		local iratio = floor(`ratio')
		if `ratio' != `iratio' {
			display as error "upper–lower must be an integer multiple of width"
			exit 198
		}
		
		// 2) Build breakpoints list
		local brks 0
		local b = `lower'
		while (`b' < `upper') {
			local brks "`brks' `b'"
			local b = `b' + `width'
		}
		local brks "`brks' `upper'"

		// 3) Cut into integer bins
		egen byte bin = cut(`yvar'), at(`brks') icodes
		
		quietly summarize bin, meanonly
		local maxbin = r(max) + 1
		replace bin = `maxbin' if `yvar' > `upper'

		// 4) Contract frequencies
		if `nvars' > 1 {
			contract `covars' bin, freq(_freq)
			sort `covars' bin
		}
		else {
			contract bin, freq(_freq)
			sort bin
		}
		
		tempfile empty_bins
		preserve
			clear
			set obs `=`maxbin' + 1'
			gen byte bin = _n - 1
			save `empty_bins', replace
		restore
		// if no covariate, then simply merging all bins. any using only is because it's not in main.
		// if has covariate, then we append all bins then use fillin to get all interactions of covariates and bins.
		if `nvars' > 1{
			append using `empty_bins'
			fillin `covars' bin
			// drop missing covariates
			foreach v of local covars {
				capture confirm string variable `v'
				if !_rc {
					drop if `v' == ""
				}
				else {
					drop if missing(`v')
				}
			}
			drop _fillin
		} 
		else {
			merge 1:1 bin using `empty_bins', keepusing(bin) nogen 
		}
		
		replace _freq = 0 if missing(_freq)
		local expected = (`maxbin'+1)
		if `nvars' > 1 {
			foreach var of local covars {
				levelsof `var'
				local expected = `expected' * `r(r)'
			}
		}
		count
		if r(N) != `expected' {
			display as error "cell count mismatch: found " `r(N)' ", expected `expected'"
			exit 198
		}
		} //quietly
		// 7) Compute fweight, remain, hazard
		if `nvars' > 1 {
			di "construct binned data with covariates"
			by `covars': egen total = total(_freq)
			gen double fweight = _freq/total
			gsort `covars' -bin
			by `covars': gen double remain = sum(fweight)
			gen double hazard = fweight/remain
			gsort `covars' bin
			di "data binned by `covars', from `lower' to `upper' with bin width `width'. "
		}
		else {
			di "construct binned data without covariates"
			egen total = total(_freq)
			gen double fweight = _freq/total
			gsort -bin
			gen double remain = sum(fweight)
			gen double hazard = fweight/remain
			sort bin
			di "data binned without covariates, from `lower' to `upper' with bin width `width'. "

		}

		qui{
			// sanity checks for myself: fweight, remain, hazard ∈ [0,1]
			local tol = 1e-5
			count if fweight < -`tol' | fweight > 1+`tol'
			if r(N) > 0 {
				display as error "fweight out of [0,1]"
				exit 198
			}
			count if remain < -`tol' | remain > 1+`tol'
			if r(N) > 0 {
				display as error "remain out of [0,1]"
				exit 198
			}
			count if hazard < -`tol' | hazard > 1+`tol'
			if r(N) > 0 {
				display as error "hazard out of [0,1]"
				exit 198
			}
		
		// sanity check: remain must decrease with bin
		if "`covars'" != "" {
			generate byte bad_rem = 0
			by `covars' (bin): replace bad_rem = 1 if _n>1 & remain > remain[_n-1]
			count if bad_rem == 1
			if r(N) > 0 {
				display as error "remain not decreasing in some bin for a covariate group"
				exit 198
			}
			drop bad_rem
		} 
		else {
			generate byte bad_rem = 0
			sort bin
			replace bad_rem = 1 if _n>1 & remain > remain[_n-1]
			count if bad_rem == 1
			if r(N) > 0 {
				display as error "remain not decreasing across bins"
				exit 198
			}
			drop bad_rem
		}

		// sanity check: hazard at maxbin must equal 1
		count if bin == `maxbin' & abs(hazard - 1) > .00001
		if r(N) > 0 {
			display as error "hazard at maxbin not equal to 1"
			exit 198
		}
		}
		
		//create label
// 		label define binlbl 0 "[0, `lower')"
// 		local maxbin_minus_1 = `maxbin'-1
//
// 		forvalues i = 1/`maxbin_minus_1' {
// 			local lo : display %9.2f `lower' + (`i'-1) * `width'
// 			local hi : display %9.2f `lo' + `width'
//  			label define binlbl `i' "[`lo', `hi')", add
// 		}
// 		label define binlbl `maxbin' "[`upper', Inf)", add
//
// 		label values bin binlbl
		
		count 
		di "`r(N)' cells are created"
		
		drop total _freq
		qui compress
	
end
