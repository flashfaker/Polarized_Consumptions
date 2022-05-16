* merge data from household_id to trip and purchase data 
local fname merge_numerator_ppl_trip_item

/*******************************************************************************

* Merge Household ID first to trip data and then to purchase data from each trip 
to obtain the the fraction of items that the household purchases

Author: Zirui Song
Date Created: May 5th, 2022
Date Modified: May 13th, 2022

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

*** merge annual purchase data with NM_LI crosswalk to only keep those items that
*** can be matched to Label Insights
	forv yr = 2017/2021 {
		use "$intdir/numerator_purchase_cleaned_`yr'", clear
		fmerge m:1 item_id using "$intdir/matchkey_NM_LI_`yr'", keepusing(productid)
		keep if _merge == 3
		drop _merge
		save "$intdir/numerator_purchase_cleaned_`yr'_LI_matched", replace
	}

*** append the purchase data (matched with LI) together 
	use "$intdir/numerator_purchase_cleaned_2017_LI_matched", clear
	forv yr = 2018/2021 {
		append using "$intdir/numerator_purchase_cleaned_`yr'_LI_matched"
		save "$outdir/numerator_purchase_cleaned_2017to2021_LI_matched", replace
	}

	
/**************
	Merge Household ID with trip data to get the trip-id for each household
	***************/	
*** merge household trips and purchase data 

	* keep the minimum number of variables from the trip data to merge with purchase data
	* based on trip_id 
	use "$outdir/numerator_trip_cleaned_2017to2021", clear
	keep trip_id household_id trip_total trip_date 
	* check for duplicated trip_ids (error, trip_id should uniquely identify data)
	gen year = year(trip_date)
	gduplicates tag trip_id, gen(dup)
	tab dup 
	tab year if dup == 1
	drop if dup == 1 
	drop year dup 
	gisid trip_id
	* save as temp file for merge
	tempfile trip
	save `trip'
	* merge purchase data with trip data to create household-trip-purchase panel
	use "$outdir/numerator_purchase_cleaned_2017to2021_LI_matched", clear
	fmerge m:1 trip_id using "`trip'"
		* keep both the ones in the using data (keep all trips) and matched results
		drop if _merge == 1
		preserve
			keep if _merge == 3 
			drop _merge
			save "$intdir/numerator_purchase_2017to2021_LI_matched", replace
		restore
		keep if _merge == 2
		drop _merge
		save "$intdir/numerator_purchase_2017to2021_not_LI_matched", replace
		
/**************
	Merge with COO data from Label Insights to compute shares 
	***************/	
	use "$intdir/numerator_purchase_2017to2021_LI_matched", clear
	fmerge m:1 productid using "$outdir/coo_cleaned"
		keep if _merge == 3
		drop _merge
	
	* drop trip_total == 0 (cannot compute shares)
	drop if trip_total == 0
	* change country origin dummy into trip purchase shares (dummy times item total/trip total)
	foreach c in EU other MX CN US {
		replace `c' = `c'*item_total/trip_total
	}
	* collapse down to trip_id level to obtain the total shares of each country/origin 
	* for a given trip that the household goes 
	collapse (first) household_id trip_date trip_total (sum) EU-US, by(trip_id)
	tempfile shares
	save "`shares'"
	
/**************
	Append the trip data set with no matched Label Insights items 
	***************/	
	use "$intdir/numerator_purchase_2017to2021_not_LI_matched", clear
	keep trip_id household_id trip_date trip_total
	append using "`shares'"
	* gsort household_id trip_date
	* fillin missings for the 5 COO regions
	foreach x in EU other MX CN US {
		replace `x' = 0 if `x' >=.
	}
	save "$outdir/numerator_trip_coo_2017to2021_cleaned", replace
	
