# =============================================================================
# harmonize_educ3.R
# Bloco 15, TAREFA 3: harmoniza educ3_final (basic_or_less/secondary/
# higher_or_more) a partir dos dados brutos de uma onda do Latinobarometro.
# Reaproveita a logica de mapeamento (cat7/cat3/years17) e a tabela de
# variavel-por-ano de scripts/54_construir_educ3_final_latinobarometro.R
# -- a fonte de verdade que gerou o educ3_final da v1.4 congelada. NAO usa
# o crosswalk geral "education_r" (aponta para outra variavel em 2020).
#
# GUARD-RAIL CENTRAL: so funciona para anos na tabela de anos VALIDADOS
# (inst/extdata/educ3_validated_years.csv). Para qualquer ano fora dela
# (onda futura, ou onda nao coberta pelo script 54), RECUSA -- nao
# adivinhe esquema nem variavel.
# =============================================================================

#' @keywords internal
.educ3_anos_validados <- function() {
  path <- system.file("extdata", "educ3_validated_years.csv", package = "incomeLato")
  if (!nzchar(path)) {
    path <- file.path(dirname(dirname(sys.frame(1)$ofile %||% ".")), "inst", "extdata", "educ3_validated_years.csv")
  }
  read.csv(path, stringsAsFactors = FALSE)
}

# --- mapeamentos de esquema, identicos ao script 54 ---
.mapear_cat7 <- function(codigo) {
  dplyr::case_when(
    codigo %in% c(1, 2, 3) ~ "basic_or_less",
    codigo %in% c(4, 5)    ~ "secondary",
    codigo %in% c(6, 7)    ~ "higher_or_more",
    TRUE ~ NA_character_
  )
}
.mapear_cat3 <- function(codigo) {
  dplyr::case_when(codigo == 1 ~ "basic_or_less", codigo == 2 ~ "secondary", codigo == 3 ~ "higher_or_more", TRUE ~ NA_character_)
}
.mapear_years17 <- function(codigo) {
  anos <- codigo - 1
  dplyr::case_when(
    codigo %in% 1:13 & anos <= 6 ~ "basic_or_less",
    codigo %in% 1:13 & anos >= 7 ~ "secondary",
    codigo %in% 14:17            ~ "higher_or_more",
    TRUE ~ NA_character_
  )
}

