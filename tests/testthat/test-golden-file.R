# =============================================================================
# test-golden-file.R
# Bloco 15, TAREFA 6: testes unitarios com dado SINTETICO (nao
# redistribuivel) -- smoke tests estruturais. A validacao golden-file
# CONTRA O PRODUTO V1.4 REAL (reproducao exata, N=329.326, corr=1.0,
# diff_max=0) foi feita em desenvolvimento sobre os microdados locais
# do projeto e esta documentada em data-raw/golden_file_validation.md
# -- nao repetida aqui porque exigiria embutir o produto v1.4 e os
# .dta brutos no pacote, o que violaria a premissa de nao-redistribuicao.
# =============================================================================

test_that("harmonize_educ3_latinobarometro recusa ano nao validado", {
  sim <- simulate_latinobarometro_wave(2018, n = 10)
  expect_error(harmonize_educ3_latinobarometro(sim, 2099), "NAO tem logica validada")
})

test_that("harmonize_educ3_latinobarometro produz as 3 categorias esperadas", {
  sim <- simulate_latinobarometro_wave(2018, n = 200)
  educ <- harmonize_educ3_latinobarometro(sim, 2018)
  expect_true(all(educ$educ3_final %in% c("basic_or_less", "secondary", "higher_or_more", NA)))
})

test_that("prepare + predict rodam ponta a ponta sobre dado sintetico sem erro", {
  sim <- simulate_latinobarometro_wave(2018, n = 100)
  # simula prepare_latinobarometro_income_inputs() sem exigir arquivo em disco:
  core <- harmonize_core_predictors(sim, 2018)
  educ <- harmonize_educ3_latinobarometro(sim, 2018)
  cw_pais <- read.csv(system.file("extdata", "country_crosswalk.csv", package = "incomeLato"), stringsAsFactors = FALSE)
  banco <- data.frame(year = 2018, country_raw = core$country_raw, respondent_row_id = seq_len(nrow(sim)),
                       weight = core$weight, sexo_final = core$sexo_final, idade_final = core$idade_final,
                       educ3_final = educ$educ3_final, owns_car = core$owns_car,
                       owns_washing_machine = core$owns_washing_machine, source_file = "sintetico",
                       harmonization_flags = NA_character_, stringsAsFactors = FALSE)
  banco <- merge(banco, cw_pais, by.x = "country_raw", by.y = "country_numeric", all.x = TRUE)

  resultado <- suppressWarnings(predict_latinobarometro_income(banco))
  expect_true(all(c("prob_bottom50", "prob_middle40", "prob_top10") %in% names(resultado)))
  expect_equal(nrow(resultado), nrow(banco))
  # Venezuela deve estar sempre bloqueada
  expect_true(all(is.na(resultado$prob_bottom50[resultado$iso3 == "VEN"])))
  expect_true(all(resultado$motivo_exclusao[resultado$iso3 == "VEN"] == "venezuela_quarentena_arquitetural"))
  # probabilidades devem somar 1 onde elegivel
  elig <- !is.na(resultado$prob_bottom50)
  if (any(elig)) {
    soma <- resultado$prob_bottom50[elig] + resultado$prob_middle40[elig] + resultado$prob_top10[elig]
    expect_true(all(abs(soma - 1) < 1e-6))
  }
})

test_that("simulate_latinobarometro_wave nao contem dado real (marcador de atributo)", {
  sim <- simulate_latinobarometro_wave(2018, n = 10)
  expect_true(isTRUE(attr(sim, "synthetic")))
})

test_that("harmonize_core_predictors falha informativamente quando a coluna vem como factor (padrao real da onda 2024)", {
  # simula o padrao real descoberto no Bloco 16: IDENPA/SEXO em 2024 vem
  # como factor com rotulo de texto embutido ("[%32%] Argentina", "Woman"),
  # nao um codigo numerico direto -- as.numeric(factor) extrairia a
  # POSICAO do nivel silenciosamente, nao o codigo real.
  sim <- simulate_latinobarometro_wave(2011, n = 10)
  cw <- read.csv(system.file("extdata", "lb_income_predictor_crosswalk.csv", package = "incomeLato"), stringsAsFactors = FALSE)
  col_sex <- cw$raw_variable_name[cw$year == 2011 & cw$harmonized_concept == "sex"]
  sim[[col_sex]] <- factor(ifelse(sim[[col_sex]] == 1, "Man", "Woman"))
  expect_error(harmonize_core_predictors(sim, 2011), "veio como factor")
})

test_that("prepare_latinobarometro_income_inputs ignora uma onda que falha e mantem as demais", {
  # NOTA: nao e possivel reproduzir o mecanismo exato (readstata13
  # devolvendo um factor genuino) via um roundtrip haven::write_dta() +
  # leitura -- o haven converte factor em haven_labelled<double> na
  # escrita, nao preserva a classe factor. Este teste mocka .ler_onda()
  # para simular uma onda cuja leitura produz uma coluna-factor (o
  # padrao real observado na onda 2024, ver README), sem depender do
  # comportamento de serializacao do haven.
  sim_ok <- simulate_latinobarometro_wave(2011, n = 10)
  cw <- read.csv(system.file("extdata", "lb_income_predictor_crosswalk.csv", package = "incomeLato"), stringsAsFactors = FALSE)
  col_sex_2013 <- cw$raw_variable_name[cw$year == 2013 & cw$harmonized_concept == "sex"]
  sim_quebrada <- simulate_latinobarometro_wave(2013, n = 10)
  sim_quebrada[[col_sex_2013]] <- factor(ifelse(sim_quebrada[[col_sex_2013]] == 1, "Man", "Woman"))

  ler_onda_mock <- local({
    chamadas <- 0
    function(path) {
      chamadas <<- chamadas + 1
      if (grepl("2013", path)) sim_quebrada else sim_ok
    }
  })
  testthat::local_mocked_bindings(.ler_onda = ler_onda_mock)

  tmp_dir <- tempfile("lb_sim_multi_"); dir.create(tmp_dir)
  file.create(file.path(tmp_dir, "Latinobarometro_2011_sim.dta"))
  file.create(file.path(tmp_dir, "Latinobarometro2013Eng_sim.dta"))

  expect_warning(
    banco <- prepare_latinobarometro_income_inputs(tmp_dir, years = c(2011, 2013)),
    "IGNORADA"
  )
  expect_true(all(banco$year == 2011))
  unlink(tmp_dir, recursive = TRUE)
})
