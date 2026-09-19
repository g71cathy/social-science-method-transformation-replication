********************************************************************************
* RQ3 final replication code
* Unit: country x subfield x year
* Main outcomes: global Top-10% and Top-20% output shares
* Supplemental outcomes: within-country Top-10% and Top-20% high-impact rates
********************************************************************************

version 17.0
clear all
set more off

* Run this file from the repository root. If the CSV is absent, first run:
* python scripts/decompress_study3_data.py
global input "data/study3_country_subfield_year_panel.csv"
global out   "outputs/study3"
capture mkdir "outputs"
capture mkdir "$out"

capture confirm file "$input"
if _rc {
    display as error "Input file not found: $input"
    display as error "Run: python scripts/decompress_study3_data.py"
    exit 601
}

capture which reghdfe
if _rc {
    ssc install ftools, replace
    ssc install reghdfe, replace
}
capture which require
if _rc ssc install require, replace
capture which esttab
if _rc ssc install estout, replace

********************************************************************************
* 1. Import and panel setup
********************************************************************************

import delimited using "$input", varnames(1) encoding(utf8) clear
drop if missing(country_code) | lower(trim(country_code)) == "nan"
keep if inrange(year, 1990, 2025)
isid country_code subfield_id year

egen country_id       = group(country_code), label
egen entity_id        = group(country_code subfield_id), label
egen country_year_id  = group(country_code year), label
egen subfield_year_id = group(subfield_id year), label
xtset entity_id year

global CMAIN "c_method_share"
global X4 "log_paper_count paper_count_growth_rate mean_team_size intl_collaboration_share"
global X5 "$X4 cross_field_topic_share"
global XEXP "$X5 mean_references english_paper_share open_access_share"

forvalues h = 1/3 {
    generate g10_h`h' = F`h'.global_top10_output_share
    generate g20_h`h' = F`h'.global_top20_output_share
    generate r10_h`h' = F`h'.top10_high_impact_rate
    generate r20_h`h' = F`h'.top20_high_impact_rate
    generate papers_h`h' = F`h'.paper_count_fractional
}
generate global_output_h1 = F1.global_output_share

********************************************************************************
* Utility: winsorize growth within the current estimation sample
********************************************************************************

capture program drop winsor_growth
program define winsor_growth
    quietly summarize paper_count_growth_rate, detail
    local p1 = r(p1)
    local p99 = r(p99)
    replace paper_count_growth_rate = `p1'  if paper_count_growth_rate < `p1'
    replace paper_count_growth_rate = `p99' if paper_count_growth_rate > `p99'
end

