# =============================================================================
# predict_income.R
# Bloco 15, TAREFA 5: aplica o modelo de renda v1.5 congelado ao banco
# preparado por prepare_latinobarometro_income_inputs(). Devolve o banco
# do USUARIO com as probabilidades ANEXADAS (nao um objeto separado
# casado por posicao), mais flags de confianca por pais e o aviso de
# uso emitido ativamente (nao so documentado).
# =============================================================================

#' @keywords internal
.carregar_modelo <- function(model_version) {
  if (model_version != "v1_5") stop("Unica versao empacotada nesta v0.1: 'v1_5'.", call. = FALSE)
  modelo <- readRDS(system.file("model", "modelo_income_quantile_v1_5.rds", package = "incomeLato"))
  if (!identical(modelo$countries, PAISES_ATIVOS)) {
    stop("Paises do modelo empacotado divergem de PAISES_ATIVOS -- pacote inconsistente.", call. = FALSE)
  }
  # O .rds e byte-identico ao artefato promovido (SHA-256 c935cb87...), que
  # carrega metadado interno gravado antes da promocao de 2026-07-13
  # (release_status = "candidate_manual_review_only", model_version =
  # "pooled15_candidate_v1"). O estatuto vale pelo model_registry do projeto,
  # nao por esses campos; corrigidos aqui so em memoria, arquivo intacto.
  modelo$release_status <- "promoted_primary"
  modelo$model_version <- "core5_lb_educ3_income_quantile_v1_5_mex"
  modelo
}
#' @keywords internal
.carregar_recalibradores <- function() {
  # Recalibradores v1.4 (14 paises), os mesmos que geraram o produto v1.5
  # promovido. O Mexico nao tem recalibrador e sai com a probabilidade bruta
  # do modelo, como no produto.
  readRDS(system.file("model", "recalibradores_v1_4.rds", package = "incomeLato"))
}
#' @keywords internal
.carregar_ref <- function(nome) {
  read.csv(system.file("extdata", paste0(nome, ".csv"), package = "incomeLato"), stringsAsFactors = FALSE)
}

#' @keywords internal
.aviso_de_uso_emitido <- new.env()
.aviso_de_uso_emitido$emitido <- FALSE

#' @keywords internal
.emitir_aviso_de_uso <- function() {
  if (!isTRUE(.aviso_de_uso_emitido$emitido)) {
    warning(
      "USO: prob_bottom50/middle40/top10 sao PESO CONTINUO para composicao/associacao ",
      "(ex.: media ponderada por prob_bottom50 numa regressao). NAO classifique respondentes ",
      "individuais em bottom50/middle40/top10 por corte duro, e NAO interprete mean(prob_bottom50) ",
      "por pais-onda como o TAMANHO do bottom50 naquele pais-onda -- a margem agregada deriva ao ",
      "longo do tempo por razoes do proprio modelo, nao e uma serie temporal substantiva valida. ",
      "Ver attr(resultado, 'uso_recomendado') / attr(resultado, 'uso_proibido').",
      call. = FALSE
    )
    .aviso_de_uso_emitido$emitido <- TRUE
  }
}

