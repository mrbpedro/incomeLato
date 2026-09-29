# =============================================================================
# build_test_fixture.R
# Gera tests/testthat/fixtures/regressao_v1_5.rds: saida do modelo v1.5 sobre
# o banco sintetico fixo (simulate_latinobarometro_wave(2018, n = 10, seed =
# 42), 17 paises x 10 = 170 linhas; nenhum dado real). So regerar quando uma
# mudanca de saida for intencional e estiver registrada no NEWS.md.
#
# Rodar a partir da raiz do pacote, com o pacote instalado na versao a fixar:
#   Rscript data-raw/build_test_fixture.R
# =============================================================================

library(incomeLato)
source("tests/testthat/helper-banco-sintetico.R")

banco <- banco_sintetico(2018, n = 10, seed = 42)
res <- suppressWarnings(predict_latinobarometro_income(banco))
res <- res[order(res$iso3, res$respondent_row_id),
           c("iso3", "respondent_row_id", "prob_bottom50", "prob_middle40", "prob_top10")]
rownames(res) <- NULL
stopifnot(nrow(res) <= 200)

dir.create("tests/testthat/fixtures", showWarnings = FALSE)
saveRDS(res, "tests/testthat/fixtures/regressao_v1_5.rds", version = 2)
