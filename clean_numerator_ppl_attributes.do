* import and clean people attributes data from numerator
local fname clean_numerator_ppl_attributes

/*******************************************************************************

* obtain the household that watches fox, fox news, fox sports from the Numerator
People Attributes data set from 2017 to 2021 

Author: Zirui Song
Date Created: May 17th, 2022
Date Modified: May 20th, 2022

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
	* import and clean the data (2017 to 2021) (Fox News)
	forv yr = 2017/2021 {
		if `yr' != 2021 {
			import delimited "$numdir/`yr'/standard_nmr_feed_people_attributes_table_resend.csv", clear 
		} 
		else {
			import delimited "$numdir/`yr'/standard_nmr_feed_people_attributes_table.csv", clear 	
		}
		* generate dummy for fox channel viewership (fox sports included?)
		replace tag_description = lower(tag_description)
		gen fox = 1 if strpos(tag_description, "fox") != 0 
		replace fox = 0 if strpos(tag_description, "fox sport") != 0
		keep if fox == 1
		* keep only non-duplicates household_ids 
		* gduplicates drop household_id, force
		keep household_id fox tag_date
		gen year = `yr'
		tempfile attributes`yr'
		save "`attributes`yr''", replace
	}
	* append the files together
	use "`attributes2017'", clear
	forvalues yr = 2018/2021 {
		append using "`attributes`yr''"
    }
	* clean data -- 
	gduplicates drop household_id tag_date fox, force // note that 2017-2021 files might contain the same information about tags
	gduplicates drop household_id fox, force
	keep household_id fox
	
	save "$outdir/numerator_ppl_foxnews_2017to2021", replace
	
	* import and clean data (education and income buckets)
	forv yr = 2017/2021 {
		import delimited "$numdir/2017/standard_nmr_feed_people_table.csv", clear 
		* keep only education and income variables
		keep household_id education_group income_bucket
		* encode education and income
		encode education_group, gen(education)
		encode income_bucket, gen(income)
		gen year = `yr'
		tempfile educ_income`yr'
		save "`educ_income`yr''", replace
	}
	* append the files together
	use "`educ_income2017'", clear
	forvalues yr = 2018/2021 {
		append using "`educ_income`yr''"
    }
	* note that the annual data from Numerator just records the HH education+income 
	* five times, but they are the same (check this below)
	gduplicates tag household_id-income, gen(dup)
	sum dup 
	drop year dup education_group income_bucket
	duplicates drop 
	* merge the fox news watching data with education/income data (all on hh_id level)
	fmerge 1:1 household_id using "$outdir/numerator_ppl_foxnews_2017to2021"
		* keep all merges 
		* _merge == 1: household has education and income characteristics but 
		* not watch fox
		* _merge == 2: watch fox but has missing education and income characteristics
		* _merge == 3: watch fox and has records income and education characteristics
		drop _merge
		gsort household_id
	save "$outdir/numerator_ppl_attributes_2017to2021", replace 
********************************* END ******************************************

capture log close
exit
