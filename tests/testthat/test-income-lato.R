# income_lato(): onda unica (arquivo ou pasta) e resumo da execucao.
# Dado 100% sintetico gravado como .dta temporario.

grava_onda_sintetica <- function(dir, ano = 2011, n = 15, nome = NULL) {
  sim <- simulate_latinobarometro_wave(ano, n = n)
  arquivo <- file.path(dir, nome %||% paste0("Latinobarometro_", ano, "_sim.dta"))
  haven::write_dta(sim, arquivo)
  arquivo
}
`%||%` <- function(a, b) if (is.null(a)) b else a

test_that("income_lato aceita arquivo unico e da o mesmo resultado que a pasta e que as duas etapas", {
  dir <- tempfile("lb_uma_onda_"); dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE))
  arquivo <- grava_onda_sintetica(dir)

  por_arquivo <- suppressMessages(suppressWarnings(income_lato(arquivo)))
  por_pasta <- suppressMessages(suppressWarnings(income_lato(dir)))
  em_duas_etapas <- suppressMessages(suppressWarnings(
    predict_latinobarometro_income(prepare_latinobarometro_income_inputs(dir))))

  expect_identical(por_arquivo, por_pasta)
  expect_equal(por_arquivo$prob_bottom50, em_duas_etapas$prob_bottom50)
  expect_true(all(por_arquivo$year == 2011))
  expect_gt(sum(!is.na(por_arquivo$prob_bottom50)), 0)
})

test_that("income_lato resume a execucao numa message final", {
  dir <- tempfile("lb_resumo_"); dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE))
  arquivo <- grava_onda_sintetica(dir)

  msgs <- character(0)
  withCallingHandlers(suppressWarnings(income_lato(arquivo)),
                      message = function(m) { msgs <<- c(msgs, conditionMessage(m)); invokeRestart("muffleMessage") })
  resumo <- msgs[grepl("resumo da execucao", msgs)]
  expect_length(resumo, 1)
  expect_match(resumo, "ondas detectadas: 2011")
  expect_match(resumo, "ondas excluidas por padrao: nenhuma")
  expect_match(resumo, "VEN: venezuela_quarentena_arquitetural")
  expect_match(resumo, "GTM: pais_fora_dos_15_ativos")
  expect_false(grepl("ARG:", resumo))
})

test_that("resumo lista 2024 como excluida por padrao e as ondas ignoradas", {
  banco <- data.frame(year = c(2018, 2024), iso3 = c("ARG", "ARG"))
  attr(banco, "ondas_detectadas") <- c(2013, 2018, 2024)
  attr(banco, "ondas_ignoradas") <- 2013
  res <- data.frame(iso3 = "ARG", prob_bottom50 = 0.5, motivo_exclusao = NA_character_)
  resumo <- .resumo_execucao(banco, res, include_2024 = FALSE)
  expect_match(resumo, "ondas detectadas: 2013, 2018, 2024")
  expect_match(resumo, "2024 \\(use include_2024 = TRUE")
  expect_match(resumo, "ignoradas por falha de leitura: 2013")
  expect_match(resumo, "paises sem predicao: nenhum")
  expect_match(.resumo_execucao(banco, res, include_2024 = TRUE), "excluidas por padrao: nenhuma")
})

test_that("arquivo unico sem ano no nome exige years", {
  dir <- tempfile("lb_sem_ano_"); dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE))
  arquivo <- grava_onda_sintetica(dir, nome = "minha_onda.dta")
  expect_error(suppressWarnings(prepare_latinobarometro_income_inputs(arquivo)), "Nenhum arquivo correspondente")
  banco <- prepare_latinobarometro_income_inputs(arquivo, years = 2011)
  expect_true(all(banco$year == 2011))
})

test_that("caminho inexistente gera erro claro", {
  expect_error(prepare_latinobarometro_income_inputs(file.path(tempdir(), "nao_existe.dta")),
               "Diretorio ou arquivo nao encontrado")
})
