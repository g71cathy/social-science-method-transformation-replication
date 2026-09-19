********************************************************************************
* Robustness check: Alternative measures of AI knowledge exposure
*
* Purpose:
* Replicate the baseline specification in "0801" and replace the
* independent variable with alternative AI exposure measures.
*
* Unit: subfield × year
*
* Outcomes:
*   C = Computational/AI methods
*   F = Formal modelling
*   H = Historical/interpretive approaches
*   N = Traditional quantitative methods
*   Q = Qualitative-empirical approaches
*   T = Theoretical/normative scholarship
*
* Model:
* MethodShare_jt =
*     beta * AIExposure_j,t-1
*     + lagged controls
*     + subfield FE
*     + year FE
*     + error
*
* SE: clustered by subfield
********************************************************************************

clear all
set more off
set maxvar 32767


********************************************************************************
* 1. PATHS
*
* Run this do-file from the repository root.
********************************************************************************

global project_dir "."

global input_file ///
    "$project_dir/data/study2_subfield_year_panel.xlsx"

global output_dir ///
    "$project_dir/outputs/study2_robustness"

capture mkdir "$project_dir/outputs"
capture mkdir "$output_dir"


********************************************************************************
* 2. IMPORT DATA
********************************************************************************

import excel using "$input_file", ///
    sheet("Panel_method_wide") ///
    firstrow clear


********************************************************************************
* 3. CHECK REQUIRED VARIABLES
********************************************************************************

local required_vars ///
    subfield_id ///
    year ///
    is_partial_year ///
    method_share_C ///
    method_share_F ///
    method_share_H ///
    method_share_N ///
    method_share_Q ///
    method_share_T ///
    ai_method_topic_keyword_exposure ///
    iv3_reference_ai_ref_tier1_share ///
    iv4_reference_ai_ref_tier1_tier2_share ///
    ai_method_keyword_exposure ///
    log1p_paper_count ///
    paper_count_growth_rate ///
    avg_team_size ///
    topic_entropy_normalized ///
    cross_field_topic_share

foreach var of local required_vars {

    capture confirm variable `var'

    if _rc {
        display as error "ERROR: variable not found: `var'"
        exit 111
    }
}


********************************************************************************
* 4. CONSTRUCT NUMERIC SUBFIELD IDENTIFIER
********************************************************************************

capture confirm numeric variable subfield_id

if _rc {
    encode subfield_id, gen(panel_id)
}
else {
    gen long panel_id = subfield_id
}

label variable panel_id "Subfield panel identifier"


********************************************************************************
* 5. REMOVE PARTIAL YEAR (2026)
********************************************************************************

capture confirm numeric variable is_partial_year

if !_rc {
    drop if is_partial_year == 1
}
else {
    drop if inlist(lower(strtrim(is_partial_year)), ///
        "true", "yes", "1")
}


********************************************************************************
* 6. BASIC PANEL CHECK
********************************************************************************

isid panel_id year, sort

sort panel_id year

display as text "------------------------------------------"
display as text "Sample after dropping partial years:"
count

display as text "Number of subfields:"
egen __tag = tag(panel_id)
count if __tag == 1
drop __tag

summarize year


********************************************************************************
* 7. GENERATE STRICT ONE-YEAR-LAGGED AI EXPOSURES
*
* Lag is created ONLY when year t-1 actually exists.
********************************************************************************

* --------------------------------------------------------------------------
* X1. Baseline: generalized AI knowledge exposure
* --------------------------------------------------------------------------

by panel_id (year): gen double exposure_baseline_l1 = ///
    ai_method_topic_keyword_exposure[_n-1] ///
    if _n > 1 & year == year[_n-1] + 1


* --------------------------------------------------------------------------
* X2. Reference-based AI exposure: Tier 1
* --------------------------------------------------------------------------

by panel_id (year): gen double exposure_ref_tier1_l1 = ///
    iv3_reference_ai_ref_tier1_share[_n-1] ///
    if _n > 1 & year == year[_n-1] + 1


* --------------------------------------------------------------------------
* X3. Reference-based AI exposure: Tier 1 + Tier 2
* --------------------------------------------------------------------------

by panel_id (year): gen double exposure_ref_tier12_l1 = ///
    iv4_reference_ai_ref_tier1_tier2_share[_n-1] ///
    if _n > 1 & year == year[_n-1] + 1


* --------------------------------------------------------------------------
* X4. AI method-specific keyword exposure
* --------------------------------------------------------------------------

by panel_id (year): gen double exposure_method_l1 = ///
    ai_method_keyword_exposure[_n-1] ///
    if _n > 1 & year == year[_n-1] + 1


