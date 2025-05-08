*! version 1.0.0 07May2025
program define simdata
	clear
	set seed 12345
	set obs 10000

	* continuous "wage"  with mean=15, sd=5
	gen double y = rnormal(15,5)
	drop if y <= 0

	* 3-level string covariate
	gen byte _grp = ceil(runiform()*3)
	gen byte grp2 = ceil(runiform()*5)

	label define grp 1 "A" 2 "B" 3 "C"
	label values _grp grp
	tostring _grp, gen(grp)  // now grp is string
	drop _grp

end