/**************
	Collapse trip panel down to household-weekly panel 
	***************/
	use "$outdir/numerator_trip_coo_2017to2021_cleaned", replace
	
	* identify the Saturday of trip week (in order to get trip week number)
	gen dow = dow(trip_date)
	gen weekend = trip_date + (6 - dow)

	rename weekend date
	format date %td
	/* generate week variable of which Jan 1st, 2017 is the first date
	gen trip_week = wofd(trip_date) - wofd(td(1jan2017)) */
	
	* collapse down to trip_week-household panel (weighted mean by trip_total)
	collapse (mean) EU-US [aw=trip_total], by(household_id date)
	xtset household_id date
	save "$outdir/numerator_trip_coo_2017to2021_cleaned", replace
	
	* drop households that have zero consumptions in either way 
		egen total_share = rowtotal(EU-US)
		* generate indicator variable (whether or not have positive total_share) by hh
		bysort household_id: egen total_shares = sum(total_share)
		drop if total_shares == 0
		* 19,462,024 obs deleted
		drop total_share*
		
	save "$outdir/numerator_trip_coo_2017to2021_cleaned", replace	
	
/**************
	Import Panel Rally Data (Event Time Cross with Household ID)
	***************/
*** create event-time panel
	clear all
	set obs 21 // The number of observations will define the number of weeks before and after that we will look at
	gen t = .
	foreach num of numlist 1(1)21{
		replace t = `num' - 11 in `num'
	}
	tempfile eventime
	save `eventime'
	
	use "$outdir/numerator_person_dist_to_trumprally_2017to2021_reshaped", clear
	* drop household-rally combination with more than 800km distance
	drop if dist_rally > 800
	* (134,328,349 observations deleted)
	
*** obtain rally date and get event-time 
	* merge with rally data for date 
	merge m:1 rallyid using "$dropbox/Data/rallies/trump_rally_data.dta", keepusing(date)
		keep if _merge == 3
		drop _merge
	* convert rally date to Stata date format
	replace date = trim(date)
	gen month_str = substr(date, 1, strpos(date, " ") - 1)
	gen month = 1 if month_str == "January"
	replace month = 2 if month_str == "February"
	replace month = 3 if month_str == "March"
	replace month = 4 if month_str == "April"
	replace month = 5 if month_str == "May"
	replace month = 6 if month_str == "June"
	replace month = 7 if month_str == "July"
	replace month = 8 if month_str == "August"
	replace month = 9 if month_str == "September"
	replace month = 10 if month_str == "October"
	replace month = 11 if month_str == "November"
	replace month = 12 if month_str == "December"
	gen day = substr(date, strpos(date, " ") + 1, strlen(date) - strpos(date, " "))
	destring day, replace
	gen rally_date = mdy(month, day, year)
	drop year date month_str month day
	
	* identify the Saturday of rally week
	gen rally_dow = dow(rally_date)
	gen rally_weekend = rally_date + (6 - rally_dow)

	rename rally_weekend date
	format date %td

*** cross with event-time for the final panel data
	cross using `eventime'
	replace date = date + t *7
	drop rally_date rally_dow
	save "$outdir/panel_hhrally", replace
*** fmerge with hh-week data to obtain shares for event-times
	* divide the data into 21 segments, fmerge and then append due to large size
	use "$outdir/panel_hhrally", clear
	forv i = -10/10 {
		preserve 
			keep if t == `i'
			fmerge m:1 household date using "$outdir/numerator_trip_coo_2017to2021_cleaned"
				keep if _merge == 3
				drop _merge 
			save "$intdir/panel_hhrally_cleaned_`i'", replace
		restore
	}
	* append matched HH-rally-share data sets from above
	clear all 
	set obs 1 
	gen x = . 
	save "$outdir/panel_hhrally_cleaned", replace 
	forv i = -10/10 {
		append using "$intdir/panel_hhrally_cleaned_`i'"
		erase "$intdir/panel_hhrally_cleaned_`i'"
		save "$outdir/panel_hhrally_cleaned", replace
	}
	drop in 1 
	drop x
	save "$outdir/panel_hhrally_cleaned", replace 
	// note that the event times have gaps due to unmatched HH-dates in the fmerge step
	// but this is fine as in the panel regression the missing value doesn't get
	// into the estimation equation

/**************
	Event-Study Regression with Distance-Eventtime Interactions
	***************/	
	gen lndist_rally = ln(dist_rally)
	reghdfe EU i(1/9 11/21)bn.event#c.foreign##c.lndist , absorb(household_id rally_id prodtime)
	
********************************* END ******************************************

capture log close
exit