capture program drop drop_missing
program define drop_missing
    syntax varlist
    tempvar nmiss
    egen `nmiss' = rowmiss(`varlist')
    drop if `nmiss' > 0
end

********************************************************************************
* 2. Table 4: model sequence for global Top-10% share at t+1
********************************************************************************

estimates clear

preserve
    keep if paper_count_fractional >= 20 & papers_h1 >= 20
    drop if missing(g10_h1, $CMAIN)
    quietly reghdfe g10_h1 $CMAIN, ///
        absorb(entity_id country_year_id subfield_year_id) ///
        vce(cluster country_id subfield_id)
    estadd scalar effect_10pp = _b[$CMAIN] * 10
    estimates store table4_nocontrols
restore

preserve
    keep if paper_count_fractional >= 20 & papers_h1 >= 20
    drop_missing g10_h1 $CMAIN $X4
    winsor_growth
    quietly reghdfe g10_h1 $CMAIN $X4, ///
        absorb(entity_id country_year_id subfield_year_id) ///
        vce(cluster country_id subfield_id)
    estadd scalar effect_10pp = _b[$CMAIN] * 10
    estimates store table4_fourcontrols
restore

preserve
    keep if paper_count_fractional >= 20 & papers_h1 >= 20
    drop_missing g10_h1 $CMAIN $X5
    winsor_growth
    quietly reghdfe g10_h1 $CMAIN $X5, ///
        absorb(entity_id country_year_id subfield_year_id) ///
        vce(cluster country_id subfield_id)
    estadd scalar effect_10pp = _b[$CMAIN] * 10
    estimates store table4_main
restore

preserve
    keep if paper_count_fractional >= 20 & papers_h1 >= 20
    drop_missing g10_h1 $CMAIN $XEXP
    winsor_growth
    quietly reghdfe g10_h1 $CMAIN $XEXP, ///
        absorb(entity_id country_year_id subfield_year_id) ///
        vce(cluster country_id subfield_id)
    estadd scalar effect_10pp = _b[$CMAIN] * 10
    estimates store table4_expanded
restore

esttab table4_nocontrols table4_fourcontrols table4_main table4_expanded ///
    using "$out/Table4_model_sequence.csv", replace csv ///
    keep($CMAIN) cells("b(fmt(6) star) se(fmt(6)) p(fmt(6))") ///
    stats(effect_10pp N r2_within, fmt(%9.4f %12.0fc %9.4f)) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("No controls" "Four controls" "Main five controls" "Expanded controls")

********************************************************************************
* 3. Table 5: descriptive statistics in the t+1 main-model sample
********************************************************************************

preserve
    keep if paper_count_fractional >= 20 & papers_h1 >= 20
    drop_missing g10_h1 $CMAIN $X5
    quietly reghdfe g10_h1 $CMAIN $X5, ///
        absorb(entity_id country_year_id subfield_year_id) ///
        vce(cluster country_id subfield_id)
    keep if e(sample)
    winsor_growth

    generate pct_g10 = 100 * g10_h1
    generate pct_g20 = 100 * g20_h1
    generate pct_r10 = 100 * r10_h1
    generate pct_r20 = 100 * r20_h1
    generate pct_c = 100 * $CMAIN
    generate pct_growth = 100 * paper_count_growth_rate
    generate pct_international = 100 * intl_collaboration_share
    generate pct_cross_field = 100 * cross_field_topic_share

    estpost summarize pct_g10 pct_g20 pct_r10 pct_r20 pct_c ///
        log_paper_count pct_growth mean_team_size ///
        pct_international pct_cross_field
    esttab using "$out/Table5_descriptive_statistics.csv", replace csv ///
        cells("count(fmt(0)) mean(fmt(1)) sd(fmt(1)) min(fmt(1)) max(fmt(1))") ///
        nonumber nomtitle noobs
restore

********************************************************************************
* 4. Tables 6 and 7: four outcomes over one- to three-year horizons
********************************************************************************

local rate_models ""
local global_models ""

foreach outcome in r10 r20 g10 g20 {
    forvalues h = 1/3 {
        preserve
            keep if paper_count_fractional >= 20 & papers_h`h' >= 20
            drop_missing `outcome'_h`h' $CMAIN $X5
            winsor_growth
            quietly reghdfe `outcome'_h`h' $CMAIN $X5, ///
                absorb(entity_id country_year_id subfield_year_id) ///
                vce(cluster country_id subfield_id)
            estadd scalar effect_10pp = _b[$CMAIN] * 10
            estimates store main_`outcome'_h`h'
        restore
        if inlist("`outcome'", "r10", "r20") ///
            local rate_models "`rate_models' main_`outcome'_h`h'"
        if inlist("`outcome'", "g10", "g20") ///
            local global_models "`global_models' main_`outcome'_h`h'"
    }
}

esttab `rate_models' using "$out/Table6_within_country_rates.csv", replace csv ///
    keep($CMAIN) cells("b(fmt(6) star) se(fmt(6)) p(fmt(6))") ///
    stats(effect_10pp N r2_within, fmt(%9.4f %12.0fc %9.4f)) ///
    star(* 0.10 ** 0.05 *** 0.01)

esttab `global_models' using "$out/Table7_global_output_shares.csv", replace csv ///
    keep($CMAIN) cells("b(fmt(6) star) se(fmt(6)) p(fmt(6))") ///
    stats(effect_10pp N r2_within, fmt(%9.4f %12.0fc %9.4f)) ///
    star(* 0.10 ** 0.05 *** 0.01)

********************************************************************************
* 5. Table 8: four measures of computational-method penetration
********************************************************************************