********************************************************************************
* 8. GENERATE STRICT ONE-YEAR-LAGGED CONTROLS
********************************************************************************

by panel_id (year): gen double control_log_papers_l1 = ///
    log1p_paper_count[_n-1] ///
    if _n > 1 & year == year[_n-1] + 1

by panel_id (year): gen double control_growth_l1 = ///
    paper_count_growth_rate[_n-1] ///
    if _n > 1 & year == year[_n-1] + 1

by panel_id (year): gen double control_team_size_l1 = ///
    avg_team_size[_n-1] ///
    if _n > 1 & year == year[_n-1] + 1

by panel_id (year): gen double control_entropy_l1 = ///
    topic_entropy_normalized[_n-1] ///
    if _n > 1 & year == year[_n-1] + 1

by panel_id (year): gen double control_cross_field_l1 = ///
    cross_field_topic_share[_n-1] ///
    if _n > 1 & year == year[_n-1] + 1


local controls ///
    control_log_papers_l1 ///
    control_growth_l1 ///
    control_team_size_l1 ///
    control_entropy_l1 ///
    control_cross_field_l1


********************************************************************************
* 9. DESCRIPTIVE CHECK OF FOUR EXPOSURE MEASURES
********************************************************************************

summarize ///
    ai_method_topic_keyword_exposure ///
    iv3_reference_ai_ref_tier1_share ///
    iv4_reference_ai_ref_tier1_tier2_share ///
    ai_method_keyword_exposure

summarize ///
    exposure_baseline_l1 ///
    exposure_ref_tier1_l1 ///
    exposure_ref_tier12_l1 ///
    exposure_method_l1


********************************************************************************
* 10. CHECK CORRELATIONS AMONG ALTERNATIVE EXPOSURE MEASURES
********************************************************************************

pwcorr ///
    ai_method_topic_keyword_exposure ///
    iv3_reference_ai_ref_tier1_share ///
    iv4_reference_ai_ref_tier1_tier2_share ///
    ai_method_keyword_exposure, ///
    sig obs


********************************************************************************
* 11. DEFINE METHOD OUTCOMES AND EXPOSURES
********************************************************************************

local methods C F H N Q T

local exposures ///
    exposure_baseline_l1 ///
    exposure_ref_tier1_l1 ///
    exposure_ref_tier12_l1 ///
    exposure_method_l1


********************************************************************************
* 12. MAIN ROBUSTNESS REGRESSIONS
*
* This is the specification corresponding to the controlled column
* of the 0801 baseline regressions.
********************************************************************************

tempname results
tempfile regression_results

postfile `results' ///
    byte exposure_id ///
    str40 exposure ///
    str1 method ///
    double coef ///
    double se ///
    double tstat ///
    double pvalue ///
    double ci_low ///
    double ci_high ///
    long N ///
    int clusters ///
    double r2 ///
    using `regression_results', replace


local xnum = 0

