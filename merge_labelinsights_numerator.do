* merge Label Insights COO data set with Numerator Data using UPC
local fname merge_labelinsights_numerator

/*******************************************************************************

* Merge Label Insights Food+Beverage Product Data with Numerator Item Data

Author: Zirui Song
Date Created: Apr 11th, 2022
Date Modified: Apr 12th, 2022

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
	global outdir = "$datadir/Cleaned Data"
	global intdir = "$datadir/Cleaned Data/Intermediate"
	global logdir = "$dropbox/Code/ZS/LogFiles"
	
	* Start plain text log file with same name
	log using "$logdir/`fname'.txt", replace text
	
/**************
	Clean Numerator Item Data
	***************/	
	* separately import 2017 and 2019 item data due to the size of those two data sets
	import delimited "$datadir/Numerator/New_File_Formats_2017-2021/2017/standard_nmr_feed_item_table.csv", delimiter("|") bindquotes(nobind) clear
	drop v*
	save "$intdir/numerator_item_2017_cleaned", replace
	import delimited "$datadir/Numerator/New_File_Formats_2017-2021/2018/standard_nmr_feed_item_table.csv", delimiter("|") bindquotes(nobind) clear
	drop v*
	save "$intdir/numerator_item_2018_cleaned", replace
	import delimited "$datadir/Numerator/New_File_Formats_2017-2021/2019/standard_nmr_feed_item_table.csv", delimiter("|") bindquotes(nobind) clear
	drop v*
	save "$intdir/numerator_item_2019_cleaned", replace
	import delimited "$datadir/Numerator/New_File_Formats_2017-2021/2020/standard_nmr_feed_item_table.csv", delimiter("|") bindquotes(nobind) clear
	drop v*
	save "$intdir/numerator_item_2020_cleaned", replace
	import delimited "$datadir/Numerator/New_File_Formats_2017-2021/2021/standard_nmr_feed_item_table.csv", delimiter("|") bindquotes(nobind) clear
	drop v*
	save "$intdir/numerator_item_2021_cleaned", replace

/**************
	Merge with Label Insights data via UPC 
	***************/	
	
// This section borrows code from JG/merge_Nielsen_Label.
// 										Initial Note: 
// The UPC codes (UPC) in the Numerator data do not include the check digits. 
// Label Insights offers three types of codes, UPC code without check digit, UPC-A code with check digit, and UPC-E