local cvars "c_method_share c_paper_rate_classified c_paper_rate_all c_share_fractional_labels"
local alt_models ""
local i = 0
foreach cvar of local cvars {
    local ++i
    foreach outcome in g10 g20 {
        preserve
            keep if paper_count_fractional >= 20 & papers_h1 >= 20
            drop_missing `outcome'_h1 `cvar' $X5
            winsor_growth
            quietly reghdfe `outcome'_h1 `cvar' $X5, ///
                absorb(entity_id country_year_id subfield_year_id) ///
                vce(cluster country_id subfield_id)
            estadd scalar effect_10pp = _b[`cvar'] * 10
            estimates store alt`i'_`outcome'
            local alt_models "`alt_models' alt`i'_`outcome'"
        restore
    }
}

esttab `alt_models' using "$out/Table8_alternative_C_measures.csv", replace csv ///
    keep(c_method_share c_paper_rate_classified c_paper_rate_all c_share_fractional_labels) ///
    cells("b(fmt(6) star) se(fmt(6)) p(fmt(6))") ///
    stats(effect_10pp N r2_within, fmt(%9.4f %12.0fc %9.4f)) ///
    star(* 0.10 ** 0.05 *** 0.01)

********************************************************************************
* 6. Table 9: specification and sample robustness at t+1
********************************************************************************

local table9_models ""
foreach threshold in 10 20 {
    local future_y "g`threshold'_h1"
    local current_y "global_top`threshold'_output_share"

    preserve
        keep if paper_count_fractional >= 20 & papers_h1 >= 20
        drop_missing `future_y' $CMAIN $X5
        winsor_growth
        quietly reghdfe `future_y' $CMAIN $X5, ///
            absorb(entity_id country_year_id subfield_year_id) ///
            vce(cluster country_id subfield_id)
        estadd scalar effect_10pp = _b[$CMAIN] * 10
        estimates store t9_`threshold'_main
    restore

    preserve
        keep if paper_count_fractional >= 20 & papers_h1 >= 20 & year + 1 <= 2022
        drop_missing `future_y' $CMAIN $X5
        winsor_growth
        quietly reghdfe `future_y' $CMAIN $X5, ///
            absorb(entity_id country_year_id subfield_year_id) ///
            vce(cluster country_id subfield_id)
        estadd scalar effect_10pp = _b[$CMAIN] * 10
        estimates store t9_`threshold'_through2022
    restore

    preserve
        keep if paper_count_fractional >= 50 & papers_h1 >= 50
        drop_missing `future_y' $CMAIN $X5
        winsor_growth
        quietly reghdfe `future_y' $CMAIN $X5, ///
            absorb(entity_id country_year_id subfield_year_id) ///
            vce(cluster country_id subfield_id)
        estadd scalar effect_10pp = _b[$CMAIN] * 10
        estimates store t9_`threshold'_ge50
    restore

    preserve
        keep if paper_count_fractional >= 20 & papers_h1 >= 20
        drop_missing `future_y' `current_y' $CMAIN $X5
        winsor_growth
        quietly reghdfe `future_y' $CMAIN `current_y' $X5, ///
            absorb(entity_id country_year_id subfield_year_id) ///
            vce(cluster country_id subfield_id)
        estadd scalar effect_10pp = _b[$CMAIN] * 10
        estimates store t9_`threshold'_lagged_y
    restore

    preserve
        keep if paper_count_fractional >= 20 & papers_h1 >= 20
        drop_missing `future_y' global_output_share $CMAIN $X5
        winsor_growth
        quietly reghdfe `future_y' $CMAIN global_output_share $X5, ///
            absorb(entity_id country_year_id subfield_year_id) ///
            vce(cluster country_id subfield_id)
        estadd scalar effect_10pp = _b[$CMAIN] * 10
        estimates store t9_`threshold'_baseline_output
    restore

    preserve
        keep if paper_count_fractional >= 20 & papers_h1 >= 20
        drop_missing `future_y' global_output_h1 $CMAIN $X5
        winsor_growth
        quietly reghdfe `future_y' $CMAIN global_output_h1 $X5, ///
            absorb(entity_id country_year_id subfield_year_id) ///
            vce(cluster country_id subfield_id)
        estadd scalar effect_10pp = _b[$CMAIN] * 10
        estimates store t9_`threshold'_future_output
    restore

    preserve
        keep if paper_count_fractional >= 20 & papers_h1 >= 20
        drop_missing `future_y' $CMAIN $X5
        winsor_growth
        quietly reghdfe `future_y' $CMAIN $X5, ///
            absorb(entity_id subfield_year_id entity_id#c.year) ///
            vce(cluster country_id subfield_id)
        estadd scalar effect_10pp = _b[$CMAIN] * 10
        estimates store t9_`threshold'_unit_trends
    restore

    local table9_models "`table9_models' t9_`threshold'_main t9_`threshold'_through2022 t9_`threshold'_ge50 t9_`threshold'_lagged_y t9_`threshold'_baseline_output t9_`threshold'_future_output t9_`threshold'_unit_trends"
}

esttab `table9_models' using "$out/Table9_robustness.csv", replace csv ///
    keep($CMAIN) cells("b(fmt(6) star) se(fmt(6)) p(fmt(6))") ///
    stats(effect_10pp N r2_within, fmt(%9.4f %12.0fc %9.4f)) ///
    star(* 0.10 ** 0.05 *** 0.01)

********************************************************************************
* 7. Save prepared Stata panel
********************************************************************************

compress
save "$out/RQ3_country_subfield_year_panel.dta", replace
display as result "RQ3 replication complete. Outputs saved in $out"