foreach x of local exposures {

    local ++xnum

    display as result ""
    display as result "======================================================="
    display as result " Exposure `xnum': `x'"
    display as result "======================================================="


    foreach m of local methods {

        local y method_share_`m'

        regress `y' ///
            `x' ///
            `controls' ///
            i.panel_id ///
            i.year, ///
            vce(cluster panel_id)


        * Core coefficient
        local b = _b[`x']
        local se = _se[`x']

        * t statistic
        local t = `b' / `se'

        * two-sided p value
        local p = 2 * ttail(e(df_r), abs(`t'))

        * 95% confidence interval
        local low  = `b' - invttail(e(df_r), 0.025) * `se'
        local high = `b' + invttail(e(df_r), 0.025) * `se'

        * number of clusters
        quietly levelsof panel_id if e(sample), local(clusterlist)
        local G : word count `clusterlist'


        post `results' ///
            (`xnum') ///
            ("`x'") ///
            ("`m'") ///
            (`b') ///
            (`se') ///
            (`t') ///
            (`p') ///
            (`low') ///
            (`high') ///
            (e(N)) ///
            (`G') ///
            (e(r2))


        display as text ///
            "Method `m': beta=" %8.4f `b' ///
            "  SE=" %8.4f `se' ///
            "  p=" %8.4f `p' ///
            "  N=" e(N)
    }
}

postclose `results'


********************************************************************************
* 13. LOAD STORED RESULTS
********************************************************************************

use `regression_results', clear


********************************************************************************
* 14. LABEL EXPOSURE MEASURES
********************************************************************************

gen str50 exposure_label = ""

replace exposure_label = ///
    "Baseline: generalized AI knowledge exposure" ///
    if exposure_id == 1

replace exposure_label = ///
    "Reference-based AI exposure: Tier 1" ///
    if exposure_id == 2

replace exposure_label = ///
    "Reference-based AI exposure: Tier 1+Tier 2" ///
    if exposure_id == 3

replace exposure_label = ///
    "AI method-specific keyword exposure" ///
    if exposure_id == 4


********************************************************************************
* 15. METHOD LABELS
********************************************************************************

gen str45 method_label = ""

replace method_label = ///
    "Computational/AI methods" if method == "C"

replace method_label = ///
    "Formal modelling" if method == "F"

replace method_label = ///
    "Historical/interpretive approaches" if method == "H"

replace method_label = ///
    "Traditional quantitative methods" if method == "N"

replace method_label = ///
    "Qualitative-empirical approaches" if method == "Q"

replace method_label = ///
    "Theoretical/normative scholarship" if method == "T"


********************************************************************************
* 16. SIGNIFICANCE STARS
********************************************************************************

gen str3 stars = ""

replace stars = "***" if pvalue < 0.01
replace stars = "**"  if pvalue >= 0.01 & pvalue < 0.05
replace stars = "*"   if pvalue >= 0.05 & pvalue < 0.10


gen str30 coef_se = ///
    string(coef, "%9.3f") + stars + ///
    " (" + string(se, "%9.3f") + ")"


********************************************************************************
* 17. BENJAMINI-HOCHBERG FDR ADJUSTMENT
*
* Six method outcomes are corrected separately within each
* AI exposure measure.
********************************************************************************

sort exposure_id pvalue

by exposure_id: gen rank = _n
by exposure_id: gen number_tests = _N

gen double bh_raw = ///
    pvalue * number_tests / rank


* Enforce monotonicity of BH-adjusted p-values
gsort exposure_id -rank

by exposure_id: gen double fdr_p = bh_raw if _n == 1

by exposure_id: replace fdr_p = ///
    min(bh_raw, fdr_p[_n-1]) ///
    if _n > 1

replace fdr_p = min(fdr_p, 1)

sort exposure_id rank


********************************************************************************
* 18. DISPLAY COMPLETE RESULTS
********************************************************************************

format coef se pvalue fdr_p %9.4f

list ///
    exposure_label ///
    method_label ///
    coef ///
    se ///
    pvalue ///
    fdr_p ///
    N ///
    clusters, ///
    sepby(exposure_id) ///
    noobs abbreviate(40)


********************************************************************************
* 19. DISPLAY ONLY COMPUTATIONAL/AI METHOD RESULTS
********************************************************************************

display as result ""
display as result "======================================================="
display as result " Computational/AI method: comparison across exposures"
display as result "======================================================="

list ///
    exposure_label ///
    coef ///
    se ///
    pvalue ///
    fdr_p ///
    N ///
    if method == "C", ///
    noobs abbreviate(45)


********************************************************************************
* 20. SAVE FULL RESULTS AS STATA DATA
********************************************************************************

save ///
    "$output_dir/alternative_AI_exposure_robustness_results.dta", ///
    replace


********************************************************************************
* 21. EXPORT FULL RESULTS TO EXCEL
********************************************************************************

export excel ///
    exposure_id ///
    exposure_label ///
    method ///
    method_label ///
    coef ///
    se ///
    pvalue ///
    fdr_p ///
    ci_low ///
    ci_high ///
    N ///
    clusters ///
    r2 ///
    stars ///
    coef_se ///
    using ///
    "$output_dir/alternative_AI_exposure_robustness_results.xlsx", ///
    firstrow(variables) replace


********************************************************************************
* 22. OPTIONAL: CREATE WIDE TABLE FOR PAPER
********************************************************************************

preserve

keep ///
    exposure_id ///
    exposure_label ///
    method ///
    method_label ///
    coef_se ///
    pvalue ///
    fdr_p ///
    N

reshape wide ///
    coef_se pvalue fdr_p N, ///
    i(method method_label) ///
    j(exposure_id)

order ///
    method ///
    method_label ///
    coef_se1 ///
    coef_se2 ///
    coef_se3 ///
    coef_se4

export excel using ///
    "$output_dir/alternative_AI_exposure_publication_table.xlsx", ///
    firstrow(variables) replace

restore


********************************************************************************
* 23. FINAL CHECK
********************************************************************************

display as result ""
display as result "======================================================="
display as result " Finished successfully."
display as result ""
display as result " Output folder:"
display as result "$output_dir"
display as result ""
display as result " Main files:"
display as result " 1. alternative_AI_exposure_robustness_results.dta"
display as result " 2. alternative_AI_exposure_robustness_results.xlsx"
display as result " 3. alternative_AI_exposure_publication_table.xlsx"
display as result "======================================================="
