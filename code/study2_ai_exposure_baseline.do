clear all
set more off
set maxvar 32767

********************************************************************************
* AI exposure and social-science method structure: 72 panel regressions
*
* Model 1: subfield fixed effects + year fixed effects
* Model 2: subfield fixed effects + year fixed effects
*          + subfield-specific linear trends
*
* Standard errors: clustered by subfield
* Outcomes: C F H N Q T method shares
* Exposures: IV5 and IV6, lagged 1-3 years
*
* This version:
* 1. Uses manually generated lagged variables.
* 2. Does not use Stata's L. time-series operators.
* 3. Does not use the unsupported encoding() option.
********************************************************************************


* ==============================================================================
* 1. File paths
* ==============================================================================

* Run this do-file from the repository root.
local project_dir "."

cd "`project_dir'"

local input_file ///
    "`project_dir'/data/study2_subfield_year_panel.xlsx"

capture mkdir "`project_dir'/outputs"
local output_dir "`project_dir'/outputs/study2_baseline"
capture mkdir "`output_dir'"

capture confirm file "`input_file'"

if _rc {
    display as error "Input workbook not found:"
    display as error "`input_file'"
    display as error "Please place the workbook at data/study2_subfield_year_panel.xlsx."
    exit 601
}


* ==============================================================================
* 2. Import panel data
* ==============================================================================

import excel using "`input_file'", ///
    sheet("Panel_method_wide") firstrow clear


* Verify all required variables

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
    ai_method_keyword_exposure ///
    ai_method_topic_keyword_exposure ///
    log1p_paper_count ///
    paper_count_growth_rate ///
    avg_team_size ///
    topic_entropy_normalized ///
    cross_field_topic_share

foreach variable of local required_vars {

    capture confirm variable `variable'

    if _rc {
        display as error "Required variable not found: `variable'"
        exit 111
    }
}


* ==============================================================================
* 3. Construct numeric panel identifier
* ==============================================================================

capture confirm numeric variable subfield_id

if _rc {
    encode subfield_id, generate(panel_id)
}
else {
    generate long panel_id = subfield_id
}

label variable panel_id "Numeric subfield panel identifier"


* ==============================================================================
* 4. Remove partial years
* ==============================================================================

capture confirm numeric variable is_partial_year

if !_rc {
    drop if is_partial_year == 1
}
else {
    drop if inlist(lower(strtrim(is_partial_year)), "true", "yes", "1")
}


* Confirm that year is numeric

capture confirm numeric variable year

if _rc {
    display as error "The year variable is not numeric."
    exit 109
}


* Confirm that regression variables are numeric

local numeric_vars ///
    method_share_C ///
    method_share_F ///
    method_share_H ///
    method_share_N ///
    method_share_Q ///
    method_share_T ///
    ai_method_keyword_exposure ///
    ai_method_topic_keyword_exposure ///
    log1p_paper_count ///
    paper_count_growth_rate ///
    avg_team_size ///
    topic_entropy_normalized ///
    cross_field_topic_share

foreach variable of local numeric_vars {

    capture confirm numeric variable `variable'

    if _rc {
        display as error "Regression variable is not numeric: `variable'"
        exit 109
    }
}


* Confirm one observation per subfield-year

isid panel_id year, sort

sort panel_id year


* ==============================================================================
* 5. Manually construct lagged exposure variables
* ==============================================================================

* ------------------------------------------------------------------------------
* IV5: AI method keyword exposure
* ------------------------------------------------------------------------------

by panel_id (year): generate double iv5_lag1 = ///
    ai_method_keyword_exposure[_n-1] ///
    if _n > 1 & year == year[_n-1] + 1

by panel_id (year): generate double iv5_lag2 = ///
    ai_method_keyword_exposure[_n-2] ///
    if _n > 2 & year == year[_n-2] + 2

by panel_id (year): generate double iv5_lag3 = ///
    ai_method_keyword_exposure[_n-3] ///
    if _n > 3 & year == year[_n-3] + 3


* ------------------------------------------------------------------------------
* IV6: AI method-topic keyword exposure
* ------------------------------------------------------------------------------

by panel_id (year): generate double iv6_lag1 = ///
    ai_method_topic_keyword_exposure[_n-1] ///
    if _n > 1 & year == year[_n-1] + 1

by panel_id (year): generate double iv6_lag2 = ///
    ai_method_topic_keyword_exposure[_n-2] ///
    if _n > 2 & year == year[_n-2] + 2

by panel_id (year): generate double iv6_lag3 = ///
    ai_method_topic_keyword_exposure[_n-3] ///
    if _n > 3 & year == year[_n-3] + 3


