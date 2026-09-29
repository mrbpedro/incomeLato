# =============================================================================
# build_sysdata.R
# Gera R/sysdata.rda com duas tabelas minimas, escritas A MAO (valores
# literais, nao lidos de arquivo). Sao RESULTADOS categoricos da validacao do
# artigo, sem nenhuma estatistica subjacente e sem dado do Latinobarometro,
# do LAPOP ou das surveys de treino. Substituem, desde 2026-09-29, tres CSV
# que carregavam as estatisticas (deriva_temporal_veredito_por_pais,
# bottom50_weights_classification_final, tier_final_janela_por_pais) e que
# ficaram fora do repositorio.
#
# Rodar a partir da raiz do pacote: Rscript data-raw/build_sysdata.R
# =============================================================================

# Veredito da validacao externa (LAPOP) da margem agregada de P(bottom50), por
# pais. margem_ok = TRUE so onde a margem foi validada sem ressalva. O Mexico
# nao tem linha: a margem nunca foi avaliada para ele (flag_margin = NA).
veredito_margem_pais <- data.frame(
  iso3 = c("ARG", "BOL", "BRA", "CHL", "COL", "CRI", "ECU",
           "HND", "NIC", "PAN", "PER", "PRY", "SLV", "URY"),
  veredito_deriva = c("DERIVA_DIRECIONAL_GRANDE", "DERIVA_DIRECIONAL_GRANDE",
                      "DERIVA_DIRECIONAL_MODERADA", "DERIVA_DIRECIONAL_GRANDE",
                      "DERIVA_DIRECIONAL_GRANDE", "DERIVA_DIRECIONAL_GRANDE",
                      "DERIVA_DIRECIONAL_GRANDE", "RUIDO_AMOSTRAL",
                      "DERIVA_DIRECIONAL_GRANDE", "DERIVA_DIRECIONAL_MODERADA",
                      "DERIVA_DIRECIONAL_GRANDE", "DERIVA_DIRECIONAL_GRANDE",
                      "DERIVA_DIRECIONAL_GRANDE", "DERIVA_DIRECIONAL_GRANDE"),
  margem_ok = c(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE),
  stringsAsFactors = FALSE
)

# Ondas do Latinobarometro em que um pais ativo NAO e imputado. Qualquer
# combinacao pais-onda fora desta lista e elegivel (a onda 2024 tem regra
# propria, via include_2024).
regras_janela_onda <- data.frame(
  iso3 = c("CRI", "CRI", "CRI", "CRI",
           "SLV", "SLV", "SLV",
           "ECU", "ECU",
           "PRY",
           "HND", "HND",
           "NIC", "NIC",
           "BOL",
           "MEX", "MEX"),
  onda = c(1995, 1996, 1997, 1998,
           1995, 1996, 1997,
           1995, 1997,
           1996,
           1995, 2007,
           1995, 1998,
           1995,
           1996, 2024),
  motivo = c(rep("borda_esquerda: fora da janela de aplicacao do pais", 4),
             rep("borda_esquerda: fora da janela de aplicacao do pais", 3),
             "borda_esquerda: fora da janela de aplicacao do pais",
             "onda_isolada: preditor indisponivel nesta onda",
             "onda_isolada: preditor indisponivel nesta onda",
             "borda_esquerda: fora da janela de aplicacao do pais",
             "onda_isolada: preditor ausente no arquivo original (recusa do respondente)",
             "borda_esquerda: fora da janela de aplicacao do pais",
             "onda_isolada: posse de lavadora acima do limiar de faltantes",
             "borda_esquerda: fora da janela de aplicacao do pais",
             "onda_isolada: educacao acima do limiar de faltantes",
             "onda_isolada: codificacao de educacao rejeitada"),
  stringsAsFactors = FALSE
)

stopifnot(!anyDuplicated(veredito_margem_pais$iso3),
          !anyDuplicated(paste(regras_janela_onda$iso3, regras_janela_onda$onda)))

save(veredito_margem_pais, regras_janela_onda, file = "R/sysdata.rda", compress = "bzip2", version = 2)
