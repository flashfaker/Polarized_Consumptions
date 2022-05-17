* clean food&beverage product label + country of origin data from Label Insights
local fname clean_02_labelinsights_coo_data

/*******************************************************************************

* clean and append Label Insights Food&Beverage Data (Newly downloaded from 20220331)
* note that the only difference between this one and the original clean_labelinsights_coo_data
* is that this one uses the newer data with all the upc fields for matching

Author: Zirui Song
Date Created: Mar 31st, 2022
Date Modified: Apr 1st, 2022

********************************************************************************/

/**************
	Basic Set-up
	***************/
	clear all
	set more off, permanently
	capture log close
	
	* Set local directory
	* notice that repodir path for Mac/Windows might differ
	global dropbox = "/Users/zsong/Dropbox/Polarized Consumptions"
	global datadir = "$dropbox/Data"
	global rawdir = "$datadir/Label Insights/20220331"
	global outdir = "$datadir/Cleaned Data"
	global intdir = "$datadir/Cleaned Data/Intermediate"
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
		tostring productid onpackgtinformats upc* ean* gtin, replace format("%15.0f")
		local file: subinstr local file ".csv" ""
		save "$intdir/Label Insights/20220331/`file'", replace
	}
	
	* append files
	
	* See https://www.statalist.org/forums/forum/general-stata-discussion/general/1530135-append-all-dta-files-in-directory
	cd "$intdir/Label Insights/20220331"
	local File : dir . files "*.dta"
	clear 
	append using `File' 
	
*** to get rid of weird productids/empty upc products
		drop if upc == ""
		drop if upc == "."
		*charlist productid
		*charlist upc
		* drop duplicates in terms of productid
		duplicates drop productid, force	
	destring productid, replace
	
	save "$intdir/labelinsights_product_coo_base.dta", replace

/**************
	Clean Data to get coo string
	***************/	
	use "$intdir/labelinsights_product_coo_base.dta", clear
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
	
	save "$intdir/labelinsights_temp1", replace
*** get rid of string duplicates (country names)
	use "$intdir/labelinsights_temp1", clear
	
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
	merge 1:1 productid using "$intdir/labelinsights_temp1", keepusing(upc* partial)
	keep if _merge == 3
	drop _merge
	split coo
	
	lab var coo "Country of Origin"
	lab var partial "Partial Ingredient"
	save "$intdir/labelinsights_product_coo_cleaned", replace
	
/**************
	Obtain Country Dummies and Finalize Data
	***************/	
	use "$intdir/labelinsights_product_coo_base.dta", clear
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
	* destring countryoforigin variables and generate partial
	gen partial_m = 0
	foreach var of varlist countryof* v* {
		replace partial = 1 if strpos(`var', "Partial") != 0
		replace `var' = "1" if `var' != ""
		replace `var' = "0" if `var' == ""
		destring `var', replace
	}
	
	*ssc install labutil2
	lab2varn countryof*
	
	foreach var of varlist v* {
		local label: variable label `var'
		local v "`label'_`var'"
		rename `var' `v'
	}
	
	order _all, alpha
	foreach x in Albania Aruba Bahamas Barbados Belgium Belize ///
				 BritishVirginIslands Canada CaymanIslands Colombia Cuba ///
				 DominicanRepublic Dominica ElSalvador Greenland Guyana ///
				 Lithuania Montenegro NorthernMarianaIsland Norway ///
				 PapuaNewGuinea Peru Pitcairn Portugal Slovenia Switzerland ///
				 Tokelau Tonga Tuvalu {
		egen `x' = rowmax(`x'*)
		local i "`x'_v"
		drop `i'* 	
	}
	* clean other variables ended with _v...
	rename *_v* *
	
	merge 1:1 productid using "$intdir/labelinsights_product_coo_cleaned", keepusing(coo partial)
	keep if _merge == 3
	drop _merge
	* simple sanity checks
	isid productid
	assert partial == partial_m
	merge 1:1 productid using "$intdir/labelinsights_product_coo_base", keepusing(upc*)
	keep if _merge == 3
	drop _merge
	
	drop partial_m
	rename brandidentifyingheaderinformatio brand
	rename categoryproductcategorization category
	rename productsizeidentifyingheaderinfo size
	rename producttitleidentifyingheaderinf title
	order _all, alpha
	sort productid
	keep productid title brand category size upc-upcstandardfields coo partial datecreatedtimestamps Afghanistan-Zimbabwe
	
*** generate date for upc creation
	gen date = substr(datecreatedtimestamps, 1, 10)
	gen upc_date = date(date, "YMD")
	format upc_date %td
	order productid title brand category size upc-upcstandardfields coo partial date upc_date datecreatedtimestamps
	
	save "$outdir/labelinsights_product_cleaned", replace
********************************* END ******************************************

capture log close
exit
