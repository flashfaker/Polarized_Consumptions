* check whether there is systematic difference between the products matched to 
* Numerator compared to the baseline 450,000 products
local fname check_labelinsights_numerator_merge

/*******************************************************************************

since there are only 70,000 products matched to the Numerator data, do a sanity
check on how good/reasonable the matchi is compared to the original data  

Author: Zirui Song
Date Created: May 17th, 2022
Date Modified: May 17th, 2022

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
	Import and Save all Data
	***************/	
	
	use "$outdir/coo_cleaned.dta", clear
	sum partial-US
	* merge with Numerator-LI key 
	merge 1:m productid using "$intdir/matchkey_NM_LI_2017to2021"
		keep if _merge == 3
		drop _merge 
	duplicates drop productid, force
	sum partial-US
********************************* END ******************************************

capture log close
exit
