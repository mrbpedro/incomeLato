# =============================================================================
# data-raw/build_model_objects.R
# Copia os objetos do modelo para inst/model/:
#   1. modelo v1.5 (pooled15, 15 paises) -- copia byte a byte do artefato
#      promovido, com conferencia do SHA-256 antes e depois;
#   2. recalibradores v1.4 (14 paises) -- limpeza de licenca: remove o model
#      frame do glm() (que embutiria linhas do LAPOP, dado de terceiros),
#      mantendo so o necessario para predict(). O Mexico nao tem recalibrador.
# Esta e a combinacao que reproduz exatamente o produto v1.5 promovido
# (ver data-raw/golden_file_validation_v1_5.R).
#
# Rodar a partir da raiz do pacote. INCOMELATO_PROJ_ROOT aponta para o
# projeto de pesquisa (padrao: ../.., o pacote vive em pacote/incomeLato/).
# =============================================================================

proj_root <- Sys.getenv("INCOMELATO_PROJ_ROOT", "../..")
dir.create("inst/model", showWarnings = FALSE, recursive = TRUE)

# --- 1. modelo glmnet v1.5 (so coeficientes e escalares de padronizacao) ---
SHA_MODELO_V1_5 <- "c935cb87f974d71a409e8849ce45cd3be34eaa8b99cb157805b63eb0afc8687d"
origem_modelo <- file.path(proj_root, "staging/package_candidate_mexico_pooled15/models/pooled",
                           "core5_lb_educ3_income_quantile_v1_5_mex_20260713",
                           "modelo_core5_lb_educ3_income_quantile_v1_5_mex.rds")
sha256 <- function(f) unname(system2("shasum", c("-a", "256", shQuote(f)), stdout = TRUE)) |> sub(pattern = " .*", replacement = "")
stopifnot(identical(sha256(origem_modelo), SHA_MODELO_V1_5))
file.copy(origem_modelo, "inst/model/modelo_income_quantile_v1_5.rds", overwrite = TRUE, copy.date = TRUE)
stopifnot(identical(sha256("inst/model/modelo_income_quantile_v1_5.rds"), SHA_MODELO_V1_5))
# O .rds carrega release_status/model_version gravados antes da promocao; o
# pacote os corrige em memoria (R/predict_income.R, .carregar_modelo()).

# --- 2. recalibradores por pais v1.4 -- LIMPEZA DE LICENCA ---
origem_recal <- file.path(proj_root, "models/pooled/recalibradores_por_pais_v1_4_per_20260711/recalibradores_por_pais_v1_4.rds")
recal <- readRDS(origem_recal)
tamanho_antes <- object.size(recal)

CAMPOS_A_REMOVER <- c("model", "data", "y", "residuals", "fitted.values", "linear.predictors", "weights", "prior.weights", "effects")
for (pais in names(recal$recalibradores)) {
  cal <- recal$recalibradores[[pais]]
  if (identical(cal$metodo, "platt") && !is.null(cal$fit)) {
    for (campo in CAMPOS_A_REMOVER) cal$fit[[campo]] <- NULL
    if (!is.null(cal$fit$qr)) cal$fit$qr$qr <- NULL
    recal$recalibradores[[pais]] <- cal
  }
  # isotonica ja e so uma lista de breakpoints (xl/xr/y) -- nada a limpar
}
cat("Tamanho do objeto recalibrador -- antes:", format(tamanho_antes, units = "Kb"),
    "| depois:", format(object.size(recal), units = "Kb"), "\n")

# --- confirmar que a predicao ainda funciona identicamente apos a limpeza ---
source(file.path(proj_root, "scripts/_lib_recalibracao.R"))
p_teste <- seq(0.05, 0.95, by = 0.05)
recal_bruto_orig <- readRDS(origem_recal)
for (pais in c("BRA", "CHL", "ARG")) {
  stopifnot(isTRUE(all.equal(predizer_recalibrado(recal_bruto_orig$recalibradores[[pais]], p_teste),
                             predizer_recalibrado(recal$recalibradores[[pais]], p_teste))))
}
stopifnot(!"MEX" %in% names(recal$recalibradores))

saveRDS(recal, "inst/model/recalibradores_v1_4.rds")

# --- 3. tabelas de referencia ---
# inst/extdata/confianca_por_pais.csv: copiada em 2026-07-24 de
# data/output/diagnostics/income_quantile_v1_confianca_por_pais.csv (14
# paises); linha do Mexico acrescentada a mao em 2026-09-29. Mantida no
# pacote a partir dai -- nao recopiar.
# Veredito de margem e regras de janela: data-raw/build_sysdata.R.
