# incomeLato

[![DOI](https://zenodo.org/badge/1395470164.svg)](https://doi.org/10.5281/zenodo.23045516)

`incomeLato` estimates where each Latinobarómetro respondent sits in their
country's income distribution: the probability of belonging to the bottom 50%,
the middle 40% and the top 10% of their country in that survey year. It applies
a frozen, already-validated model (v1.5, 15 countries, waves 1995–2024) to
Latinobarómetro microdata that you download yourself.

> Source, issues and documentation site: <https://github.com/mrbpedro/incomeLato>
> · <https://mrbpedro.github.io/incomeLato>.

## How to use

Install:

```r
install.packages("incomeLato",
                 repos = c("https://mrbpedro.r-universe.dev", "https://cloud.r-project.org"))
```

### One wave

Download a wave from the official site (<https://www.latinobarometro.org>,
*Documentación y Datos*), unzip it, and pass the file:

```r
library(incomeLato)
res <- income_lato("~/data/Latinobarometro_2018_Eng_Stata_v20190303.dta")
```

The function ends with a short report:

```
incomeLato -- run summary
  waves detected: 2018
  waves excluded by default: none
  respondents with a prediction: 16901 of 20204
  countries with no prediction:
    DOM: country_not_in_15
    GTM: country_not_in_15
    VEN: venezuela_architectural_quarantine
```

On the real 2018 file this call reproduces the
article's 16,901 predictions for that wave exactly.

If the file name does not contain the year, give it: `income_lato(file,
years = 2018)`.

### Several waves

Put one file per wave (`.dta` or `.sav`) in a folder and pass the folder:

```r
res <- income_lato("~/data/latinobarometro")                    # every wave found
res <- income_lato("~/data/latinobarometro", years = c(2018, 2020))
```

### The output

`res` has one row per respondent in your file(s): the harmonized predictors,
`prob_bottom50`, `prob_middle40`, `prob_top10`, `elegivel` (was the
respondent scored), `motivo_exclusao` (why not) and per-country quality
flags. The other columns of your file are not carried over;
`respondent_row_id` is the row's position in its file, so any variable can be
brought in with `raw$variable[res$respondent_row_id]`, where `raw` is that
wave read with `haven::read_dta()`. To inspect the harmonized predictors
before predicting, run the two steps separately:
`prepare_latinobarometro_income_inputs()`, then
`predict_latinobarometro_income()`.

Respondents from countries outside the 15 get empty probabilities and a
reason, never an error. Venezuela is always excluded (an architectural
quarantine of the model). The codes in `motivo_exclusao` are:

| Code | Meaning |
|---|---|
| `venezuela_architectural_quarantine` | respondent from Venezuela, always excluded |
| `country_not_in_15` | country outside the 15 covered by the model |
| `outside_country_valid_window` | country-wave outside that country's valid window |
| `missing_or_invalid_predictor` | sex, age, education, car or washing machine missing or invalid |

`NA` means the respondent was scored. These codes replaced the Portuguese
ones of v0.1.0 (`venezuela_quarentena_arquitetural`,
`pais_fora_dos_15_ativos`, `fora_da_janela_temporal_valida_do_pais`,
`preditor_ausente_ou_invalido`, in the same order).

## Example: support for democracy by income group

The example uses synthetic data, written to a temporary file and read the
way a downloaded wave would be. `supports_democracy` is **simulated** (1 =
democracy is preferable to any other kind of government), with a probability
that rises with predicted income, so that the table shows a gradient.

```r
library(incomeLato)
sim <- simulate_latinobarometro_wave(2011, n = 200)   # synthetic, no real respondent
arquivo <- file.path(tempdir(), "Latinobarometro_2011_sim.dta")
haven::write_dta(sim, arquivo)

res <- income_lato(arquivo)
res <- res[res$elegivel, ]                            # scored respondents only

# simulated outcome, rising with predicted income
set.seed(1)
p <- 0.40 + 0.25 * res$prob_middle40 + 1.2 * res$prob_top10
res$supports_democracy <- rbinom(nrow(res), 1, pmin(p, 1))

# share supporting democracy in each income group, by country:
# each respondent weighted by prob_<group> times the survey weight
grupos <- c("bottom50", "middle40", "top10")
share <- sapply(grupos, function(g) {
  w <- res[[paste0("prob_", g)]] * res$weight
  tapply(w * res$supports_democracy, res$iso3, sum) / tapply(w, res$iso3, sum)
})
round(100 * share, 1)
```

With real data, the variable comes from the Latinobarómetro's standard
question on preference for democracy. Its name changes between waves, so
look it up in each wave's questionnaire, and bring it into `res` with
`raw$variable[res$respondent_row_id]`.

## Scope and limits: strong in aggregate, weak for individuals

The package was validated against LAPOP, which records household income (the
`q10` family of questions). Within each country-wave, each income bracket is
converted into membership in the bottom 50%, middle 40% and top 10%. The
numbers below apply the packaged recipe (the v1.5 model with the v1.4
recalibrators, Mexico uncalibrated) to 66 country-waves in 15 countries,
2008–2018.

These checks are **in-sample for the recalibrators**, which were fitted on
this same LAPOP data. LAPOP never enters the training of the model itself.

### Calibration: the level of each income group

| Metric | Result |
|---|---|
| Predicted minus observed share of the bottom 50%, per country-wave: median of the absolute difference | 2.3 pp (7.3 pp without recalibration) |
| Countries whose median difference is within ±1 pp | 11 of 15 |
| Countries outside ±2 pp | Ecuador (−2.1), Uruguay (−2.5), Mexico (−2.7, no recalibrator) |
| Spearman between a respondent's predicted probability and their observed income-group membership: bottom 50 / middle 40 / top 10 | 0.44 / 0.25 / 0.35 |

Single country-waves vary more than the medians: the largest difference is
above 2 pp in 14 of the 15 countries, and reaches 11.6 pp in one Ecuadorian
wave. At the level of one respondent, the model is weak.

### In use: the income composition of party support

Here LAPOP vote intention is held fixed and only the income weights change.
Support for each party within each income group is computed twice, once
weighting respondents by their observed income-group membership and once by
the predicted probabilities, and the two are compared. Each comparison is
one country-wave-party (357 comparisons).

| Metric | Result |
|---|---|
| Mean absolute difference in the bottom 50's support share | 0.71 pp |
| Spearman between the two sets of support shares | 0.97 (top 10) to 0.99 (bottom 50, middle 40) |
| Party most supported by the bottom 50% is the same | 97% of 66 country-waves |

These metrics barely move with recalibration: support within a group is a
ratio of weighted sums, so a shift in the level of the weights largely
cancels out. The vignette compares the packaged recipe with the models
without recalibration.

In aggregate, the model reproduces what observed income would give.

So `prob_bottom50`, `prob_middle40` and `prob_top10` are continuous weights
for describing the composition of groups, within a wave and across waves
(through a weighted mean or a weighted regression).

- **Allowed**, including over time: support for party X among the bottom
  50% in each wave, 1995–2023, weighting each respondent by
  `prob_bottom50` times the survey weight.
- **Not allowed**: classifying individual respondents by a hard cutoff
  (`prob_bottom50 > 0.5` → "poor").
- **Not allowed**: reading `mean(prob_bottom50)` by country-wave as the size
  of the bottom half, or its change over time as a trend. The aggregate
  margin drifts for reasons internal to the model; the columns
  `veredito_deriva_temporal` and `flag_margin` give the per-country drift
  verdict.

The magnitude labels in `veredito_deriva_temporal` come from the
leave-one-wave-out validation of an earlier model vintage (v1.1).
`flag_margin` remains a justified caution, because the direction of the
drift persists under the packaged recipe.

The package issues this notice as a warning on first use in each session,
and records it in `attr(res, "recommended_use")` and
`attr(res, "prohibited_use")`.

## Why v1.5 model with v1.4 recalibrators

Each country's probabilities are recalibrated after prediction. The package
ships the combination that the published results actually used: the v1.5
model, the v1.4 recalibrators for 14 countries, and no recalibrator for
Mexico. We tested three combinations against the 369,999 predictions behind
the article:

| Combination | Largest difference in `prob_bottom50` |
|---|---|
| v1.5 model, no recalibration | 0.31 |
| **v1.5 model + v1.4 recalibrators (14 countries), Mexico uncalibrated** | **0** |
| v1.5 model + v1.5 recalibrators (all 15, including Mexico) | 0.093 |

Only the second reproduces the article's predictions, so the package ships
it. The installed package reproduces all 369,999 predictions exactly (maximum
difference 0, correlation 1.0, all 15 countries); the script is in
`data-raw/golden_file_validation_v1_5.R`.

The model file is byte-identical to the one used in the article. It still
carries an internal status field written before the model was promoted
(`release_status = "candidate_manual_review_only"`); the package corrects it
in memory when loading, without altering the file.

## Mexico

Mexico is new in v1.5. It is scored like the other 14 countries, with two
differences: it has no recalibrator (see above), so `flag_margin` is `NA`
(the aggregate margin was never assessed for it); and the waves 1996 and 2024
are not scored. Being in the package does not put Mexico in the electoral
figures of the article, which do not include it.

## Countries and waves

Argentina, Bolivia, Brazil, Chile, Colombia, Costa Rica, Ecuador, El
Salvador, Honduras, Mexico, Nicaragua, Panama, Paraguay, Peru, Uruguay; all
Latinobarómetro waves 1995–2023. A few country-waves are outside a country's
valid window and come back with `motivo_exclusao`.

### The 2024 wave

The 2024 wave is excluded by default. Its education codes were inferred from
the order used in earlier waves, not confirmed by value labels (the file has
none readable). Use `include_2024 = TRUE` (in `income_lato()` or
`predict_latinobarometro_income()`) to score it anyway; a warning repeats
this caveat. Scored this way, the package reproduces the article's 2024
predictions exactly.

### New waves

A new wave (2025 onward) is refused until someone adds it to the two
crosswalks in `inst/extdata/`, checked against the wave's codebook.

## Data

The package contains no data from the Latinobarómetro, LAPOP or the national
household surveys used for training, and nothing computed from their
microdata. It ships model coefficients, recalibration parameters, variable
names per wave, the list of country-waves outside each country's valid
window, a per-country categorical verdict from the article's validation, and
a per-country confidence label for the training sources. Training or re-validating the model requires the microdata, which
you obtain from each source under its own terms.

## Citation

`citation("incomeLato")` gives the citation for the package and a template
for citing the Latinobarómetro waves you use. The package is archived on
Zenodo: DOI [10.5281/zenodo.23045516](https://doi.org/10.5281/zenodo.23045516)
(all versions).

## License

MIT © Pedro Barbosa. The license covers the code; the Latinobarómetro data
you download remain under the terms of Corporación Latinobarómetro.
