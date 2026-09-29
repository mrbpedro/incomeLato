# Testes da v1.5 (15 paises, Mexico sem recalibrador). Dado 100% sintetico.

test_that("Mexico e elegivel e sai com a probabilidade bruta do modelo (sem recalibracao)", {
  banco <- banco_sintetico(2018, n = 30)
  res <- suppressWarnings(predict_latinobarometro_income(banco))
  mex <- res[res$iso3 == "MEX" & res$elegivel, ]
  expect_gt(nrow(mex), 0)
  expect_true(all(is.na(mex$flag_margin)))

  modelo <- .carregar_modelo("v1_5")
  sub <- mex; sub$country <- "MEX"
  X <- .construir_X(sub, modelo$idade_center, modelo$idade_scale)[, modelo$colnames_X, drop = FALSE]
  bruto <- stats::predict(modelo$modelo, newx = X, type = "response")[, , 1]
  expect_equal(mex$prob_bottom50, unname(bruto[, "bottom50"]), tolerance = 1e-12)
  expect_false("MEX" %in% names(.carregar_recalibradores()$recalibradores))
})

test_that("pais recalibrado difere da saida bruta (controle do teste do Mexico)", {
  banco <- banco_sintetico(2018, n = 30)
  res <- suppressWarnings(predict_latinobarometro_income(banco))
  arg <- res[res$iso3 == "ARG" & res$elegivel, ]
  modelo <- .carregar_modelo("v1_5")
  sub <- arg; sub$country <- "ARG"
  X <- .construir_X(sub, modelo$idade_center, modelo$idade_scale)[, modelo$colnames_X, drop = FALSE]
  bruto <- stats::predict(modelo$modelo, newx = X, type = "response")[, , 1]
  expect_gt(max(abs(arg$prob_bottom50 - bruto[, "bottom50"])), 1e-4)
})

test_that("regressao: saida do modelo v1.5 sobre a fixture sintetica nao muda", {
  esperado <- readRDS(test_path("fixtures", "regressao_v1_5.rds"))
  banco <- banco_sintetico(2018, n = 10, seed = 42)
  res <- suppressWarnings(predict_latinobarometro_income(banco))
  res <- res[order(res$iso3, res$respondent_row_id), c("iso3", "respondent_row_id", "prob_bottom50", "prob_middle40", "prob_top10")]
  rownames(res) <- NULL
  expect_equal(res, esperado, tolerance = 1e-10)
})

test_that("modelo carregado tem o estatuto corrigido em memoria e os 15 paises", {
  modelo <- .carregar_modelo("v1_5")
  expect_identical(modelo$release_status, "promoted_primary")
  expect_identical(modelo$countries, PAISES_ATIVOS)
  expect_length(PAISES_ATIVOS, 15)
  expect_error(.carregar_modelo("v1_4"), "Unica versao")
})

test_that("prepare_latinobarometro_income_inputs le .sav", {
  sim <- simulate_latinobarometro_wave(2011, n = 5)
  tmp_dir <- tempfile("lb_sav_"); dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))
  haven::write_sav(sim, file.path(tmp_dir, "Latinobarometro_2011_sim.sav"))
  banco <- prepare_latinobarometro_income_inputs(tmp_dir, years = 2011)
  expect_equal(nrow(banco), nrow(sim))
  expect_true("MEX" %in% banco$iso3)
})

test_that("duas copias da mesma onda no diretorio geram erro", {
  tmp_dir <- tempfile("lb_dup_"); dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))
  file.create(file.path(tmp_dir, "Latinobarometro_2011_a.dta"))
  file.create(file.path(tmp_dir, "Latinobarometro_2011_b.sav"))
  expect_error(prepare_latinobarometro_income_inputs(tmp_dir, years = 2011), "Mais de um arquivo")
})
