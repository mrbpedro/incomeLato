# =============================================================================
# income_lato.R
# Wrapper de conveniencia -- combina prepare_latinobarometro_income_inputs()
# e predict_latinobarometro_income() num unico passo, para o caso de uso
# mais comum (ler uma onda ou um diretorio de ondas e sair direto com as
# probabilidades), e resume a execucao numa message() final.
# Usuarios que precisam inspecionar/filtrar o banco harmonizado antes de
# prever devem usar as duas funcoes separadamente.
# =============================================================================

#' Apply the v1.5 income model to Latinobarometro microdata (shortcut)
#'
#' Combines [prepare_latinobarometro_income_inputs()] and
#' [predict_latinobarometro_income()] in a single step. Equivalent to:
#' `predict_latinobarometro_income(prepare_latinobarometro_income_inputs(raw_dir, years, countries), model_version, include_2024)`,
#' plus a run summary emitted with `message()` at the end: waves detected,
#' waves excluded by default (2024), waves skipped because they could not be
#' read, and countries with no prediction at all, with the reason.
#'
#' The package does NOT distribute Latinobarometro microdata -- `raw_dir`
#' must point to files the user downloaded from the official source
#' (latinobarometro.org).
#'
#' @param raw_dir path to one wave's `.dta`/`.sav` file, or to a directory
#'   with one file per wave (downloaded by the user -- not distributed with
#'   the package).
#' @param years vector of years to process (default: every file found; see
#'   [educ3_validated_years()] for the years with validated education
#'   harmonization). For a single file without the year in its name, give
#'   the year here.
#' @param countries vector of ISO3 codes to filter on (default: every
#'   country present in the file).
#' @param model_version model version to apply (the only one available in
#'   this v0.1: `"v1_5"`, the frozen model).
#' @param include_2024 if `FALSE` (default), drops the 2024 wave from the
#'   result -- that wave's education codes were inferred from the historical
#'   order, not confirmed by labels (the 2024 `.dta` is only read by
#'   readstata13, without value labels). If `TRUE`, keeps 2024 with an
#'   additional warning explaining the specific reason for the reduced
#'   confidence.
#'
#' @return data.frame: the harmonized data with `prob_bottom50`,
#'   `prob_middle40`, `prob_top10`, `elegivel`, `motivo_exclusao` and the
#'   per-country confidence flags APPENDED (not a separate object matched
#'   by position). The probabilities are continuous weights for describing
#'   the composition of groups (e.g., party support among the bottom 50%),
#'   within a wave and across waves. Do not classify individual respondents
#'   by a hard cutoff, and do not read `mean(prob_bottom50)` by country-wave
#'   as the size of the bottom half, nor its change over time as a trend
#'   (the aggregate margin drifts for reasons internal to the model; see
#'   `veredito_deriva_temporal` and `flag_margin`). A warning with this
#'   notice is issued on the first call of the session; see also
#'   `attr(result, "recommended_use")` / `attr(result, "prohibited_use")`.
#'   `motivo_exclusao` codes: `venezuela_architectural_quarantine`,
#'   `country_not_in_15`, `outside_country_valid_window`,
#'   `missing_or_invalid_predictor`.
#'
#' @examples
#' # One wave, single file. 100% synthetic data written as a temporary
#' # .dta -- no real Latinobarometro respondent.
#' sim <- simulate_latinobarometro_wave(2011, n = 20)
#' arquivo <- file.path(tempdir(), "Latinobarometro_2011_sim.dta")
#' haven::write_dta(sim, arquivo)
#' res <- income_lato(arquivo)
#' head(res[, c("iso3", "prob_bottom50", "motivo_exclusao")])
#' unlink(arquivo)
#'
#' \dontrun{
#' # real use, with microdata downloaded by the user:
#' res2018 <- income_lato("~/downloads/Latinobarometro_2018_Eng_Stata_v20190303.dta")
#' todas <- income_lato("~/downloads/latinobarometro_dtas")
#' }
#' @export
income_lato <- function(raw_dir, years = NULL, countries = NULL, model_version = "v1_5", include_2024 = FALSE) {
  banco <- prepare_latinobarometro_income_inputs(raw_dir, years = years, countries = countries)
  res <- predict_latinobarometro_income(banco, model_version = model_version, include_2024 = include_2024)
  message(.resumo_execucao(banco, res, include_2024))
  res
}

#' @keywords internal
.resumo_execucao <- function(banco, res, include_2024) {
  detectadas <- attr(banco, "ondas_detectadas")
  ignoradas <- attr(banco, "ondas_ignoradas")
  excluidas_2024 <- if (!include_2024 && 2024 %in% banco$year) 2024 else integer(0)

  linhas <- c(
    "incomeLato -- run summary",
    paste0("  waves detected: ", if (length(detectadas)) paste(detectadas, collapse = ", ") else "none"),
    paste0("  waves excluded by default: ",
           if (length(excluidas_2024)) "2024 (use include_2024 = TRUE to include it)" else "none"),
    if (length(ignoradas)) paste0("  waves skipped (could not be read): ", paste(ignoradas, collapse = ", ")),
    paste0("  respondents with a prediction: ", sum(!is.na(res$prob_bottom50)), " of ", nrow(res))
  )

  com_pred <- tapply(!is.na(res$prob_bottom50), res$iso3, any)
  sem_pred <- names(com_pred)[!com_pred]
  if (length(sem_pred)) {
    motivos <- vapply(sem_pred, function(p) {
      m <- table(res$motivo_exclusao[res$iso3 %in% p])
      paste(names(m), collapse = " / ")
    }, character(1))
    linhas <- c(linhas, "  countries with no prediction:", paste0("    ", sem_pred, ": ", motivos))
  } else {
    linhas <- c(linhas, "  countries with no prediction: none")
  }
  paste(linhas, collapse = "\n")
}
