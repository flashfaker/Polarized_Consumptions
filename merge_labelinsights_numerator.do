* merge Label Insights COO data set with Numerator Data using UPC
local fname merge_labelinsights_numerator

/*******************************************************************************

* Merge Label Insights Food+Beverage Product Data with Numerator Item Data

Author: Zirui Song
Date Created: Apr 11th, 2022
Date Modified: Apr 11th, 2022

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
	
	
********************************* END ******************************************

capture log close
exit
