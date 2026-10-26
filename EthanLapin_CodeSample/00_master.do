/*-------------------------------------------------------------
File:       00_master.do
Project: 	2026 Act 76 Research
Author: 	Ethan M. Lapin
Purpose:    Installs Packages and Runs All Do Files
Inputs:     data/raw/usa_00005.* (loaded via usa_00005.do)in 01
Outputs:    N/A
Run order:  Master
-------------------------------------------------------------*/
version 19

/* ===================================================================================
			==		Raw Data Access: 		==
A link to a .gz file with the raw data and a .md file listing all components
of the extract can be found in this Google Drive link:
https://drive.google.com/drive/folders/1xpqvrsA05jlBcjkyc9vS3_YpVeboz40Q?usp=sharing
you MUST download the data into the project folder prior to running code
=====================================================================================*/

/*=====================================================================
			==		Saving Instructions:		==	
The following block will make a set of folders in whichever directory, 
you assign as the root. It will also move all relevant files from the 
.zip into the folders in which they belong 
======================================================================*/

global PROJ "/Users/ethanlapin/Desktop/EthanLapin_CodeSample" //set to wherever the file lives on your machine
	cap mkdir "$PROJ/scripts"
	cap mkdir "$PROJ/scripts/stata"
	cap mkdir "$PROJ/scripts/stata/_outputs"
	cap mkdir "$PROJ/scripts/stata/_outputs/logs"
	cap mkdir "$PROJ/data"
	cap mkdir "$PROJ/data/clean"
	cap mkdir "$PROJ/data/raw"
	cap mkdir "$PROJ/figures"
local indir "$PROJ"
local outdir "$PROJ/scripts/stata"
local files : dir "`indir'" files "*.do"
foreach f in `files' {
	copy "`indir'/`f'" "`outdir'/`f'", replace
	erase "`indir'/`f'"
}
copy "`indir'/usa_00005.dat" "$PROJ/data/raw/usa_00005.dat"
erase "`indir'/usa_00005.dat"


* --- Essential Package installs (comment out after first run) --- *
// cap ssc install reghdfe     // High-dimensional FE regressions
// cap ssc install ftools      // Required by reghdfe
// cap ssc install require 		// Required by reghdfe 
// cap ssc install estout      // esttab / eststo for LaTeX tables	
// cap ssc install sdid			// Synth DiD
// cap ssc install drdid		// Sant'Anna-Zhao Doubly Robust DiD
// cap ssc install honestdid	// Rambachan-Roth Honest Bounds 
// cap ssc install csdid		// Callaway-Sant'Anna DiD
// cap ssc install parallel 	// parallel package for honestdid

/*---------------------------------------
Run All Do Files (_config runs indep.)
This Will Take A Substantial Amount of 
Time - EML
---------------------------------------*/
do "$PROJ/scripts/stata/01_loadclean.do"
do "$PROJ/scripts/stata/02_descriptive.do"
do "$PROJ/scripts/stata/03_main.do"
do "$PROJ/scripts/stata/04_act45pooled.do"
do "$PROJ/scripts/stata/05_fathers.do"
