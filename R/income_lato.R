# =============================================================================
# income_lato.R
# Wrapper de conveniencia -- combina prepare_latinobarometro_income_inputs()
# e predict_latinobarometro_income() num unico passo, para o caso de uso
# mais comum (ler uma onda ou um diretorio de ondas e sair direto com as
# probabilidades), e resume a execucao numa message() final.
# Usuarios que precisam inspecionar/filtrar o banco harmonizado antes de
# prever devem usar as duas funcoes separadamente.
# =============================================================================

#' Aplica o modelo de renda v1.5 a microdados do Latinobarometro (atalho)
#'
#' Combina [prepare_latinobarometro_income_inputs()] e
#' [predict_latinobarometro_income()] num unico passo. Equivalente a:
#' `predict_latinobarometro_income(prepare_latinobarometro_income_inputs(raw_dir, years, countries), model_version, include_2024)`,
#' mais um resumo da execucao emitido com `message()` ao final: ondas
#' detectadas, ondas excluidas por padrao (2024), ondas ignoradas por falha
#' de leitura, e paises sem nenhuma predicao com o motivo.
#'
#' O pacote NAO distribui microdados do Latinobarometro -- `raw_dir` deve
#' apontar para arquivos baixados pelo usuario da fonte oficial
#' (latinobarometro.org).
#'
#' @param raw_dir caminho de um arquivo `.dta`/`.sav` de uma onda, ou de um
#'   diretorio com um arquivo por onda (baixados pelo usuario -- nao
#'   distribuidos com o pacote).
#' @param years vetor de anos a processar (default: todos os arquivos
#'   encontrados; ver [educ3_validated_years()] para os anos com
#'   harmonizacao de educacao validada). Para um arquivo unico sem o ano no
#'   nome, informe o ano aqui.
#' @param countries vetor de codigos ISO3 para filtrar (default: todos
#'   os paises presentes no arquivo).
#' @param model_version versao do modelo a aplicar (unica disponivel
#'   nesta v0.1: `"v1_5"`, o modelo congelado).
#' @param include_2024 se `FALSE` (padrao), remove a onda 2024 do
#'   resultado -- os codigos de educacao dessa onda foram inferidos por
#'   ordem historica, nao confirmados por rotulo (o `.dta` de 2024 so e
#'   lido pelo readstata13, sem os rotulos de valor). Se `TRUE`,
#'   mantem 2024 com um warning adicional explicando o motivo especifico
#'   da confianca reduzida.
#'
#' @return data.frame: o banco harmonizado com `prob_bottom50`,
#'   `prob_middle40`, `prob_top10`, `elegivel`, `motivo_exclusao` e as
#'   flags de confianca por pais ANEXADAS (nao um objeto separado
#'   casado por posicao). As probabilidades sao PESO CONTINUO para
#'   composicao/associacao -- nao classifique respondentes individuais
#'   por corte duro, e nao interprete `mean(prob_bottom50)` por
#'   pais-onda como o tamanho do bottom50 (a margem agregada deriva ao
#'   longo do tempo por razoes do proprio modelo). Um warning com esse
#'   aviso e emitido na primeira chamada da sessao; ver tambem
#'   `attr(resultado, "uso_recomendado")` / `attr(resultado, "uso_proibido")`.
#'
#' @examples
#' # Uma onda, arquivo unico. Dado 100% sintetico gravado como .dta
#' # temporario -- nenhum respondente real do Latinobarometro.
#' sim <- simulate_latinobarometro_wave(2011, n = 20)
#' arquivo <- file.path(tempdir(), "Latinobarometro_2011_sim.dta")
#' haven::write_dta(sim, arquivo)
#' res <- income_lato(arquivo)
#' head(res[, c("iso3", "prob_bottom50", "motivo_exclusao")])
#' unlink(arquivo)
#'
#' \dontrun{
#' # uso real, com microdados baixados pelo usuario:
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
    "incomeLato -- resumo da execucao",
    paste0("  ondas detectadas: ", if (length(detectadas)) paste(detectadas, collapse = ", ") else "nenhuma"),
    paste0("  ondas excluidas por padrao: ",
           if (length(excluidas_2024)) "2024 (use include_2024 = TRUE para incluir)" else "nenhuma"),
    if (length(ignoradas)) paste0("  ondas ignoradas por falha de leitura: ", paste(ignoradas, collapse = ", ")),
    paste0("  respondentes com predicao: ", sum(!is.na(res$prob_bottom50)), " de ", nrow(res))
  )

  com_pred <- tapply(!is.na(res$prob_bottom50), res$iso3, any)
  sem_pred <- names(com_pred)[!com_pred]
  if (length(sem_pred)) {
    motivos <- vapply(sem_pred, function(p) {
      m <- table(res$motivo_exclusao[res$iso3 %in% p])
      paste(names(m), collapse = " / ")
    }, character(1))
    linhas <- c(linhas, "  paises sem predicao:", paste0("    ", sem_pred, ": ", motivos))
  } else {
    linhas <- c(linhas, "  paises sem predicao: nenhum")
  }
  paste(linhas, collapse = "\n")
}
