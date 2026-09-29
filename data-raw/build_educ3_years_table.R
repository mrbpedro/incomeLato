# =============================================================================
# data-raw/build_educ3_years_table.R
# Bloco 15, TAREFA 3: tabela de anos VALIDADOS para educ3_final, extraida
# diretamente de scripts/54_construir_educ3_final_latinobarometro.R (a
# fonte de verdade que gerou o educ3_final usado no produto v1.4
# congelado -- NAO o crosswalk geral "education_r", que aponta para uma
# variavel diferente em 2020, ver nota no build_crosswalk.R).
#
# Cada linha = 1 onda validada, com a variavel bruta, o esquema de
# recodificacao (cat7/cat3/years17/ambos_2024) e uma nota de confianca.
# Anos FORA desta tabela NAO tem lógica validada -- a funcao de
# harmonizacao deve recusar/avisar, nunca adivinhar (guard-rail da T3).
# =============================================================================

suppressPackageStartupMessages(library(dplyr))

educ3_anos_validados <- tibble::tribble(
  ~year, ~raw_variable_name, ~scheme, ~respondent_or_head, ~confidence_note,
  1995, "s20",      "cat7",    "respondent", "rotulo e codigo confirmados diretamente na onda",
  1996, "s16a",     "cat7",    "respondent", "rotulo e codigo confirmados diretamente na onda",
  1997, "s12a",     "cat7",    "respondent", "rotulo e codigo confirmados diretamente na onda",
  1998, "s14a",     "cat7",    "respondent", "rotulo e codigo confirmados diretamente na onda",
  2000, "reeduc1",  "cat7",    "respondent", "rotulo e codigo confirmados diretamente na onda",
  2001, "reeduc1",  "cat7",    "respondent", "rotulo e codigo confirmados diretamente na onda",
  2002, "reeduc1",  "cat7",    "respondent", "rotulo e codigo confirmados diretamente na onda",
  2003, "s18",      "cat7",    "respondent", "rotulo e codigo confirmados diretamente na onda",
  2004, "reeduc1",  "cat7",    "respondent", "rotulo e codigo confirmados diretamente na onda",
  2005, "reeduc1",  "cat7",    "respondent", "rotulo e codigo confirmados diretamente na onda",
  2006, "reeduc1",  "cat7",    "respondent", "rotulo e codigo confirmados diretamente na onda",
  2007, "reeduc1",  "cat7",    "respondent", "rotulo e codigo confirmados diretamente na onda",
  2008, "reeduc1",  "cat7",    "respondent", "rotulo e codigo confirmados diretamente na onda",
  2009, "reeduc1",  "cat7",    "respondent", "rotulo e codigo confirmados diretamente na onda",
  2010, "REEDUC1",  "cat7",    "respondent", "rotulo e codigo confirmados diretamente na onda",
  2011, "REEDUC1",  "cat7",    "respondent", "rotulo e codigo confirmados diretamente na onda",
  2013, "REEDUC_1", "cat7",    "respondent", "rotulo e codigo confirmados diretamente na onda",
  2015, "REEDUC_1", "cat7",    "respondent", "rotulo e codigo confirmados diretamente na onda",
  2016, "REEDUC_1", "cat7",    "respondent", "rotulo e codigo confirmados diretamente na onda",
  2017, "REEDUC_1", "cat7",    "respondent", "rotulo e codigo confirmados diretamente na onda",
  2018, "REEDUC.1", "cat3",    "respondent", "rotulo e codigo confirmados diretamente na onda -- esquema 3cat oficial",
  2020, "s16",      "years17", "respondent", "escolhida deliberadamente sobre reeduc_1 (escala mais fina, anos de escolaridade); rotulo e codigo confirmados",
  2023, "S11",      "years17", "respondent", "REEDUC_1/S21B nao existem ou sao do chefe de familia -- S11 e do respondente, 100% cobertura, confirmado",
  2024, "REEDUC.1;S11", "ambos_2024", "respondent", "CONFIANCA REDUZIDA -- readstata13 nao recuperou rotulos deste arquivo; codigos INFERIDOS por ordem historica identica em 9 ondas anteriores, nao confirmacao direta"
)

stopifnot(!anyDuplicated(educ3_anos_validados$year))

cat("=== T3 -- anos validados para educ3_final (fonte: scripts/54, NAO o crosswalk geral) ===\n")
print(as.data.frame(educ3_anos_validados %>% dplyr::select(year, raw_variable_name, scheme, confidence_note)), row.names = FALSE)
cat("\nN anos validados:", nrow(educ3_anos_validados), "\n")
cat("Anos NAO cobertos (qualquer ano fora desta lista, incl. ondas futuras): SEM logica validada -- funcao deve recusar.\n")

# Rodar a partir da raiz do pacote.
write.csv(educ3_anos_validados, "inst/extdata/educ3_validated_years.csv", row.names = FALSE)
cat("\nSalvo: inst/extdata/educ3_validated_years.csv\n")
