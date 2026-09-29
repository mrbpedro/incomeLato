# incomeLato 0.1.0

First public release.

Archived on Zenodo: DOI 10.5281/zenodo.23045517 (this version);
10.5281/zenodo.23045516 (all versions).

* Applies the frozen income-position model v1.5 (15 countries: Argentina,
  Bolivia, Brazil, Chile, Colombia, Costa Rica, Ecuador, El Salvador,
  Honduras, Mexico, Nicaragua, Panama, Paraguay, Peru, Uruguay) to
  Latinobarómetro waves 1995–2024 supplied by the user, in `.dta` or `.sav`.
* `income_lato()` accepts a single wave file or a folder of waves, and ends
  with a message summarizing waves detected, waves excluded by default,
  respondents scored, and countries with no prediction and why.
* Recalibration: v1.4 recalibrators for 14 countries; Mexico uncalibrated.
  This is the combination behind the published article's predictions.
* The package ships no survey data and nothing computed from survey
  microdata: model parameters, variable-name crosswalks, excluded
  country-waves, and per-country categorical verdicts only.
* The 2024 wave is now readable (codes are read as numbers instead of
  labels); it stays excluded by default because its education codes were
  inferred, not confirmed by labels.

## Known limitations

* The per-class validation (bottom 50 / middle 40 / top 10) cited in the
  README is still the one run under model v1.4; redoing it under v1.5 is
  planned for v0.1.1. The aggregate party-support validation is already
  under v1.5.
* Console messages and function help are in Portuguese; README, NEWS and
  the vignette are in English.

## Validation

End-to-end check of the installed package against the article's predictions
(`data-raw/golden_file_validation_v1_5.R`, 2026-09-29): 369,999 of 369,999
respondents matched (waves 1995–2024, 15 countries); maximum absolute
difference 0 and correlation 1.0 for all three probabilities in every
country; predictors and weights identical row by row. One deliberate
difference in a flag: `flag_piso_confianca` for Mexico is `FALSE` in the
package and `NA` in the article's file.
