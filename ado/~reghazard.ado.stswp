*! version 1.0.0 09May2025
cap program drop reghazard
program define reghazard, eclass
    version 17.0
    syntax varlist(min=1) [,KEEPmax KEEPmin]

	
//     tokenize `varlist'
//     local yvar "`1'"
//     macro shift
//    local covars "`*'"
	local covars `varlist'

    // ensure required variables exist
    foreach v in bin fweight remain hazard {
        capture confirm variable `v'
        if _rc {
            display as error "`v' not found; run bin_hazard first"
            exit 198
        }
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


		// check for duplicate cells by bin and covariates
		if "`covars'" != "" {
			tempvar dup
			by `covars' bin, sort: gen byte `dup' = _N > 1
			count if `dup'
			if r(N) {
				display as error "duplicate cells detected for bin and covariates"
				exit 198
			}
			drop `dup'
		}
		} //qui
		// build model restriction
		qui su, meanonly
		local bmin `r(min)'
		local bmax `r(max)'
	   
		local restrict ""
		if "`keepmin'" == "" local restrict "`restrict' & bin!=`bmin'"
		if "`keepmax'" == "" local restrict "`restrict' & bin!=`bmax'"
		// clean up leading &
		if substr("`restrict'",1,3)==" &" local restrict = substr("`restrict'",4,. )
		if "`restrict'" != "" local restrict = " if `restrict'"
		
		di "`restrict'"
		
    // choose and run model
//     quietly count if hazard==0`restrict'
    if r(N)>0 {
        display "Zeros in hazard ⇒ using cloglog-GLM"
        glm fweight i.bin, family(binomial remain) link(cloglog)
    }
    else {
        display "No zeros ⇒ OLS on cloglog(hazard)"
        gen double cloglog_hazard = log(-log(1-hazard))
        regress cloglog_hazard i.bin, r
        drop cloglog_hazard
    }
end
