# =============================================================================
# harmonize_predictors.R
# Bloco 15, TAREFA 4 (parte 1): harmoniza os 4 preditores nao-educacao
# que vem do crosswalk minimo (sexo, idade, carro, lavadora) + pais/peso,
# consultando inst/extdata/lb_income_predictor_crosswalk.csv. Reaproveita
# o normalizador find_col() de Latinobarometro/R_00_utils.R (candidatos
# de nome, escolhe o que existir, normalizando maiuscula/pontuacao).
# =============================================================================

#' @keywords internal
.crosswalk_min <- function() {
  path <- system.file("extdata", "lb_income_predictor_crosswalk.csv", package = "incomeLato")
  read.csv(path, stringsAsFactors = FALSE)
}

#' @keywords internal
#' Reimplementacao do find_col() de Latinobarometro/R_00_utils.R -- acha,
#' entre candidatos, a coluna presente em df (normalizando case/pontuacao).
.find_col <- function(df, candidates) {
  candidates <- candidates[!is.na(candidates) & nzchar(candidates)]
  if (length(candidates) == 0) return(NA_character_)
  nms <- names(df)
  norm <- function(s) tolower(gsub("[._]", "", s))
  nms_norm <- norm(nms)
  for (cand in candidates) {
    hit <- which(nms_norm == norm(cand))
    if (length(hit) >= 1) return(nms[hit[1]])
  }
  NA_character_
}

#' Harmoniza os preditores sexo/idade/carro/lavadora/pais/peso para uma onda
#'
#' @param raw_data data.frame bruto de uma onda do Latinobarometro.
#' @param year ano da onda.
#' @return data.frame com `sexo_final`, `idade_final`, `owns_car`,
#'   `owns_washing_machine`, `country_raw`, `weight`, e uma coluna de
#'   flags por preditor ausente.
#' @examples
#' # dado 100% sintetico -- nenhum valor de respondente real
#' sim <- simulate_latinobarometro_wave(2018, n = 50)
#' core <- harmonize_core_predictors(sim, 2018)
#' str(core)
#' @export
harmonize_core_predictors <- function(raw_data, year) {
  cw <- .crosswalk_min()
  cw_onda <- cw[cw$year == year, ]
  if (nrow(cw_onda) == 0) {
    stop("Nenhuma entrada do crosswalk minimo para o ano ", year,
         ". Anos cobertos: ", paste(sort(unique(cw$year)), collapse = ", "), ".", call. = FALSE)
  }

  achar_var <- function(conceito) {
    linha <- cw_onda[cw_onda$harmonized_concept == conceito, ]
    if (nrow(linha) == 0 || is.na(linha$raw_variable_name[1]) || !nzchar(linha$raw_variable_name[1])) return(NA_character_)
    .find_col(raw_data, linha$raw_variable_name[1])
  }

  col_sex <- achar_var("sex"); col_age <- achar_var("age")
  col_country <- achar_var("country"); col_weight <- achar_var("weight")
  col_car <- achar_var("owns_car"); col_wash <- achar_var("owns_washing_machine")

  n <- nrow(raw_data)
  flags <- character(0)

  # FALHA INFORMATIVA (Bloco 16, T4): as.numeric() sobre um factor extrai a
  # POSICAO do nivel, nao o codigo real -- silenciosamente produz numeros
  # errados (nao NA), o que pode passar despercebido ate o join com um
  # crosswalk numerico falhar 100% das linhas rio abaixo (achado real:
  # a onda 2024 tem IDENPA como factor com rotulos "[%32%] Argentina",
  # nao um codigo numerico direto -- problema de leitura conhecido daquela
  # onda especificamente). Detecta e para, em vez de coagir silenciosamente.
  get_num <- function(col, conceito) {
    if (is.na(col)) return(rep(NA_real_, n))
    valor <- raw_data[[col]]
    if (is.factor(valor)) {
      stop(
        "Nao foi possivel ler o preditor '", conceito, "' (coluna '", col, "', ano ", year, "): ",
        "veio como factor com rotulos de texto (ex.: \"", as.character(valor[1]), "\"), ",
        "nao um codigo numerico direto. as.numeric() sobre um factor extrairia a POSICAO ",
        "do nivel, nao o codigo real -- silenciosamente errado, nao NA. Isso e um problema de ",
        "leitura conhecido em algumas ondas (ex. 2024, onde IDENPA vem como \"[%32%] Argentina\"). ",
        "Nao ha correcao automatica nesta versao -- extraia o codigo manualmente (ex. via regex no ",
        "rotulo) antes de chamar harmonize_core_predictors(), ou reporte a onda como nao suportada.",
        call. = FALSE
      )
    }
    suppressWarnings(as.numeric(valor))
  }

  sex_raw <- get_num(col_sex, "sex")
  sexo_final <- dplyr::case_when(sex_raw == 1 ~ "hombre", sex_raw == 2 ~ "mujer", TRUE ~ NA_character_)
  if (is.na(col_sex)) flags <- c(flags, "sexo_coluna_nao_encontrada")

  idade_final <- get_num(col_age, "age")
  idade_final[idade_final <= 0 | idade_final >= 120] <- NA
  if (is.na(col_age)) flags <- c(flags, "idade_coluna_nao_encontrada")

  car_raw <- get_num(col_car, "owns_car"); car_raw[car_raw < 0] <- NA
  owns_car <- ifelse(is.na(car_raw), NA, car_raw == 1)
  if (is.na(col_car)) flags <- c(flags, "owns_car_coluna_nao_encontrada")

  wash_raw <- get_num(col_wash, "owns_washing_machine"); wash_raw[wash_raw < 0] <- NA
  owns_washing_machine <- ifelse(is.na(wash_raw), NA, wash_raw == 1)
  if (is.na(col_wash)) flags <- c(flags, "owns_washing_machine_coluna_nao_encontrada")

  country_raw <- get_num(col_country, "country")
  if (is.na(col_country)) flags <- c(flags, "country_coluna_nao_encontrada")

  weight <- get_num(col_weight, "weight")
  if (is.na(col_weight)) flags <- c(flags, "weight_coluna_nao_encontrada")

  data.frame(
    sexo_final = sexo_final, idade_final = idade_final,
    owns_car = owns_car, owns_washing_machine = owns_washing_machine,
    country_raw = country_raw, weight = weight,
    harmonization_flags = if (length(flags) == 0) NA_character_ else paste(flags, collapse = ";"),
    stringsAsFactors = FALSE
  )
}
