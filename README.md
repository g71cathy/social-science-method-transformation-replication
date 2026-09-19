# Social Science Method Transformation: Replication Materials

This repository contains the data, Stata code, and classification prompts used to reproduce two panel analyses of methodological change in the social sciences.

## Analyses

### Study 2: AI exposure and methodological transformation

The analysis uses a subfield-by-year panel to estimate whether lagged exposure to AI knowledge is associated with subsequent changes in the relative shares of six method categories:

- `C`: computational social science
- `F`: formal modelling
- `H`: historical or interpretive approaches
- `N`: traditional quantitative methods
- `Q`: qualitative empirical approaches
- `T`: theoretical or normative scholarship

The baseline code estimates subfield and year fixed-effects models, with subfield-clustered standard errors. The robustness code replaces the main exposure measure with alternative indicators of AI knowledge exposure.

### Study 3: Computational-method penetration and scientific visibility

The analysis uses a country-by-subfield-by-year panel. It relates lagged computational-method penetration to subsequent scientific visibility, measured primarily by the share of a unit's fractionally weighted papers that enter the global top 10% of the citation distribution within the same subfield and year. The models absorb country-by-subfield, country-by-year, and subfield-by-year fixed effects and use two-way clustered standard errors.

## Repository structure

```text
.
├── code/
│   ├── study2_ai_exposure_baseline.do
│   ├── study2_ai_exposure_robustness.do
│   └── study3_scientific_visibility_analysis.do
├── data/
│   ├── study2_subfield_year_panel.xlsx
│   └── study3_country_subfield_year_panel.csv.gz
├── prompts/
│   ├── method_classification_stage1.md
│   └── method_classification_arbitration.md
├── scripts/
│   └── decompress_study3_data.py
└── outputs/
```

## Software

- Stata 17 or later
- Python 3 (only needed to decompress the Study 3 dataset)
- Stata packages `reghdfe`, `ftools`, and `estout`; the Study 3 script installs missing packages automatically

## Reproducing Study 2

Start Stata in the repository root and run:

```stata
do code/study2_ai_exposure_baseline.do
do code/study2_ai_exposure_robustness.do
```

Results are written to `outputs/study2_baseline/` and `outputs/study2_robustness/`.

## Reproducing Study 3

The Study 3 CSV is distributed as a gzip archive to remain within GitHub's standard file-size limit. From the repository root, first run:

```bash
python scripts/decompress_study3_data.py
```

Then run in Stata:

```stata
do code/study3_scientific_visibility_analysis.do
```

Results are written to `outputs/study3/`. The decompressed CSV and generated output files are ignored by Git.

## Classification prompts

The `prompts/` directory contains the initial method-classification prompt and the LLM arbitration prompt. In the classification workflow, 58,717 training labels were assigned by majority vote across three models, with LLM arbitration when no majority was available. The separate 2,000-paper human-coded gold standard is not conflated with the arbitration stage.

## Notes

- The analysis files use repository-relative paths and should be run from the repository root.
- The PNAS manuscript template is intentionally not included because it is a publisher-supplied formatting file rather than a research artifact.
- Generated outputs are excluded so that the repository remains focused on source data, code, and prompts.

## Citation

If you use these materials, please cite the associated article and this repository. Full article citation details can be added after publication.
