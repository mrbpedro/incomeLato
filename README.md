# incomeLato

`incomeLato` estimates where each Latinobarómetro respondent sits in their
country's income distribution: the probability of belonging to the bottom 50%,
the middle 40% and the top 10% of their country in that survey year. It applies
a frozen, already-validated model (v1.5, 15 countries, waves 1995–2024) to
Latinobarómetro microdata that you download yourself.

> Function documentation and console messages are currently in Portuguese.
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
incomeLato -- resumo da execucao
  ondas detectadas: 2018
  ondas excluidas por padrao: nenhuma
  respondentes com predicao: 16901 de 20204
  paises sem predicao:
    DOM: pais_fora_dos_15_ativos
    GTM: pais_fora_dos_15_ativos
    VEN: venezuela_quarentena_arquitetural
```

(waves detected, waves excluded by default, respondents scored, and countries
with no prediction and why). On the real 2018 file this call reproduces the
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

`res` is your data with `prob_bottom50`, `prob_middle40`, `prob_top10`
appended, plus `elegivel` (was the respondent scored), `motivo_exclusao` (why
not) and per-country quality flags. To inspect the harmonized predictors
before predicting, run the two steps separately:
`prepare_latinobarometro_income_inputs()`, then
`predict_latinobarometro_income()`.

Respondents from countries outside the 15 get empty probabilities and a
reason, never an error. Venezuela is always excluded (an architectural
quarantine of the model, reported as `venezuela_quarentena_arquitetural`).

## Scope and limits: strong in aggregate, weak for individuals

The two uses of the probabilities perform very differently, and the package
is built for the first one.

| Use | Validation (against LAPOP) | Result |
|---|---|---|
| **Aggregate**: share of each income group supporting a party, per country-wave | Spearman between predicted and observed shares, per-class validation **under v1.4** | 0.97–0.99 (339 comparisons) |
| **Aggregate**, same metric **under v1.5**, 15 countries | mean absolute error of the bottom-50 support share | 0.670 pp; the most-supported party matches in 97% of 357 comparisons |
| **Individual**: one respondent's probability vs. their observed position | Spearman, per-class validation **under v1.4** | 0.21–0.42 (N = 92,940) |

So: use `prob_bottom50` as a continuous weight in aggregate analysis (for
example, a weighted mean or a weighted regression). Do not classify
individual respondents by thresholding it, and do not read
`mean(prob_bottom50)` per country-wave as the size of the bottom 50% — the
aggregate margin drifts over time for reasons internal to the model. The
package warns about this on first use in each session.

The per-class validation has not yet been redone under v1.5; it is the first
open issue, planned for v0.1.1.

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
for citing the Latinobarómetro waves you use.

## License

MIT © Pedro Barbosa. The license covers the code; the Latinobarómetro data
you download remain under the terms of Corporación Latinobarómetro.
