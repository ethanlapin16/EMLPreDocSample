/*------------------------------------------------------------
File:       02_descriptive.do
Project: 	2026 Act 76 Research
Author: 	Ethan M. Lapin
Other Credits: LaTeX writing code engineered by Claude
Purpose:    Creates descriptive tables and figures for paper
Inputs:     data/clean/cleaned_dataset.dta
Outputs:    scripts/stata/_outputs/ and scripts/stata/figures
Run order:  After 01_loadclean.do
------------------------------------------------------------*/
version 19                        // pin Stata semantics
clear all
set more off
cap log close _all
log using "$PROJ/scripts/stata/_outputs/logs/02_descriptive.log", replace

//-----------------------------------------------------------
* --- Load data via config to reference configs --- *
do "$PROJ/scripts/stata/_config.do"

/*========================================================================
Table 1: Summary statistics -- mean (SD) by group 2018-2023, weighted)
Panel A is dependent variables
Panel B is covariates
========================================================================*/
preserve
	keep if inrange(year, 2018,2023) & mother_elig == 1     // analysis sample: mothers, pre-period
		
	* --- Panel A: dependent / explanatory (outcome) variables --- *
	local Avars lf_indicator uhrswork
	local Albls `"  "Labor force participation" "Usual weekly hours worked"  "'
	local Atype  pct          raw //assigns each avar a type

	* --- Panel B: mother-level covariates --- *
	local Bvars age single_mother white black aian asian otherr mixedr hispanic is_citizen in_school diploma associate bachelor high_degree rural nchild hhincome_k
	local Blbls `" "Age" "Single mother" "White, non-Hispanic" "Black, non-Hispanic" "AIAN, non-Hispanic" "Asian/PI, non-Hispanic" "Other race, non-Hispanic" "Two or more races" "Hispanic" "U.S. citizen" "In school" "HS diploma" "Associate degree" "Bachelor's degree" "Graduate degree"  "Nonmetro" "Number of own children" "Household income (in thousands)" "'
	local Btype raw pct pct pct pct pct pct pct pct pct pct pct pct pct pct pct raw usd // assigns each bvar a type
			local nA : word count `Avars'
			local nB : word count `Bvars'
			matrix M = J(`=`nA'+`nB'', 4, .) //Counts variables in each panel and builds a matrix with that many rows and 4 columns filled with "."
		* Fill matrix M (cols: 1 T_mean 2 T_sd  3 C_mean 4 C_sd)
	local r = 0                       // matrix row counter (runs across both panels), starts at 0
	foreach v of local Avars {        // Panel A: outcome variables
		local ++r						//next row
		qui sum `v' [aw=perwt] if Treat == 1   // VT (treated)
		matrix M[`r',1] = r(mean) 					//stores mean
		matrix M[`r',2] = r(sd) 					//stores SD
		qui sum `v' [aw=perwt] if Treat == 0   // control states
		matrix M[`r',3] = r(mean)
		matrix M[`r',4] = r(sd)
	}
	foreach v of local Bvars {        // Panel B: covariates 
		local ++r
		qui sum `v' [aw=perwt] if Treat == 1
		matrix M[`r',1] = r(mean)
		matrix M[`r',2] = r(sd)
		qui sum `v' [aw=perwt] if Treat == 0
		matrix M[`r',3] = r(mean)
		matrix M[`r',4] = r(sd)
	}
	* --- unweighted observation counts per group (%12.0fc = comma-grouped integer) --- *
	count if Treat == 1
	local nTf = string(r(N), "%12.0fc")
	count if Treat == 0
		local nCf = string(r(N), "%12.0fc")

	* --- echo the same numbers to the results window --- *
	matrix rownames M = `Avars' `Bvars'
	matrix colnames M = T_mean T_sd C_mean C_sd
	matlist M, format(%9.3f) title("Table 1: Mean (SD) by group, pre-period mothers, sample-weighted")

/*---------- Write LaTeX ------------ */
/*-----------------------------------------------------------
Cell formatter program to assign proper lengths or symbols
------------------------------------------------------------*/
cap program drop fmtcell 
program define fmtcell, rclass
    args v typ
    if "`typ'" == "pct"      return local s = (string(100*`v', "%9.1f")) + "\%"
    else if "`typ'" == "usd" return local s = "\$" + (string(`v', "%9.0fc"))
    else                     return local s = (string(`v', "%9.2f"))
end
*---------------------------------------------------------------

cap mkdir "$PROJ/scripts/stata/_outputs" // points Stata at the outputs folder 
	tempname fa //creates a name to more easily reference 
	file open `fa' using "$PROJ/scripts/stata/_outputs/tab_sumstats.tex", write replace text
	file write `fa' "{\footnotesize" _n
	file write `fa' "\setlength{\tabcolsep}{4pt}\renewcommand{\arraystretch}{0.9}" _n
	file write `fa' "\begin{tabular}{lcc}" _n
	file write `fa' "\toprule" _n
	file write `fa' " & Treatment & Control \\" _n
	file write `fa' " & mean (sd) & mean (sd) \\" _n
	file write `fa' "\midrule" _n
	* Panel A *
	file write `fa' "\multicolumn{3}{l}{\textit{Dependent / explanatory variables}} \\" _n
	forvalues r = 1/`nA' {
		local lab : word `r' of `Albls'
		local typ : word `r' of `Atype'
		fmtcell M[`r',1] "`typ'" //formats cell according to type
		local mT `r(s)' // treatment mean
		fmtcell M[`r',2] "`typ'"
		local sT `r(s)' // treatment SD
		fmtcell M[`r',3] "`typ'"
		local mC `r(s)' // control mean
		fmtcell M[`r',4] "`typ'"
		local sC `r(s)' // control SD
		file write `fa' "`lab' & `mT' (`sT') & `mC' (`sC') \\" _n //in row writes label and means + SDs 
		}
		file write `fa' "\addlinespace" _n
	* Panel B *
	file write `fa' "\multicolumn{3}{l}{\textit{Covariates}} \\" _n
	forvalues r = 1/`nB' {
		local lab : word `r' of `Blbls'
		local typ : word `r' of `Btype'
		local row = `nA' + `r'                 // Panel B occupies matrix rows nA+1 .. nA+nB
		fmtcell M[`row',1] "`typ'"
		local mT `r(s)'
		fmtcell M[`row',2] "`typ'"
		local sT `r(s)'
		fmtcell M[`row',3] "`typ'"
		local mC `r(s)'
		fmtcell M[`row',4] "`typ'"
		local sC `r(s)'
		file write `fa' "`lab' & `mT' (`sT') & `mC' (`sC') \\" _n
	}
	file write `fa' "\addlinespace" _n
	file write `fa' "Observations & `nTf' & `nCf' \\" _n
	file write `fa' "\bottomrule" _n
	file write `fa' "\end{tabular}" _n
	file write `fa' "}" _n
	file close `fa'
	di as txt "Wrote scripts/stata/_outputs/tab_sumstats.tex"
restore


/*=========================================================================
Table 2: Two-period covariate balance, eligible mothers
Purpose: help justify CONDITIONAL parallel trends for the DR DiD by 
showing (A) the baseline composition of treated vs. control eligible mothers 
and (B) whether their covariates were on parallel paths over the pre-period.
Rule of thumb from Baker et al. (2026): |norm./std. diff| > 0.25 = imbalance
============================================================================*/

local y0 = 2023     // pre year
local y1 = 2024      // post year
local lbls `" "Age" "Age Squared" "Single mother" "White, non-Hispanic" "Black, non-Hispanic" "AIAN, non-Hispanic" "Asian/PI, non-Hispanic" "Two or more races" "Hispanic" "U.S. citizen" "HS diploma" "Associate degree" "Bachelor's degree" "Graduate degree" "Nonmetro/Rural" "Number of own children" "'
local nc : word count $covs_d //creates a var that is the number of words in this string, each "" is one 'word'

/* ========================================================================
Propensity score for IPW-ATT reweighting, Aligned with the DR estimator 
in 03_main.do: same covariate set ($covs_main), same iweights,
and controls trimmed at p>0.995 (drdid's default).03 uses drdid w/drimp, 
whose pscore is fit by inverse-probability tilting, not logit MLE,
so these weights are an approximation of the estimator's odds weights.
We reweight CONTROLS toward Vermont, treated keep survey weights, 
so the Vermont column is identical across the two blocks by construction.
===========================================================================*/
cap drop ps_hat odds w_att
/* pscore uses $covs_main (the estimator's set); identical fitted values to $covs_d
since they differ only in which single race dummy is the omitted reference. */
logit Treat $covs_d [iw=perwt] if mother_elig==1 & inrange(year,`y0',`y1')
predict double ps_hat if e(sample), pr
* trim controls with p > 0.995, matching drdid's default pscoretrim(0.995)
replace ps_hat = . if ps_hat > .995 & Treat==0
gen double odds = ps_hat/(1-ps_hat)
gen double w_att = cond(Treat==1, perwt, perwt*odds)
* effective sample size of the reweighted control group (overlap diagnostic)
preserve
	keep if Treat==0 & mother_elig==1 & inrange(year,`y0',`y1') & w_att<.
	gen double w2 = w_att^2
	qui sum w_att, detail
	scalar sumw = r(sum)
	local  Nc   = r(N)
	qui sum w2
	scalar sumw2 = r(sum)
		scalar ess = sumw^2/sumw2
		di as txt "IPW-reweighted control ESS = " string(ess,"%9.1f") " (raw control N = `Nc'); trimmed obs excluded."
restore

* ---- Panel A: baseline levels at `y0' --- * 
/*   cols: 1 Ctrl(survey) 2 VT(survey) 3 ND(survey) 4 Ctrl(IPW) 5 VT(IPW) 6 ND(IPW)
wcol 0 = perwt survey-weighted means, wcol 1 = IPW-ATT reweighted means. */
matrix A = J(`nc', 6, .)
forvalues wcol = 0/1 { //block 0 = survey-weighted, block 1 = IPW-reweighted
	if `wcol' == 0  local wt "[aw=perwt]"   // survey-weighted (perwt)
	else            local wt "[aw=w_att]"   // IPW-ATT reweighted
	local base = 3*`wcol' //allows us to offset to weight columns
preserve
	keep if mother_elig == 1 & year == `y0'
	local r = 0
foreach v of global covs_d {
	local ++r 
	qui sum `v' `wt' if Treat == 0
	local m0 = r(mean)
	local s0 = r(sd)
	qui sum `v' `wt' if Treat == 1 
	local m1 = r(mean)
	local s1 = r(sd)
	matrix A[`r',`base'+1] = `m0'
	matrix A[`r', `base' +2] = `m1'
	matrix A[`r', `base'+3] = (`m1'-`m0') / sqrt((`s1'^2 + `s0'^2)/2)
	}
restore
}
matrix rownames A = $covs_d
matrix colnames A = Ctrl_sw VT_sw ND_sw Ctrl_ipw VT_ipw ND_ipw

/* ---- Panel B: (`y1' - `y0') change in state-year cell means (survey-weighted) --
Std. diff = (mean Del. VT - mean Del. control)/SD(Del. control).
Survey-weighted ONLY: pre-trends are a dynamic diagnostic, so the
cross-sectional IPW composition reweighting (Panel A) is not applied here. */
matrix B = J(`nc', 3, .)
preserve
	keep if mother_elig == 1 & inlist(year, `y0', `y1')
	collapse (mean) $covs_d [aw=perwt], by(statefip Treat year) //weighted mother mean per state-year cell
	reshape wide $covs_d, i(statefip Treat) j(year) // rows by state, columns per year (e.g. age2018, age2023)
	local r = 0
	foreach v of global covs_d {
		local ++r
		gen double d_`v' = `v'`y1' - `v'`y0' //change in the cell mean across the 2x2
		qui sum d_`v' if Treat == 0       // across the control states
		local m0 = r(mean)
		local s0 = r(sd)
		qui sum d_`v' if Treat == 1       // VT specifically
		local m1 = r(mean)
		matrix B[`r',1] = `m0'
		matrix B[`r',2] = `m1'
		matrix B[`r',3] = (`m1'-`m0')/`s0'
	}
restore
matrix rownames B = $covs_d
matrix colnames B = Ctrl_sw VT_sw SD_sw

* ---- echo both panels to the results window ---------------------------------
matlist A, format(%9.3f) title("Table 2A: Baseline (`y0') levels, eligible mothers; |ND|>0.25 flags imbalance")
matlist B, format(%9.3f) title("Table 2B: Pre-period change (`y1'-`y0') in cell means; std. by control dispersion")

* ---- Write LaTeX: Table 2A -- baseline levels balance (survey vs IPW) --------
cap mkdir "$PROJ/scripts/stata/_outputs"
local esstxt = string(ess,"%9.0f")
tempname fb
file open `fb' using "$PROJ/scripts/stata/_outputs/tab_balance_levels.tex", write replace text
file write `fb' "\begin{table}[H]" _n
file write `fb' "\centering" _n
file write `fb' "\caption{Pre-Period Covariate Levels}" _n
file write `fb' "\label{tab:bal_levels}" _n
file write `fb' "{\footnotesize" _n
file write `fb' "\setlength{\tabcolsep}{3pt}\renewcommand{\arraystretch}{0.75}" _n
file write `fb' "\begin{tabular}{lcccccc}" _n
file write `fb' "\toprule" _n
file write `fb' " & \multicolumn{3}{c}{Survey-weighted} & \multicolumn{3}{c}{IPW-reweighted} \\" _n
file write `fb' "\cmidrule(lr){2-4}\cmidrule(lr){5-7}" _n
file write `fb' "Variable & Control & Vermont & Norm. Diff. & Control & Vermont & Norm. Diff. \\" _n
file write `fb' "\midrule" _n
forvalues r = 1/`nc' {
	local lab : word `r' of `lbls'
	local c1 = string(A[`r',1], "%9.3f")
	local c2 = string(A[`r',2], "%9.3f")
	local c3 = string(A[`r',3], "%9.3f")
	local c4 = string(A[`r',4], "%9.3f")
	local c5 = string(A[`r',5], "%9.3f")
	local c6 = string(A[`r',6], "%9.3f")
	file write `fb' "`lab' & `c1' & `c2' & `c3' & `c4' & `c5' & `c6' \\" _n
}
file write `fb' "\bottomrule" _n
file write `fb' "\end{tabular}" _n
file write `fb' "\par\smallskip {\scriptsize \textit{Note:} 2023 baseline levels for eligible mothers. Survey-weighted columns use ACS person weights. IPW-reweighted columns apply Sant'Anna--Zhao (2020) odds weights $\hat p/(1-\hat p)$ to control mothers, with the propensity score fit on the estimator's covariate set and control observations trimmed at $\hat p>0.995$. The improved DR estimator used for analysis uses inverse-probability tilting, which balances  covariates exactly by construction.}" _n
file write `fb' "}" _n
file write `fb' "\end{table}"
file close `fb'
di as txt "Wrote scripts/stata/_outputs/tab_balance_levels.tex"

* ---- Write LaTeX: Table 2B -- pre-period covariate trends (survey-weighted) --
tempname fc
file open `fc' using "$PROJ/scripts/stata/_outputs/tab_balance_trends.tex", write replace text
file write `fc' "\begin{table}[H]" _n
file write `fc' "\centering" _n
file write `fc' "\caption{Covariate Balance in Changes Across the 2x2}" _n
file write `fc' "\label{tab:bal_trends}" _n
file write `fc' "{\footnotesize" _n
file write `fc' "\setlength{\tabcolsep}{6pt}\renewcommand{\arraystretch}{0.75}" _n
file write `fc' "\begin{tabular}{lccc}" _n
file write `fc' "\toprule" _n
file write `fc' "Variable & Control & Vermont & Std. Diff. \\" _n
file write `fc' "\midrule" _n
forvalues r = 1/`nc' {
	local lab : word `r' of `lbls'
	local c1 = string(B[`r',1], "%9.3f")
	local c2 = string(B[`r',2], "%9.3f")
	local c3 = string(B[`r',3], "%9.3f")
	file write `fc' "`lab' & `c1' & `c2' & `c3' \\" _n
}
file write `fc' "\bottomrule" _n
file write `fc' "\end{tabular}" _n
file write `fc' "\par\smallskip {\scriptsize \textit{Notes:}Change in survey-weighted state-year cell means, `y0'--`y1', for eligible mothers. Std.\ diff.\ = (Vermont change $-$ mean control change) $/$ SD(control change). This compares covariate changes across the 2x2 and is informative about parallel trends only for covariates unaffected by treatment. The cross-sectional IPW reweighting used in Table~\ref{tab:bal_levels} is not applied here.}" _n
file write `fc' "}" _n
file write `fc' "\end{table}"
file close `fc'
di as txt "Wrote scripts/stata/_outputs/tab_balance_trends.tex"
cap drop ps_hat odds w_att
cap scalar drop ess sumw sumw2

/*=================================================================================
Table 3: Baseline (pre-period) dependent variables, 2023
=================================================================================*/
local outcomes employed lf_indicator fulltime uhrswork wkswork lincome
local no : word count `outcomes' //counts the variables in the list
matrix O = J(`no', 6, .) 
local r = 0 
foreach v of local outcomes {
	local ++r 
	* --- unweighted --- * 
	qui sum `v' if Treat == 0 & year == 2023 & mother_elig == 1 
	local m0 = r(mean)
	local s0 = r(sd)
	qui sum `v' if Treat == 1 & year == 2023 & mother_elig == 1
	local m1 = r(mean)
	local s1 = r(sd)
	matrix O[`r',1] = `m0' //whichever row we are on, begins populating 
	matrix O[`r',2] = `m1'
	matrix O[`r',3] = (`m1'-`m0') / sqrt((`s1'^2 + `s0'^2)/2) 
	* --- perwt-weighted ---
	qui sum `v' [aw=perwt] if Treat == 0 & year == 2023 & mother_elig == 1
	local m0 = r(mean)
	local s0 = r(sd)
	qui sum `v' [aw=perwt] if Treat == 1 & year == 2023 & mother_elig == 1
	local m1 = r(mean)
	local s1 = r(sd)
	matrix O[`r',4] = `m0'
	matrix O[`r',5] = `m1'
	matrix O[`r',6] = (`m1'-`m0') / sqrt((`s1'^2 + `s0'^2)/2)
}
matrix rownames O = `outcomes'
matrix colnames O = Ctrl_unw VT_unw ND_unw Ctrl_wt VT_wt ND_wt
matlist O, format(%9.3f) title("Table 3: Baseline (2023) dependent variables; pre-treatment comparison")


/*============================================================================
Figure 1: Two-Way Pre-Trends Figure: LFP, Vermont vs. control states
============================================================================*/
preserve
	collapse (mean) lf_indicator [pw=perwt] if mother_elig == 1, by(Treat year)
	qui sum year
	local ymin = r(min)
	local ymax = r(max)
	twoway ///
		(line    lf_indicator year if Treat == 1, lcolor(red)  lpattern(solid) lwidth(medium)) ///
		(line    lf_indicator year if Treat == 0, lcolor(blue) lpattern(solid) lwidth(medium)) ///
		(scatter lf_indicator year if Treat == 1, msymbol(O)  mcolor(red)) ///
		(scatter lf_indicator year if Treat == 0, msymbol(Oh) mcolor(blue)) , ///
		legend(order(1 "Vermont" 2 "Control States") pos(6) ring(2) cols(2)) ///
		xtitle("") ///
		ytitle("Labor Force Participation", orientation(horizontal)) ///
		ysize(5) xsize(10) ///
		xline(2023.5, lpattern(dash) lcolor(gs8)) ///
		xlabel(`ymin' (1)`ymax', nogrid) ///
		graphregion(color(white)) ///
		plotregion(style(none))
	cap mkdir "$PROJ/figures" // point towards the correct folder
	graph export "$PROJ/figures/LFPpreTrend_stata.pdf", replace
	di as txt "Wrote Figure 1"
restore
/*============================================================================
Figure 2: Two-Way Pre-Trends Figure: Hours Worked, Vermont vs. control states
============================================================================*/
preserve
	collapse (mean) uhrswork [pw=perwt] if mother_elig == 1, by(Treat year)
	qui sum year
	local ymin = r(min)
	local ymax = r(max)
	twoway ///
		(line    uhrswork year if Treat == 1, lcolor(red)  lpattern(solid) lwidth(medium)) ///
		(line    uhrswork year if Treat == 0, lcolor(blue) lpattern(solid) lwidth(medium)) ///
		(scatter uhrswork year if Treat == 1, msymbol(O)  mcolor(red)) ///
		(scatter uhrswork year if Treat == 0, msymbol(Oh) mcolor(blue)) , ///
		legend(order(1 "Vermont" 2 "Control States") pos(6) ring(2) cols(2)) ///
		xtitle("") ///
		ytitle("Average Weekly Hours Worked", orientation(horizontal)) ///
		ysize(5) xsize(10) ///
		xline(2023.5, lpattern(dash) lcolor(gs8)) ///
		xlabel(`ymin' (1)`ymax', nogrid) ///
		graphregion(color(white)) ///
		plotregion(style(none))
	cap mkdir "$PROJ/figures"
	graph export "$PROJ/figures/HourspreTrend_stata.pdf", replace
	di as txt "Wrote Figure 2"
restore
	
cap log close