#' Aplica o modelo de renda v1.5 ao banco preparado
#'
#' @param data data.frame retornado por [prepare_latinobarometro_income_inputs()].
#' @param model_version por enquanto so `"v1_5"` (o modelo congelado).
#' @param include_2024 se FALSE (padrao), remove a onda 2024 do resultado
#'   (problema de leitura/encoding conhecido). Se TRUE, mantem com um
#'   warning forte adicional.
#' @return `data` com as colunas anexadas: `prob_bottom50`,
#'   `prob_middle40`, `prob_top10`, `elegivel`, `motivo_exclusao`,
#'   `confianca_alvo_treino`, `flag_tier_reduzido`, `flag_piso_confianca`,
#'   `flag_fonte_censitaria`, `veredito_deriva_temporal`. Atributos
#'   `uso_recomendado`/`uso_proibido` anexados ao objeto.
#' @note As probabilidades sao PESO CONTINUO para uso em
#'   composicao/associacao (ex. media ponderada numa regressao). NAO
#'   classifique respondentes individuais em bottom50/middle40/top10 por
#'   corte duro. NAO interprete `mean(prob_bottom50)` por pais-onda como
#'   o TAMANHO do bottom50 naquele pais-onda -- a margem agregada
#'   deriva ao longo do tempo por razoes do proprio modelo, nao e uma
#'   serie temporal substantiva valida. Um warning com este aviso e
#'   emitido na primeira chamada da sessao.
#' @examples
#' # dado 100% sintetico -- nenhum valor de respondente real
#' sim <- simulate_latinobarometro_wave(2018, n = 30)
#' core <- harmonize_core_predictors(sim, 2018)
#' educ <- harmonize_educ3_latinobarometro(sim, 2018)
#' cw_pais <- read.csv(system.file("extdata", "country_crosswalk.csv", package = "incomeLato"))
#' banco <- data.frame(year = 2018, country_raw = core$country_raw,
#'   respondent_row_id = seq_len(nrow(sim)), weight = core$weight,
#'   sexo_final = core$sexo_final, idade_final = core$idade_final,
#'   educ3_final = educ$educ3_final, owns_car = core$owns_car,
#'   owns_washing_machine = core$owns_washing_machine,
#'   source_file = "sintetico", harmonization_flags = NA_character_)
#' banco <- merge(banco, cw_pais, by.x = "country_raw", by.y = "country_numeric", all.x = TRUE)
#' resultado <- predict_latinobarometro_income(banco)
#' head(resultado[, c("iso3", "prob_bottom50", "elegivel")])
#' @export
predict_latinobarometro_income <- function(data, model_version = "v1_5", include_2024 = FALSE) {
  req <- c("year", "iso3", "sexo_final", "idade_final", "educ3_final", "owns_car", "owns_washing_machine")
  faltando <- setdiff(req, names(data))
  if (length(faltando) > 0) stop("Colunas ausentes em `data` (esperado de prepare_latinobarometro_income_inputs()): ",
                                  paste(faltando, collapse = ", "), call. = FALSE)

  modelo <- .carregar_modelo(model_version)
  recal <- .carregar_recalibradores()
  confianca_pais <- .carregar_ref("confianca_por_pais")
  # regras_janela_onda e veredito_margem_pais vem de R/sysdata.rda
  # (data-raw/build_sysdata.R): so resultado categorico, sem estatistica.

  d <- data
  d$obs_id_temp <- seq_len(nrow(d))

  if (any(d$year == 2024)) {
    if (!include_2024) {
      d <- d[d$year != 2024, ]
      message("Onda 2024 removida por padrao (include_2024=FALSE) -- codigos de educacao inferidos, nao confirmados por rotulo.")
    } else {
      warning("include_2024=TRUE: onda 2024 incluida, mas os codigos de educacao dessa onda ",
              "foram INFERIDOS (nao confirmados diretamente) -- ver educ3_validated_years(). Use com cautela.", call. = FALSE)
    }
  }

  # guard-rail: se filtrar 2024 zerou o banco (usuario so tinha 2024), devolve
  # uma tabela vazia mas com a estrutura correta -- alguns metodos de
  # atribuicao do R (`d$col <- escalar`) falham especificamente em
  # data.frame de 0 linhas (achado real do R CMD check/teste 2024, Bloco 16),
  # entao tratar esse caso separado evita esse quirk em vez de contornar
  # cada atribuicao escalar individualmente.
  if (nrow(d) == 0) {
    d$elegivel <- logical(0); d$motivo_exclusao <- character(0)
    d$prob_bottom50 <- numeric(0); d$prob_middle40 <- numeric(0); d$prob_top10 <- numeric(0)
    d$confianca_alvo_treino <- character(0); d$flag_tier_reduzido <- logical(0)
    d$flag_piso_confianca <- logical(0); d$flag_fonte_censitaria <- logical(0)
    d$veredito_deriva_temporal <- character(0); d$flag_margin <- logical(0)
    d$obs_id_temp <- NULL
    .emitir_aviso_de_uso()
    attr(d, "uso_recomendado") <- "peso_continuo_para_composicao_associacao"
    attr(d, "uso_proibido") <- "classificacao_dura_individual; margem_agregada_como_serie_temporal_ou_estimando_substantivo"
    attr(d, "model_version") <- model_version
    return(d)
  }

  fora_da_janela <- paste(d$iso3, d$year) %in% paste(regras_janela_onda$iso3, regras_janela_onda$onda)

  d$escopo <- ifelse(d$iso3 %in% PAISES_ATIVOS, "ativo", ifelse(d$iso3 == "VEN", "quarentena", "fora_do_escopo"))
  d$elegivel <- d$escopo == "ativo" & !fora_da_janela

  d$motivo_exclusao <- NA_character_
  d$motivo_exclusao[d$escopo == "quarentena"] <- "venezuela_quarentena_arquitetural"
  d$motivo_exclusao[d$escopo == "fora_do_escopo"] <- "pais_fora_dos_15_ativos"
  d$motivo_exclusao[d$escopo == "ativo" & !d$elegivel] <- "fora_da_janela_temporal_valida_do_pais"

  preditor_faltando <- is.na(d$sexo_final) | is.na(d$idade_final) | is.na(d$educ3_final) |
    is.na(d$owns_car) | is.na(d$owns_washing_machine) | d$idade_final >= 120
  d$elegivel[preditor_faltando] <- FALSE
  d$motivo_exclusao[preditor_faltando & is.na(d$motivo_exclusao)] <- "preditor_ausente_ou_invalido"

  d$prob_bottom50 <- NA_real_; d$prob_middle40 <- NA_real_; d$prob_top10 <- NA_real_
  candidatos <- d[d$elegivel, ]

  if (nrow(candidatos) > 0) {
    for (pais in unique(candidatos$iso3)) {
      idx <- which(candidatos$iso3 == pais)
      sub <- candidatos[idx, ]; sub$country <- pais
      Xp <- .construir_X(sub, idade_center = modelo$idade_center, idade_scale = modelo$idade_scale)
      faltam <- setdiff(modelo$colnames_X, colnames(Xp))
      for (colf in faltam) Xp <- cbind(Xp, Matrix::Matrix(0, nrow(Xp), 1, sparse = TRUE, dimnames = list(NULL, colf)))
      Xp <- Xp[, modelo$colnames_X, drop = FALSE]

      pred <- stats::predict(modelo$modelo, newx = Xp, type = "response")[, , 1]
      colnames(pred) <- c("bottom50", "middle40", "top10")

      if (pais %in% names(recal$recalibradores)) {
        r <- .aplicar_recalibracao_3classes(recal$recalibradores[[pais]], pred[, "bottom50"], pred[, "middle40"], pred[, "top10"])
        candidatos$prob_bottom50[idx] <- r$p_bottom50; candidatos$prob_middle40[idx] <- r$p_middle40; candidatos$prob_top10[idx] <- r$p_top10
      } else {
        candidatos$prob_bottom50[idx] <- pred[, "bottom50"]; candidatos$prob_middle40[idx] <- pred[, "middle40"]; candidatos$prob_top10[idx] <- pred[, "top10"]
      }
    }
    d$prob_bottom50[match(candidatos$obs_id_temp, d$obs_id_temp)] <- candidatos$prob_bottom50
    d$prob_middle40[match(candidatos$obs_id_temp, d$obs_id_temp)] <- candidatos$prob_middle40
    d$prob_top10[match(candidatos$obs_id_temp, d$obs_id_temp)] <- candidatos$prob_top10
  }

  d <- merge(d, confianca_pais[, c("country", "confianca_alvo_treino", "piso_confianca_projeto")],
             by.x = "iso3", by.y = "country", all.x = TRUE)
  d <- merge(d, veredito_margem_pais, by = "iso3", all.x = TRUE)
  names(d)[names(d) == "veredito_deriva"] <- "veredito_deriva_temporal"

  # Os 15 paises ativos do v1.5 estao todos em tier_A_core5_educ3.
  d$flag_tier_reduzido <- FALSE
  d$flag_piso_confianca <- ifelse(is.na(d$piso_confianca_projeto), FALSE, d$piso_confianca_projeto)
  d$flag_fonte_censitaria <- d$iso3 == "PAN"
  # NA = margem nunca avaliada para o pais (caso do Mexico), nao "sem problema".
  d$flag_margin <- !d$margem_ok

  d <- d[order(d$obs_id_temp), ]
  d$obs_id_temp <- NULL; d$escopo <- NULL; d$piso_confianca_projeto <- NULL; d$margem_ok <- NULL
  rownames(d) <- NULL

  .emitir_aviso_de_uso()

  attr(d, "uso_recomendado") <- "peso_continuo_para_composicao_associacao"
  attr(d, "uso_proibido") <- "classificacao_dura_individual; margem_agregada_como_serie_temporal_ou_estimando_substantivo"
  attr(d, "model_version") <- model_version
  attr(d, "package_version") <- tryCatch(as.character(utils::packageVersion("incomeLato")), error = function(e) NA_character_)
  d
}