label variable iv5_lag1 "IV5 lagged 1 year"
label variable iv5_lag2 "IV5 lagged 2 years"
label variable iv5_lag3 "IV5 lagged 3 years"

label variable iv6_lag1 "IV6 lagged 1 year"
label variable iv6_lag2 "IV6 lagged 2 years"
label variable iv6_lag3 "IV6 lagged 3 years"


* ==============================================================================
* 6. Manually construct one-year-lagged control variables
* ==============================================================================

by panel_id (year): generate double control_log_papers_l1 = ///
    log1p_paper_count[_n-1] ///
    if _n > 1 & year == year[_n-1] + 1

by panel_id (year): generate double control_growth_l1 = ///
    paper_count_growth_rate[_n-1] ///
    if _n > 1 & year == year[_n-1] + 1

by panel_id (year): generate double control_team_size_l1 = ///
    avg_team_size[_n-1] ///
    if _n > 1 & year == year[_n-1] + 1

by panel_id (year): generate double control_entropy_l1 = ///
    topic_entropy_normalized[_n-1] ///
    if _n > 1 & year == year[_n-1] + 1

by panel_id (year): generate double control_cross_field_l1 = ///
    cross_field_topic_share[_n-1] ///
    if _n > 1 & year == year[_n-1] + 1


label variable control_log_papers_l1 ///
    "Log paper count lagged 1 year"

label variable control_growth_l1 ///
    "Paper count growth rate lagged 1 year"

label variable control_team_size_l1 ///
    "Average team size lagged 1 year"

label variable control_entropy_l1 ///
    "Normalised topic entropy lagged 1 year"

label variable control_cross_field_l1 ///
    "Cross-field topic share lagged 1 year"


local lagged_controls ///
    control_log_papers_l1 ///
    control_growth_l1 ///
    control_team_size_l1 ///
    control_entropy_l1 ///
    control_cross_field_l1


* ==============================================================================
* 7. Inspect and save panel data with manually constructed lags
* ==============================================================================

summarize ///
    iv5_lag1 ///
    iv5_lag2 ///
    iv5_lag3 ///
    iv6_lag1 ///
    iv6_lag2 ///
    iv6_lag3 ///
    `lagged_controls'

save ///
    "`output_dir'/ai_exposure_panel_with_manual_lags.dta", ///
    replace


* ==============================================================================
* 8. Prepare result storage
* ==============================================================================

local methods C F H N Q T

tempname result_handle

postfile `result_handle' ///
    str32 model ///
    str1 method ///
    byte iv_number ///
    str45 iv ///
    byte lag ///
    double coef ///
    double se ///
    double t_stat ///
    double p_value ///
    double ci_low ///
    double ci_high ///
    long n_obs ///
    int n_clusters ///
    double r2 ///
    using "`output_dir'/ai_exposure_72_model_results.dta", ///
    replace


* ==============================================================================
* 9. Estimate all 72 panel regressions
* ==============================================================================

* Number of regressions:
*
* 2 model specifications
* x 6 method outcomes
* x 2 AI exposure measures
* x 3 lag lengths
* = 72 regressions


