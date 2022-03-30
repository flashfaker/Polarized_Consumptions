* clean food&beverage product label + country of origin data from Label Insights
local fname clean_labelinsights_coo_data

/*******************************************************************************

* clean and append Label Insights Food&Beverage Data 

Author: Zirui Song
Date Created: Mar 27th, 2022
Date Modified: Mar 30th, 2022

********************************************************************************/

/**************
	Basic Set-up
	***************/
	clear all
	set more off, permanently
	capture log close
	
	* Set local directory
	* notice that repodir path for Mac/Windows might differ
	global dropbox = "/Users/zsong98/Dropbox/Polarized Consumptions"
	global datadir = "$dropbox/Data"
	global rawdir = "$datadir/Label Insights"
	global outdir = "$datadir/Cleaned Data"
	global logdir = "$dropbox/Code/ZS/LogFiles"
	
	* Start plain text log file with same name
	log using "$logdir/`fname'.txt", replace text
	
/**************
	Import and Save all Data
	***************/	
	local files: dir "$rawdir" files "*.csv"
	foreach file in `files' {
		import delimited using "$rawdir/`file'", clear varnames(1)
		rename *productid productid 
		* generate country of origin string
		foreach x of varlist countryoforigin* v* {
			replace `x' = subinstr(`x', "Not Applicable", "", .)
		}
		gen countryoforigin = ""
		foreach x of varlist countryoforigin* v* {
			replace countryoforigin = countryoforigin + " " + `x'
		}
		tostring productid upc*, replace format("%15.0f")
		save "$rawdir/`file'.dta", replace
	}
	
	* append files
	
	* See https://www.statalist.org/forums/forum/general-stata-discussion/general/1530135-append-all-dta-files-in-directory
	local files : dir "$rawdir" files "*.dta"
	clear
	append using `files'
	
	* drop duplicates in terms of productid
	duplicates drop productid, force	
*** to get rid of weird productids/empty upc products
	drop if upc == ""
	drop if upc == "."
	*charlist productid
	*charlist upc
	destring productid, replace
	
	save "$outdir/labelinsights_product_coo_base.dta", replace

/**************
	Clean Data to get coo string
	***************/	
	use "$outdir/labelinsights_product_coo_base.dta", clear
	keep productid-categoryproductcategorization countryoforigin

*** Generate "Partial Indicator" (and drop "Paritial Indicator")
	gen partial = 1 if strpos(countryoforigin, "Partial Ingredients") != 0
	replace partial = 0 if partial == .
	replace countryoforigin = subinstr(countryoforigin, "Partial Ingredients", "", .)
	
*** Split Strings into Countries
	replace countryoforigin = subinstr(countryoforigin, "United States", "UnitedStates", .)
	replace countryoforigin = subinstr(countryoforigin, "United Kingdom", "UnitedKingdom", .)
	replace countryoforigin = subinstr(countryoforigin, "New Zealand", "NewZealand", .)
	replace countryoforigin = subinstr(countryoforigin, "Central African Republic", "CentralAfricanRepublic", .)
	replace countryoforigin = subinstr(countryoforigin, "Antigua and Barbuda", "AntiguaandBarbuda", .)
	replace countryoforigin = subinstr(countryoforigin, "Bosnia and Herzegovina", "BosniaandHerzegovina", .)
	replace countryoforigin = subinstr(countryoforigin, "Czech Republic", "CzechRepublic", .)
	replace countryoforigin = subinstr(countryoforigin, "Democratic Republic of the Congo", "DemocraticRepublicoftheCongo", .)
	replace countryoforigin = subinstr(countryoforigin, "Dominican Republic", "	DominicanRepublic", .)
	replace countryoforigin = subinstr(countryoforigin, "North Korea", "NorthKorea", .)
	replace countryoforigin = subinstr(countryoforigin, "North Macedonia", "NorthMacedonia", .)				
	replace countryoforigin = subinstr(countryoforigin, "Palestine State", "Palestine", .)					
	replace countryoforigin = subinstr(countryoforigin, "Papua New Guinea", "PapuaNewGuinea", .)				
	replace countryoforigin = subinstr(countryoforigin, "Saudi Arabia", "SaudiArabia", .)				
	replace countryoforigin = subinstr(countryoforigin, "South Africa", "SouthAfrica", .)				
	replace countryoforigin = subinstr(countryoforigin, "South Korea", "SouthKorea", .)
	replace countryoforigin = subinstr(countryoforigin, "South Sudan", "SouthSudan", .)
	replace countryoforigin = subinstr(countryoforigin, "Sri Lanka", "SriLanka", .)
	replace countryoforigin = subinstr(countryoforigin, "Trinidad and Tobago", "TrinidadandTobago", .)
	replace countryoforigin = subinstr(countryoforigin, "United Arab Emirates", "UnitedArabEmirates", .)
	replace countryoforigin = subinstr(countryoforigin, "Republic of Korea", "SouthKorea", .)
	replace countryoforigin = subinstr(countryoforigin, "Costa Rica", "CostaRica", .)
	replace countryoforigin = subinstr(countryoforigin, "United Arab Emirates", "UnitedArabEmirates", .)
	replace countryoforigin = subinstr(countryoforigin, "Republic of Moldova", "RepublicofMoldova", .)
	
	save "$outdir/labelinsights_temp1", replace
*** get rid of string duplicates (country names)
	use "$outdir/labelinsights_temp1", clear
	
	replace countryoforigin = stritrim(countryoforigin)
	replace countryoforigin = strtrim(countryoforigin)
	split countryoforigin
	
	keep productid countryoforigin*  
	drop countryoforigin
	reshape long countryoforigin, i(productid) j(which)

	bysort productid countryoforigin (which) : keep if _n == 1 
	bysort productid (which) : replace which = _n 
	reshape wide countryoforigin, i(productid) j(which)

	egen coo = concat(countryoforigin*), p(" ") 
	
	keep productid coo
	merge 1:1 productid using "$outdir/labelinsights_temp1", keepusing(upc* partial)
	keep if _merge == 3
	drop _merge
	split coo
	
	lab var coo "Country of Origin"
	lab var partial "Partial Ingredient"
	save "$outdir/labelinsights_product_coo_cleaned", replace
	
/**************
	Obtain Country Dummies and Finalize Data
	***************/	
	use "$outdir/labelinsights_product_coo_base.dta", clear
*** change label to be country names solely
	drop countryoforigin
	foreach var of varlist countryof* v* {
		local variable_label: variable label `var'
		local variable_label: subinstr local variable_label "Country Of Origin (On-Package) " ""
		local variable_label: subinstr local variable_label "- Africa - " ""
		local variable_label: subinstr local variable_label "- Asia - " ""
		local variable_label: subinstr local variable_label "- Europe - " ""
		local variable_label: subinstr local variable_label "- Oceanic - " ""
		local variable_label: subinstr local variable_label "- North America - " ""
		local variable_label: subinstr local variable_label "- South America - " ""
		local variable_label: subinstr local variable_label "- Antarctica - " ""
		local variable_label: subinstr local variable_label "- Antarctica - " ""
		local variable_label: subinstr local variable_label "&" "" 
		* get rid of blanks in country names in case there are more than 1 blanks
		* u.e., Republic of Korea
		local variable_label: subinstr local variable_label " " "" 
		local variable_label: subinstr local variable_label " " "" 
		local variable_label: subinstr local variable_label " " "" 
		local variable_label: subinstr local variable_label " " "" 
		local variable_label: subinstr local variable_label " " "" 
		local variable_label: subinstr local variable_label " " "" 
		label variable `var' "`variable_label'"
	}	

	ssc install labutil2
	lab2varn countryof*
	
	foreach var of varlist v* {
		local label: variable label `var'
		local v "`label'`var'"
		rename `var' `v'
	}
	* generate partial (later)
	
	/* manually check for duplicates variable name (due to importing variable names
	issue with csv. and then merge them together */
	foreach var of varlist _all {
		replace `var' = "1" if `var' != ""
		replace `var' = "0" if `var' == ""
		destring `var', replace
	}
	
	order _all, alpha
	foreach x in Albania Aruba Bahamas Barbados Belgium Belize ///
				 BritishVirginIslands Canada CaymanIslands Colombia Cuba ///
				 DominicanRepublic Dominica ElSalvador Greenland Guyana ///
				 Lithuania Montenegro NorthernMarianaIsland Norway ///
				 PapuaNewGuinea Peru Pitcairn Portugal Slovenia Switzerland ///
				 Tokelau Tonga Tuvalu {
		egen `x' = rowmax(`x'*)
		/* drop original duplicated obs
		local i "`x'v"
		drop `i' */
	}
	foreach x in Albania Aruba Bahamas Barbados Belgium Belize ///
				 BritishVirginIslands Canada CaymanIslands Colombia Cuba ///
				 DominicanRepublic Dominica ElSalvador Greenland Guyana ///
				 Lithuania Montenegro NorthernMarianaIsland Norway ///
				 PapuaNewGuinea Peru Pitcairn Portugal Slovenia Switzerland ///
				 Tokelau Tonga Tuvalu {
		local i "`x'v"
		drop `i'* 	
	}
	
	merge 1:1 productid using "$outdir/labelinsights_product_coo_cleaned", keepusing(coo)
	
	/* albania
	drop v107 
	* belgium
	drop v111
	* lithuania
	drop v137 
	* montenegro
	drop v141
	* norway
	drop v144
	* portugal
	replace v160 = v160 + v146
	drop v146
	* slovenia
	drop v153
	
	renvarlab v*, presub label */
********************************* END ******************************************

capture log close
exit