#' Harmonize educ3_final for one Latinobarometro wave
#'
#' Builds the 3-category education variable
#' (basic_or_less/secondary/higher_or_more) used by the income model,
#' using the table of validated years (not the general crosswalk -- see
#' the note in the file header). Years outside the table of validated
#' years are NOT processed -- the function stops with an error and never
#' guesses the scheme/variable for an unseen wave.
#'
#' @param raw_data raw data.frame of one Latinobarometro wave (columns
#'   with the original names of the file downloaded by the user).
#' @param year survey year of the wave (numeric).
#' @param on_unvalidated_year "error" (default, refuses) or "warning"
#'   (issues a strong warning and returns NA for the whole column -- use
#'   with caution, never in production without manual review).
#' @return data.frame with 1 row per respondent: `educ3_final`,
#'   `educ3_source_variable`, `educ3_source_scheme`, `educ3_quality_flag`.
#' @details The 2024 wave has reduced confidence -- `readstata13` did not
#'   recover the value labels of this particular file, so the codes were
#'   inferred from the identical historical order confirmed in 9 other
#'   waves, not by direct confirmation from labels. Use with caution when
#'   `educ3_quality_flag` is
#'   `"confianca_reduzida_2024_codigos_inferidos"`.
#' @examples
#' # 100% synthetic data -- no real respondent value
#' sim <- simulate_latinobarometro_wave(2018, n = 50)
#' educ <- harmonize_educ3_latinobarometro(sim, 2018)
#' table(educ$educ3_final, useNA = "ifany")
#'
#' # year outside the table of validated years -- refuses, does not guess
#' tryCatch(
#'   harmonize_educ3_latinobarometro(sim, 2099),
#'   error = function(e) message("Refused as expected: ", conditionMessage(e))
#' )
#' @export
harmonize_educ3_latinobarometro <- function(raw_data, year, on_unvalidated_year = c("error", "warning")) {
  on_unvalidated_year <- match.arg(on_unvalidated_year)
  anos_validados <- .educ3_anos_validados()
  linha <- anos_validados[anos_validados$year == year, ]

  if (nrow(linha) == 0) {
    msg <- paste0(
      "educ3_final has NO validated logic for year ", year, ". ",
      "Validated years: ", paste(sort(anos_validados$year), collapse = ", "), ". ",
      "A new wave requires updating inst/extdata/educ3_validated_years.csv manually ",
      "(see the package docs) -- there is no automatic detection of the education variable."
    )
    if (on_unvalidated_year == "error") stop(msg, call. = FALSE)
    warning(msg, call. = FALSE)
    return(data.frame(
      educ3_final = rep(NA_character_, nrow(raw_data)),
      educ3_source_variable = NA_character_, educ3_source_scheme = NA_character_,
      educ3_quality_flag = "ano_nao_validado"
    ))
  }

  scheme <- linha$scheme[1]

  if (scheme == "ambos_2024") {
    vars <- strsplit(linha$raw_variable_name[1], ";")[[1]]
    var_cat <- vars[1]; var_years <- vars[2]
    if (!var_cat %in% names(raw_data) || !var_years %in% names(raw_data)) {
      stop("Columns expected for 2024 (", var_cat, ", ", var_years, ") not found in raw_data.", call. = FALSE)
    }
    codigo_cat <- suppressWarnings(as.numeric(raw_data[[var_cat]])); codigo_cat[codigo_cat < 0] <- NA
    codigo_years <- suppressWarnings(as.numeric(raw_data[[var_years]])); codigo_years[codigo_years < 0] <- NA
    valor_cat <- .mapear_cat7(codigo_cat)
    valor_years <- .mapear_years17(codigo_years)
    educ3_final <- ifelse(!is.na(valor_cat), valor_cat, valor_years)
    fonte <- ifelse(!is.na(valor_cat), var_cat, var_years)
    flag <- "confianca_reduzida_2024_codigos_inferidos"
  } else {
    var <- linha$raw_variable_name[1]
    if (!var %in% names(raw_data)) {
      stop("Expected column '", var, "' (education, year ", year, ") not found in raw_data. ",
           "Check that the downloaded file is the Latinobarometro ", year, " wave.", call. = FALSE)
    }
    codigo <- suppressWarnings(as.numeric(raw_data[[var]])); codigo[codigo < 0] <- NA
    educ3_final <- switch(scheme,
      cat7 = .mapear_cat7(codigo), cat3 = .mapear_cat3(codigo), years17 = .mapear_years17(codigo),
      stop("Unknown scheme: ", scheme, call. = FALSE))
    fonte <- var
    flag <- "validado"
  }

  # guard-rail: nunca usar educacao do chefe de familia como se fosse do respondente
  # (bug real de 2023 -- REEDUC_3/S21B sao do chefe; S11 e do respondente, ja garantido
  # pela tabela de anos validados, mas o check fica aqui como defesa em profundidade)
  if (year == 2023 && fonte %in% c("REEDUC_3", "S21B")) {
    stop("BLOCKED: HEAD OF HOUSEHOLD education variable (", fonte, ") cannot be used ",
         "as the respondent's education (known 2023 bug). Use S11.", call. = FALSE)
  }

  data.frame(
    educ3_final = educ3_final,
    educ3_source_variable = fonte,
    educ3_source_scheme = scheme,
    educ3_quality_flag = flag,
    stringsAsFactors = FALSE
  )
}

#' List the years with validated education logic
#'
#' Years outside this table are not processed by
#' [harmonize_educ3_latinobarometro()] -- the function refuses instead of
#' guessing the scheme/variable for an unseen wave. Adding a new wave
#' requires updating `inst/extdata/educ3_validated_years.csv` manually
#' (see the package README).
#'
#' @return data.frame with `year`, `raw_variable_name`, `scheme`,
#'   `respondent_or_head`, `confidence_note` -- one row per validated wave
#'   (1995-2024; 2024 with reduced confidence, see `confidence_note`).
#' @examples
#' anos <- educ3_validated_years()
#' anos[, c("year", "scheme", "confidence_note")]
#' @export
educ3_validated_years <- function() .educ3_anos_validados()
