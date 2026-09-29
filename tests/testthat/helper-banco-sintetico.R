# Banco no formato de prepare_latinobarometro_income_inputs(), montado a
# partir do gerador sintetico (nenhum valor de respondente real).
banco_sintetico <- function(ano = 2018, n = 10, seed = 42) {
  sim <- simulate_latinobarometro_wave(ano, n = n, seed = seed)
  core <- harmonize_core_predictors(sim, ano)
  educ <- harmonize_educ3_latinobarometro(sim, ano)
  cw_pais <- read.csv(system.file("extdata", "country_crosswalk.csv", package = "incomeLato"), stringsAsFactors = FALSE)
  banco <- data.frame(year = ano, country_raw = core$country_raw, respondent_row_id = seq_len(nrow(sim)),
                      weight = core$weight, sexo_final = core$sexo_final, idade_final = core$idade_final,
                      educ3_final = educ$educ3_final, owns_car = core$owns_car,
                      owns_washing_machine = core$owns_washing_machine, source_file = "sintetico",
                      harmonization_flags = NA_character_, stringsAsFactors = FALSE)
  banco <- merge(banco, cw_pais, by.x = "country_raw", by.y = "country_numeric", all.x = TRUE)
  banco[order(banco$country_raw, banco$respondent_row_id), ]
}
