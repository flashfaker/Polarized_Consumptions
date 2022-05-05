* merge trump rallies data with numerator people data to create distance from
* households to each trump rally
local fname merge_trumprallies_numerator_ppl

/*******************************************************************************

* Merge Trump Rallies Data with People Data from Numerator with distance between
each household to Trump rally computed

Author: Zirui Song
Date Created: Apr 29th, 2022
Date Modified: May 4th, 2022

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
	global raldir = "$dropbox/Data/rallies"
	global zipdir = "$dropbox/Data/zip_lat_long"
	
	global outdir = "$dropbox/Data/Cleaned Data"
	global intdir = "$dropbox/Data/Cleaned Data/Intermediate"
	global logdir = "$dropbox/Code/ZS/LogFiles"
	
	* Start plain text log file with same name
	log using "$logdir/`fname'.txt", replace text
	
/**************
	Clean Numerator People Data
	***************/	
*** import Numerator Person Data
	* import 2017 data as base
	import delimited "$numdir/2017/standard_nmr_feed_people_table.csv", delimiter("|") bindquotes(nobind) clear
	gen year = 2017
	rename postal_code zip
	replace zip = "" if zip == "na"
	destring zip, replace
	save "$intdir/numerator_person_cleaned", replace
	* import 2018-2021 data
	forv yr = 2018(1)2021 {
		import delimited "$numdir/`yr'/standard_nmr_feed_people_table.csv", delimiter("|") bindquotes(nobind) clear
		gen year = `yr'
		rename postal_code zip
		replace zip = "" if zip == "na"
		destring zip, replace
		append using "$intdir/numerator_person_cleaned"
		save "$intdir/numerator_person_cleaned", replace
	}

*** import census zip code data to clean
	import delimited "$zipdir/2021_Gaz_zcta_national.txt", clear
	rename geoid zip
	keep zip intptlat intptlong
	save "$intdir/zip_lat_long", replace
	
*** Merge numerator person data with zip lat long
	use "$intdir/numerator_person_cleaned", clear
	merge m:1 zip using "$intdir/zip_lat_long"
		* most of the unmerged households from master are due to missing zip code
		* so it's fine to drop them, and we merged 710,162/810,868 obs, so the 
		* ratio is good enough
		drop if _merge != 3
		drop _merge
	rename zip zip_household
	isid household_id year
	save "$outdir/numerator_person_2017to2021", replace
	* keep only id+lat-long for merge
	keep year household_id intptlat intptlong
	save "$intdir/numerator_person_2017to2021_id_latlong_only.dta", replace
	
	
	export delimited "$intdir/numerator_person_2017to2021_id_latlong_only.csv", replace
/**************
	Joinby with Trump rally data 
	***************/	
	use "$raldir/trump_rally_data", clear
	keep rallyid year latitude longitude
	*** reshape to wide 
		drop if year < 2017
		* drop missing lat-longs
		drop if latitude >=.
		drop if longitude >=.
	export delimited "$intdir/trump_rally_data_id_latlong_only.csv", replace

		* reshape to merge with numerator data
		reshape wide latitude longitude, i(year) j(rallyid) 
	save "$intdir/trump_rally_data_id_latlong_only.dta", replace
	
*** divide the data by years and calculate distances (LONG TIME) 
	use "$intdir/numerator_person_2017to2021_id_latlong_only.dta", clear
		keep if year == 2017
		fmerge m:1 year using "$intdir/trump_rally_data_id_latlong_only.dta"
		keep if _merge==3 
		drop _merge
		forv rallyid = 215(1)224 {
			geodist intptlat intptlong latitude`rallyid' longitude`rallyid', gen(dist_rally`rallyid')
			drop latitude`rallyid' longitude`rallyid'
		}
		keep household_id year dist_rally*
		save "$outdir/numerator_person_dist_to_trumprally_2017.dta", replace
	
	use "$intdir/numerator_person_2017to2021_id_latlong_only.dta", clear
		keep if year == 2018
		fmerge m:1 year using "$intdir/trump_rally_data_id_latlong_only.dta"
		keep if _merge==3 
		drop _merge
		forv rallyid = 225(1)270 {
			geodist intptlat intptlong latitude`rallyid' longitude`rallyid', gen(dist_rally`rallyid')
			drop latitude`rallyid' longitude`rallyid'
		}
		keep household_id year dist_rally*
		save "$outdir/numerator_person_dist_to_trumprally_2018.dta", replace
		
	use "$intdir/numerator_person_2017to2021_id_latlong_only.dta", clear
		keep if year == 2019
		fmerge m:1 year using "$intdir/trump_rally_data_id_latlong_only.dta"
		keep if _merge==3 
		drop _merge
		forv rallyid = 458(1)479 {
			geodist intptlat intptlong latitude`rallyid' longitude`rallyid', gen(dist_rally`rallyid')
			drop latitude`rallyid' longitude`rallyid'
		}
		keep household_id year dist_rally*
		save "$outdir/numerator_person_dist_to_trumprally_2019.dta", replace
		
	use "$intdir/numerator_person_2017to2021_id_latlong_only.dta", clear
		keep if year == 2020
		fmerge m:1 year using "$intdir/trump_rally_data_id_latlong_only.dta"
		keep if _merge==3 
		drop _merge
			geodist intptlat intptlong latitude1 longitude1, gen(dist_rally1)
			drop latitude1 longitude1
		forv rallyid = 148(1)214 {
			geodist intptlat intptlong latitude`rallyid' longitude`rallyid', gen(dist_rally`rallyid')
			drop latitude`rallyid' longitude`rallyid'
		}
		forv rallyid = 480(1)489 {
			geodist intptlat intptlong latitude`rallyid' longitude`rallyid', gen(dist_rally`rallyid')
			drop latitude`rallyid' longitude`rallyid'
		}
		keep household_id year dist_rally*
		save "$outdir/numerator_person_dist_to_trumprally_2020.dta", replace
		
	use "$intdir/numerator_person_2017to2021_id_latlong_only.dta", clear
		keep if year == 2021
		fmerge m:1 year using "$intdir/trump_rally_data_id_latlong_only.dta"
		keep if _merge==3 
		drop _merge
		forv rallyid = 2(1)9 {
			geodist intptlat intptlong latitude`rallyid' longitude`rallyid', gen(dist_rally`rallyid')
			drop latitude`rallyid' longitude`rallyid'
		}
		keep household_id year dist_rally*
		save "$outdir/numerator_person_dist_to_trumprally_2021.dta", replace
		
/**************
	Reshape and Merge Cleaned Trump Rally Data
	***************/	
	* reshape distance data to long format
	forv yr = 2017/2021 {
		use "$outdir/numerator_person_dist_to_trumprally_`yr'.dta", clear
		reshape long dist_rally, i(household_id) j(rallyid)
		save "$intdir/numerator_person_dist_to_trumprally_`yr'_reshaped", replace
	}
	* append all years
	use "$intdir/numerator_person_dist_to_trumprally_2017_reshaped", clear
	forv yr = 2018/2021 {
		append using "$intdir/numerator_person_dist_to_trumprally_`yr'_reshaped"
		save "$outdir/numerator_person_dist_to_trumprally_2017to2021_reshaped", replace
	}
	* remove the annual data after appending
	forv yr = 2017/2021 {
		rm "$intdir/numerator_person_dist_to_trumprally_`yr'_reshaped.dta" 
	}

********************************* END ******************************************

capture log close
exit
