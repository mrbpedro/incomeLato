# =============================================================================
# data-raw/build_crosswalk.R
# Bloco 15, TAREFA 1: constroi o crosswalk MINIMO de variaveis (so os
# conceitos que o modelo de renda usa), a partir do crosswalk geral em
# Latinobarometro/crosswalk_variaveis.csv (fora deste pacote/projeto,
# fonte read-only). Remove rotulo de pergunta/alternativa -- so nome de
# variavel e ano ficam.
#
# ATENCAO (achado do diagnostico, Bloco 14-15): o crosswalk geral tem uma
# coluna "education_r" (Respondent Education recoded), mas essa NAO e a
# mesma variavel usada para construir educ3_final no pipeline de renda
# (scripts/54) -- em 2020 elas divergem de proposito (reeduc_1 = item
# oficial recodificado, 7 categorias; s16 = item de anos de escolaridade,
# escala mais fina, escolhido deliberadamente pelo script 54). Por isso
# a fonte de verdade de EDUCACAO especificamente vem do proprio script
# 54 (ver build_educ3_years_table.R), NAO desta tabela geral.
# =============================================================================

suppressPackageStartupMessages(library(dplyr))

# Rodar a partir da raiz do pacote. INCOMELATO_PROJ_ROOT aponta para o
# projeto de pesquisa (padrao: ../.., o pacote vive em pacote/incomeLato/).
proj_root <- Sys.getenv("INCOMELATO_PROJ_ROOT", "../..")

# fonte read-only, fora do pacote -- nunca escrita, so lida
crosswalk_geral <- read.csv(
  file.path(proj_root, "..", "Latinobarometro", "crosswalk_variaveis.csv"),
  stringsAsFactors = FALSE
)

CONCEITOS_MODELO <- c("sex", "age", "country", "weight", "owns_car", "owns_washing_machine")

crosswalk_min <- crosswalk_geral %>%
  filter(harmonized_var %in% CONCEITOS_MODELO) %>%
  transmute(
    year = year,
    harmonized_concept = harmonized_var,
    raw_variable_name = original_var,
    source_wave = year,
    technical_note = ifelse(original_var == "" | is.na(original_var), "nao_perguntado_nesta_onda", NA_character_)
  ) %>%
  arrange(harmonized_concept, year)

# --- confirmar que NENHUM rotulo de pergunta/alternativa sobrou ---
stopifnot(!"original_label" %in% names(crosswalk_min))
stopifnot(!"has_value_labels" %in% names(crosswalk_min))

cat("=== T1 -- crosswalk minimo construido ===\n")
cat("Conceitos incluidos:", paste(sort(unique(crosswalk_min$harmonized_concept)), collapse = ", "), "\n")
cat("N linhas:", nrow(crosswalk_min), "\n")
cat("Colunas:", paste(names(crosswalk_min), collapse = ", "), "\n")
cat("Confirmado: sem coluna de rotulo de pergunta/alternativa.\n\n")
print(table(crosswalk_min$harmonized_concept))

write.csv(crosswalk_min, "inst/extdata/lb_income_predictor_crosswalk.csv", row.names = FALSE)

cat("\nSalvo: inst/extdata/lb_income_predictor_crosswalk.csv\n")
