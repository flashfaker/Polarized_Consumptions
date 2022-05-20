* to be run on Mercury

clear all
set more off

set maxvar 120000, permanently
set max_memory 1600g, permanently

cd "pconsumptions/data"

use "panel_hhrally_cleaned.dta", clear

