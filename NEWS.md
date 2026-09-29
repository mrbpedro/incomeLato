# incomeLato 0.1.1

All console messages, warnings and function help are now in English.
Exclusion reason codes renamed (see README). No change to predictions.

* `motivo_exclusao` codes: `venezuela_quarentena_arquitetural` →
  `venezuela_architectural_quarantine`, `pais_fora_dos_15_ativos` →
  `country_not_in_15`, `fora_da_janela_temporal_valida_do_pais` →
  `outside_country_valid_window`, `preditor_ausente_ou_invalido` →
  `missing_or_invalid_predictor`. Code that filters on the old values must
  be updated.
* Result attributes `uso_recomendado` / `uso_proibido` renamed
  `recommended_use` / `prohibited_use`, with English values.
* The usage notice (warning, README, vignette) now separates what is allowed
  from what is not: comparing groups across waves is allowed (e.g. party
  support among the bottom 50% in each wave); reading `mean(prob_bottom50)`
  as the size of the bottom half, or its change as a trend, is not.
* Column names are unchanged, including `veredito_deriva_temporal` and
  `flag_margin`, so existing code keeps working. Moving column names to
  English is left for a future version, with a deprecation warning.
* Validation, description corrected (numbers unchanged). The README and the
  vignette now separate the validation against LAPOP observed income (the
  household income bracket, compared respondent by respondent) from the
  validation in use (party support computed with observed vs. predicted
  income weights). Two descriptions in 0.1.0 were wrong: the 339 v1.4
  comparisons are country-wave-party, not country-wave; and the 97% top-party
  agreement under v1.5 is over 66 country-waves, not over the 357
  country-wave-party comparisons.
* Validation section rewritten around the packaged recipe (script 265 of
  the research project): the v1.5 model with the v1.4 recalibrators, Mexico
  uncalibrated, against LAPOP observed income, 66 country-waves, 2008–2018,
  in-sample for the recalibrators. The numbers cited in 0.1.0 (0.21–0.42,
  0.97–0.99, 0.670 pp, 97%) came from the v1.4 and v1.5 models without
  recalibration; the vignette keeps them in a comparison table, labeled as
  such.
* README and vignette example rewritten: it now goes through
  `income_lato()` on a file and shows support for democracy (simulated) in
  the three income groups by country.
* The README no longer says that `income_lato()` returns "your data": the
  other columns of the input file are not carried over, and
  `respondent_row_id` (the row's position in its file) is the key to bring
  them in.
* Checked against v0.1.0 on the real 2018 wave: 16,901 of 16,901
  predictions identical (maximum difference 0).

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

## Validation

End-to-end check of the installed package against the article's predictions
(`data-raw/golden_file_validation_v1_5.R`, 2026-09-29): 369,999 of 369,999
respondents matched (waves 1995–2024, 15 countries); maximum absolute
difference 0 and correlation 1.0 for all three probabilities in every
country; predictors and weights identical row by row. One deliberate
difference in a flag: `flag_piso_confianca` for Mexico is `FALSE` in the
package and `NA` in the article's file.
