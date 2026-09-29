# =============================================================================
# design_matrix.R
# Reaproveitado de scripts/_lib_design_matrix_core5_lb_educ3_v1_2.R e
# scripts/_lib_recalibracao.R (do projeto principal) -- logica de
# APLICACAO estatistica, separada da harmonizacao de entrada (que fica
# em harmonize_predictors.R / harmonize_educ3.R). Nao alterada.
# =============================================================================

#' Force loading of dependency namespaces (internal use)
#'
#' Without this, S3 dispatch of `stats::predict()` on a
#' `"multnet"/"glmnet"` object fails ("no applicable method") -- being
#' listed in `Imports` in DESCRIPTION is not enough if no line of code
#' uses `@importFrom`; NAMESPACE needs a matching import line for the
#' namespace to be loaded (found by `R CMD check`).
#' @importFrom glmnet glmnet
#' @importFrom utils read.csv packageVersion
#' @keywords internal
.forcar_imports <- function() {
  invisible(NULL)
}

# Mesma ordem de `modelo$countries` do modelo v1.5 (MEX por ultimo);
# .carregar_modelo() confere a igualdade a cada carga.
PAISES_ATIVOS <- c("ARG", "BOL", "BRA", "CHL", "COL", "CRI", "ECU", "HND", "NIC", "PAN", "PER", "PRY", "SLV", "URY", "MEX")

#' @keywords internal
.recodificar_preditores <- function(df) {
  df$owns_car_cat <- ifelse(is.na(df$owns_car), "FALSE", ifelse(df$owns_car, "TRUE", "FALSE"))
  df$owns_washing_machine_cat <- ifelse(is.na(df$owns_washing_machine), "FALSE", ifelse(df$owns_washing_machine, "TRUE", "FALSE"))
  df$owns_car_cat <- factor(df$owns_car_cat, levels = c("FALSE", "TRUE"))
  df$owns_washing_machine_cat <- factor(df$owns_washing_machine_cat, levels = c("FALSE", "TRUE"))
  df$sexo_final <- factor(df$sexo_final, levels = c("hombre", "mujer"))
  df$educ3_final <- factor(df$educ3_final, levels = c("basic_or_less", "secondary", "higher_or_more"))
  df$country <- factor(df$country, levels = PAISES_ATIVOS)
  df
}

#' @keywords internal
.construir_X <- function(df, idade_center, idade_scale) {
  df <- .recodificar_preditores(df)
  df$idade_z <- (df$idade_final - idade_center) / idade_scale
  Matrix::sparse.model.matrix(
    ~ 0 + country + sexo_final + idade_z + educ3_final + owns_car_cat + owns_washing_machine_cat,
    data = df
  )
}

# --- recalibracao (identica a scripts/_lib_recalibracao.R) ---
#' @keywords internal
.predizer_platt <- function(modelo, p_raw) {
  eps <- 1e-6
  logit_p <- log(pmin(pmax(p_raw, eps), 1 - eps) / (1 - pmin(pmax(p_raw, eps), 1 - eps)))
  as.numeric(stats::predict(modelo$fit, newdata = data.frame(logit_p = logit_p), type = "response"))
}
#' @keywords internal
.predizer_isotonica <- function(modelo, p_raw) {
  idx <- findInterval(p_raw, modelo$xl, all.inside = TRUE)
  idx <- pmin(pmax(idx, 1), length(modelo$y))
  modelo$y[idx]
}
#' @keywords internal
.predizer_recalibrado <- function(modelo, p_raw) {
  if (modelo$metodo == "isotonica") .predizer_isotonica(modelo, p_raw) else .predizer_platt(modelo, p_raw)
}
#' @keywords internal
.aplicar_recalibracao_3classes <- function(modelo, p_bottom50, p_middle40, p_top10) {
  p_bottom50_novo <- pmin(pmax(.predizer_recalibrado(modelo, p_bottom50), 0), 1)
  resto_raw <- p_middle40 + p_top10
  resto_novo <- 1 - p_bottom50_novo
  frac_middle <- ifelse(resto_raw > 0, p_middle40 / resto_raw, 0.5)
  data.frame(p_bottom50 = p_bottom50_novo, p_middle40 = frac_middle * resto_novo, p_top10 = (1 - frac_middle) * resto_novo)
}
