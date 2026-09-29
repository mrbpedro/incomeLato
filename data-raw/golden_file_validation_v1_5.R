# =============================================================================
# golden_file_validation_v1_5.R
# Validacao ponta a ponta do pacote contra o produto v1.5 promovido do artigo
# (latinobarometro_prob_bottom50_core5_lb_educ3_v1_5_mex_20260713.rds,
# SHA-256 daec7471...). NAO e teste do testthat: depende dos microdados do
# Latinobarometro, que o usuario baixa por conta propria em
# latinobarometro.org, e do produto do projeto de pesquisa. Nada disso e
# distribuido com o pacote.
#
# Uso, a partir da raiz do pacote, com o pacote instalado:
#   INCOMELATO_PROJ_ROOT=../.. Rscript data-raw/golden_file_validation_v1_5.R
#
# Resultado em 2026-09-29: 369.999/369.999 linhas casadas (1995-2024, 15
# paises); max |diff| = 0 nas tres probabilidades; unica divergencia de flag:
# flag_piso_confianca do MEX (NA no produto, FALSE no pacote, deliberado).
# =============================================================================

suppressMessages(library(incomeLato))
P <- Sys.getenv("INCOMELATO_PROJ_ROOT", "../..")
raw <- file.path(P, "data/raw/latinobarometro/extracted")
produto <- file.path(P, "staging/package_candidate_mexico_pooled15/data/output/predictions",
                     "latinobarometro_prob_bottom50_core5_lb_educ3_v1_5_mex_20260713.rds")
SHA_PRODUTO <- "daec74714e5fc6882adcc2e677d70b26fb2505e44fb18bf8647fa29d58e1974c"
sha <- sub(" .*", "", system2("shasum", c("-a", "256", shQuote(produto)), stdout = TRUE))
stopifnot(identical(sha, SHA_PRODUTO))

banco <- suppressWarnings(prepare_latinobarometro_income_inputs(raw, years = incomeLato:::ONDAS_VALIDAS))
res <- suppressWarnings(suppressMessages(predict_latinobarometro_income(banco, include_2024 = TRUE)))
pk <- res[!is.na(res$prob_bottom50), ]
prod <- readRDS(produto)
cat("N pacote elegivel:", nrow(pk), " N produto:", nrow(prod), "\n")

k_pk <- table(paste(pk$iso3, pk$year)); k_pr <- table(paste(prod$iso3, prod$year))
cel <- union(names(k_pk), names(k_pr))
n_pk <- as.integer(k_pk[cel]); n_pr <- as.integer(k_pr[cel])
dif <- cel[is.na(n_pk) | is.na(n_pr) | n_pk != n_pr]
cat("celulas pais-onda com N divergente:", length(dif), "\n")
if (length(dif)) print(data.frame(celula = dif, pacote = n_pk[match(dif, cel)], produto = n_pr[match(dif, cel)]))

# alinhamento: ordem original dentro de pais-onda nas duas bases
pk <- pk[order(pk$year, pk$iso3, pk$respondent_row_id), ]
prod <- prod[order(prod$year, prod$iso3, prod$obs_id), ]
stopifnot(nrow(pk) == nrow(prod), identical(paste(pk$iso3, pk$year), paste(prod$iso3, prod$year)))

for (v in c("sexo_final", "idade_final", "educ3_final", "owns_car", "owns_washing_machine")) {
  cat(sprintf("covariavel %-22s divergentes: %d\n", v, sum(as.character(pk[[v]]) != as.character(prod[[v]]), na.rm = TRUE)))
}
cat("peso max|d|:", max(abs(pk$weight - prod$weight)), "\n")
for (v in c("prob_bottom50", "prob_middle40", "prob_top10")) {
  d <- abs(pk[[v]] - prod[[v]])
  cat(sprintf("%-14s max|d|=%.3e  n>1e-3=%d  corr=%.10f\n", v, max(d), sum(d > 1e-3), cor(pk[[v]], prod[[v]])))
}
cat("max|d| prob_bottom50 por pais:\n")
print(signif(tapply(abs(pk$prob_bottom50 - prod$prob_bottom50), pk$iso3, max), 3))
for (f in c("confianca_alvo_treino", "flag_margin", "flag_tier_reduzido", "flag_piso_confianca", "flag_fonte_censitaria")) {
  a <- as.character(pk[[f]]); b <- as.character(prod[[f]])
  diverge <- xor(is.na(a), is.na(b)) | (!is.na(a) & !is.na(b) & a != b)
  cat(sprintf("flag %-24s divergentes: %d %s\n", f, sum(diverge),
              if (any(diverge)) paste0("(", paste(unique(pk$iso3[diverge]), collapse = ","), ")") else ""))
}