forvalues model_type = 1/2 {

    * --------------------------------------------------------------------------
    * Select model specification
    * --------------------------------------------------------------------------

    if `model_type' == 1 {

        local model_name "baseline_twfe"

        local fixed_effects ///
            i.panel_id ///
            i.year
    }
    else {

        local model_name "twfe_subfield_linear_trends"

        local fixed_effects ///
            i.panel_id ///
            i.year ///
            i.panel_id#c.year
    }


    * --------------------------------------------------------------------------
    * Loop over six method-share outcomes
    * --------------------------------------------------------------------------

    foreach method of local methods {

        local outcome method_share_`method'


        * ----------------------------------------------------------------------
        * Loop over IV5 and IV6
        * ----------------------------------------------------------------------

        forvalues iv_number = 5/6 {

            if `iv_number' == 5 {

                local exposure_name ///
                    "ai_method_keyword_exposure"
            }
            else {

                local exposure_name ///
                    "ai_method_topic_keyword_exposure"
            }


            * ------------------------------------------------------------------
            * Loop over exposure lags 1-3
            * ------------------------------------------------------------------

            forvalues lag = 1/3 {

                local focal iv`iv_number'_lag`lag'


                quietly regress `outcome' ///
                    `focal' ///
                    `lagged_controls' ///
                    `fixed_effects', ///
                    vce(cluster panel_id)


                scalar focal_coef = _b[`focal']

                scalar focal_se = _se[`focal']

                scalar focal_t = focal_coef / focal_se

                scalar focal_p = ///
                    2 * ttail(e(df_r), abs(focal_t))

                scalar critical = ///
                    invttail(e(df_r), 0.025)

                scalar focal_low = ///
                    focal_coef - critical * focal_se

                scalar focal_high = ///
                    focal_coef + critical * focal_se


                post `result_handle' ///
                    ("`model_name'") ///
                    ("`method'") ///
                    (`iv_number') ///
                    ("`exposure_name'") ///
                    (`lag') ///
                    (focal_coef) ///
                    (focal_se) ///
                    (focal_t) ///
                    (focal_p) ///
                    (focal_low) ///
                    (focal_high) ///
                    (e(N)) ///
                    (e(N_clust)) ///
                    (e(r2))
            }
        }
    }
}


postclose `result_handle'


* ==============================================================================
* 10. Open and format the 72-model results
* ==============================================================================

use ///
    "`output_dir'/ai_exposure_72_model_results.dta", ///
    clear


* Construct statistical significance markers

generate str3 significance = ""

replace significance = "***" if p_value < 0.01

replace significance = "**" ///
    if p_value >= 0.01 & p_value < 0.05

replace significance = "*" ///
    if p_value >= 0.05 & p_value < 0.10


* Construct publication-style coefficient and standard-error string

generate str30 coef_se = ///
    string(coef, "%9.4f") + significance + ///
    " (" + string(se, "%9.4f") + ")"


* Construct significance indicators

generate byte significant_10pct = p_value < 0.10

generate byte significant_05pct = p_value < 0.05

generate byte significant_01pct = p_value < 0.01


* Variable labels

label variable model ///
    "Model specification"

label variable method ///
    "Method outcome"

label variable iv_number ///
    "Exposure number"

label variable iv ///
    "Exposure variable"

label variable lag ///
    "Lag length"

label variable coef ///
    "Coefficient"

label variable se ///
    "Clustered standard error"

label variable t_stat ///
    "t statistic"

label variable p_value ///
    "p value"

label variable ci_low ///
    "95% CI lower bound"

label variable ci_high ///
    "95% CI upper bound"

label variable n_obs ///
    "Number of observations"

label variable n_clusters ///
    "Number of subfield clusters"

label variable r2 ///
    "R-squared"

label variable significance ///
    "Significance"

label variable coef_se ///
    "Coefficient and standard error"

label variable significant_10pct ///
    "Significant at 10 percent"

label variable significant_05pct ///
    "Significant at 5 percent"

label variable significant_01pct ///
    "Significant at 1 percent"


* Reorder and sort results

order ///
    model ///
    method ///
    iv_number ///
    iv ///
    lag ///
    coef ///
    se ///
    t_stat ///
    p_value ///
    ci_low ///
    ci_high ///
    n_obs ///
    n_clusters ///
    r2 ///
    significance ///
    coef_se ///
    significant_10pct ///
    significant_05pct ///
    significant_01pct

sort model method iv_number lag


* ==============================================================================
* 11. Verify the number of models
* ==============================================================================

count

if r(N) != 72 {

    display as error ///
        "Warning: expected 72 results, but obtained " r(N)
}
else {

    display as result ///
        "Success: all 72 model results were generated."
}


* ==============================================================================
* 12. Display basic result summaries
* ==============================================================================

tabulate model

tabulate method

tabulate iv_number

tabulate lag


* Statistical significance summaries

tabulate model significant_05pct, row

tabulate method significant_05pct, row

tabulate iv_number significant_05pct, row

tabulate lag significant_05pct, row


* Display the first 20 results

list ///
    model ///
    method ///
    iv_number ///
    lag ///
    coef ///
    se ///
    p_value ///
    significance ///
    n_obs ///
    in 1/20, ///
    noobs abbreviate(24)


* ==============================================================================
* 13. Save final results
* ==============================================================================

save ///
    "`output_dir'/ai_exposure_72_model_results.dta", ///
    replace


* Export CSV without encoding(), for compatibility with older Stata versions

export delimited using ///
    "`output_dir'/ai_exposure_72_model_results.csv", ///
    replace


* Export Excel results

export excel using ///
    "`output_dir'/ai_exposure_72_model_results.xlsx", ///
    firstrow(varlabels) replace


* ==============================================================================
* 14. Completion message
* ==============================================================================

display as result ///
    "All analyses have been completed."

display as result ///
    "Results folder: `output_dir'"

display as result ///
    "Main result file: ai_exposure_72_model_results.xlsx"

display as result ///
    "Panel data with lags: ai_exposure_panel_with_manual_lags.dta"