foreach year in 2017 2018 2019 2020 2021 {
	
use "$intdir/numerator_item_`year'_cleaned", clear
////// Step 1 -- > Merge UPCs in the numerator item data with the UPC code without check digit in the Label Insights database
// Step 1.1 -- > Tranforming UPCs in the numerator data to string format
keep if upc != .
format upc %17.0g
tostring upc, gen(upc12nocheckdigitgtinformats) usedisplayformat

// Step 1.2 --> Merging based on UPC code without check digit
merge 1:m upc12nocheckdigitgtinformats using "$outdir/labelinsights_product_cleaned.dta", force

// Step 1.3 --> Saving file
preserve
keep if _merge==3
gduplicates drop upc12nocheckdigitgtinformats, force
save  "$intdir/numerator_merge1_`year'.dta",replace 
restore

//////  Step 2 --> Merge the unmatched in Step 1. based on UPC code without check digit from Numerator and UPC-A with check digit from Label Insights

keep if _merge==1
keep item_id-item_description

// Step 2.1.1 --> UPCs with 11 digits in the Numerator Data
gen length = length(upc12nocheckdigitgtinformats)

// Step 2.1.2 -- > Creating the check digit according to formula in the Label Insight manual
preserve
keep if length==11
foreach num of numlist 1/11{
	gen c`num' = substr(upc12nocheckdigitgtinformats,`num',1)
	destring c`num', replace force
}

gen nbr = (c11+c9+c7+c5+c3 +c1)*3 + (c2+c4+c6+c8+c10)
gen mod = mod(nbr,10)
gen checkdigit = 10-mod
replace checkdigit=0 if checkdigit==10
tostring checkdigit, replace force

gen upcagtinformats = upc12nocheckdigitgtinformats + checkdigit
drop c1-checkdigit

// Step 2.1.3 -- > Merge the UPC with check digit in the Consumer Panel to UPC-A in the Label Insight
merge 1:m upcagtinformats using "$outdir/labelinsights_product_cleaned.dta", force

keep if _merge==3
drop _merge
gduplicates drop upcagtinformats, force
save  "$intdir/numerator_merge2_`year'.dta", replace
restore

// Step 2.2.1 -- > UPCs with 10 digits in the Numerator Data
preserve
keep if length==10

// Step 2.2.2 -- > Creating the check digit according to formula in the Label Insight manual
foreach num of numlist 1/10{
	gen c`num' = substr(upc12nocheckdigitgtinformats,`num',1)
	destring c`num', replace force
}

gen nbr = (c10+c8+c6+c4+c2)*3 + (c1+c3+c5+c7+c9)
gen mod = mod(nbr,10)
gen checkdigit = 10-mod
replace checkdigit=0 if checkdigit==10
tostring checkdigit, replace force

gen upcagtinformats = upc12nocheckdigitgtinformats + checkdigit
drop c1-checkdigit

// Step 2.3.3 -- > Merge the UPC with check digit in the Consumer Panel to UPC-A in the Label Insight
merge 1:m  upcagtinformats using "$outdir/labelinsights_product_cleaned.dta", force
keep if _merge==3
drop _merge

gduplicates drop upcagtinformats, force
save  "$intdir/numerator_merge3_`year'.dta", replace
restore

/// 
// Step 2.3.1 -- > UPCs with 12 digits in the Numerator Data
keep if length==12
gen upcagtinformats = upc12nocheckdigitgtinformats
merge 1:m upcagtinformats using "$outdir/labelinsights_product_cleaned.dta", force
keep if _merge ==3
drop _merge
gduplicates drop upcagtinformats, force
save "$intdir/numerator_merge4_`year'.dta", replace


/// Step 3) Create List of Label Insights products that went unmatched in Step 2. and remove leading zeros from the UPC 12 digit with no checkdigit
use "$intdir/numerator_merge1_`year'.dta", clear
append using "$intdir/numerator_merge2_`year'.dta"
append using "$intdir/numerator_merge3_`year'.dta"
append using "$intdir/numerator_merge4_`year'.dta"

drop _merge 
gduplicates drop productid, force

merge 1:1 productid using "$outdir/labelinsights_product_cleaned.dta", force
keep if _merge==2
drop _merge
drop upc item_id rin-item_description

// Step 3.1) Destring the UPC 12 in Label Insights to remove leading zeros and merge to UPC numerical variable in the Numerator Item Data
destring upc12nocheckdigitgtinformats, gen(upc) force
drop if upc==.
gduplicates drop upc, force

// Step 3.2) Merging with consumer Panels
merge 1:m upc using "$intdir/numerator_item_`year'_cleaned", force
keep if _merge==3
drop _merge
save "$intdir/numerator_merge5_`year'.dta", replace

///////// Step 4) Appending all datasets
use "$intdir/numerator_merge1_`year'.dta", clear
append using "$intdir/numerator_merge2_`year'.dta"
append using "$intdir/numerator_merge3_`year'.dta"
append using "$intdir/numerator_merge4_`year'.dta"
append using "$intdir/numerator_merge5_`year'.dta"

drop _merge 
gduplicates drop productid, force
gduplicates drop upc, force

keep upc productid
save  "$intdir/matchkey_NM_LI_`year'.dta", replace	
}
	
/**************
	Clean Numerator Item Data to Make Space
	***************/		
	forv year = 2017(1)2021 {
		use "$intdir/numerator_item_`year'_cleaned.dta"
		* keep only id variables for matching
		keep *_id
		save "$intdir/numerator_item_`year'_cleaned.dta", replace
	}

/**************
	Append NM_LI_Key data from 2017-2021 
	***************/
	
********************************* END ******************************************

capture log close
exit
