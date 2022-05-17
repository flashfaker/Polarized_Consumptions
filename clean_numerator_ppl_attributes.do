* import and clean people attributes data from numerator
local fname clean_numerator_ppl_attributes

/*******************************************************************************

* obtain the household that watches fox, fox news, fox sports from the Numerator
People Attributes data set from 2017 to 2021 

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
	global numdir = "$dropbox/Data/Numerator/New_File_Formats_2017-2021"

	global outdir = "$dropbox/Data/Cleaned Data"
	global intdir = "$dropbox/Data/Cleaned Data/Intermediate"
	global logdir = "$dropbox/Code/ZS/LogFiles"
	
	* Start plain text log file with same name
	log using "$logdir/`fname'.txt", replace text
	
/**************
	Import and Clean Ppl Attributes Data from Numerator
	***************/		
	* import and clean the data (2017 to 2021)
	forv yr = 2017/2021 {
		import delimited "$numdir\`yr'\standard_nmr_feed_people_attributes_table_resend.csv", clear 
		* generate dummy for fox channel viewership (fox sports included?)
		replace tag_description = lower(tag_description)
		gen fox = 1 if strpos(tag_description, fox) != 0 
		keep if fox == 1
		* keep only non-duplicates household_ids 
		duplicates drop household_id, force
		keep household_id 
		gen year = `yr'
		tempfile attributes`yr'
		save "attributes`yr'"
	}
	* append the files together
	use "attributes2017", clear
	forvalues i = 2018/2021 {
		append using "`attributes`i''"
    }
	save "$outdir/numerator_ppl_attributes_2017to2021", clear
********************************* END ******************************************

capture log close
exit
