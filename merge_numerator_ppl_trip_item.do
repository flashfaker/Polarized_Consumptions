* merge data from household_id to trip and purchase data 
local fname merge_numerator_ppl_trip_item

/*******************************************************************************

* Merge Household ID first to trip data and then to purchase data from each trip 
to obtain the the fraction of items that the household purchases

Author: Zirui Song
Date Created: May 5th, 2022
Date Modified: May 9th, 2022

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
	Clean Trip Data (contain trip_id and household_id)
	***************/		
cd "$numdir"
* ssc install filelist // filelist due to Robert Picard
* obtain all trips csv.

forv yr = 2017/2021 {
	filelist, dir("`yr'") pat("*trips*.csv") save("trips_datasets_`yr'.dta") replace
	* merge csvs. into one
	use "trips_datasets_`yr'.dta", clear
    local obs = _N
    forvalues i=1/`obs' {
		use "trips_datasets_`yr'.dta" in `i', clear
		local f = dirname + "/" + filename
		import delimited using "`f'", clear
		gen source = "`f'"
		tempfile save`i'
		save "`save`i''"
		* delete the original csv. files to make space		
		* this step erases the csv. files used in the cleaning step (to re-do--)
		* to re-do this whole importing step, one has to download data from
		* Mercury share again.
		erase "`f'"
    }
	* append files together
    use "`save1'", clear
    forvalues i=2/`obs' {
		append using "`save`i''"
    }
	* keep only id variables, dates of the trip and trip total
	keep *_id trip_total transaction_date
	gen trip_date = date(transaction_date, "YMD")
	format trip_date %td
	drop transaction_date
	compress
	save "$intdir/numerator_trip_cleaned_`yr'", replace
}

*** append the trips data together 
	use "$intdir/numerator_trip_cleaned_2017", clear
	forv yr = 2018/2021 {
		append using "$intdir/numerator_trip_cleaned_`yr'"
		save "$outdir/numerator_trip_cleaned_2017to2021", replace
	}
	compress
	save "$outdir/numerator_trip_cleaned_2017to2021", replace 
	* erase the annual intermediate trip data to save space
	forv yr = 2017/2021 {
		erase "$intdir/numerator_trip_cleaned_`yr'.dta"
	}
	
/**************
	Clean Purchase Data (contain trip_id and item_id)
	***************/	
	cd "$numdir"
forv yr = 2017/2021 {
	filelist, dir("`yr'") pat("*purchase*.csv") save("purchase_datasets_`yr'.dta") replace
	* merge csvs. into one
	use "purchase_datasets_`yr'.dta", clear
    local obs = _N
    forvalues i=1/`obs' {
		use "purchase_datasets_`yr'.dta" in `i', clear
		local f = dirname + "/" + filename
		import delimited using "`f'", clear
		* keep only trip_id item_id and total (due to size of the data sets)
		keep *_id item_total
		tempfile save`i'
		save "`save`i''"
		* delete the original csv. files to make space		
		* this step erases the csv. files used in the cleaning step (to re-do--)
		* to re-do this whole importing step, one has to download data from
		* Mercury share again.
		erase "`f'"
    }
	* append files together
    use "`save1'", clear
    forvalues i=2/`obs' {
		append using "`save`i''"
    }
	compress
	save "$intdir/numerator_purchase_cleaned_`yr'", replace
}
*** append the trips data together 
	use "$intdir/numerator_purchase_cleaned_2017", clear
	forv yr = 2018/2021 {
		append using "$intdir/numerator_purchase_cleaned_`yr'"
		save "$outdir/numerator_purchase_cleaned_2017to2021", replace
	}
	save "$outdir/numerator_purchase_cleaned_2017to2021", replace 
	* erase the annual intermediate trip data to save space
	forv yr = 2017/2021 {
		erase "$intdir/numerator_purchase_cleaned_`yr'.dta"
	}

	
/**************
	Merge Household ID with trip data to get the trip-id for each household
	***************/	
*** read in household_id data with trump rally distances computed and merge with 
	use "$outdir/numerator_person_dist_to_trumprally_2017to2021_reshaped", clear
	
********************************* END ******************************************

capture log close
exit
