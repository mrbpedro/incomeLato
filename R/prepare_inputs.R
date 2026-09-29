# =============================================================================
# prepare_inputs.R
# Bloco 15, TAREFA 4: funcao publica que le os arquivos brutos do
# Latinobarometro (baixados pelo USUARIO, nunca distribuidos com o
# pacote), harmoniza os preditores do modelo de renda, e devolve um
# banco minimo pronto para predict_latinobarometro_income().
# =============================================================================

ONDAS_VALIDAS <- c(1995, 1996, 1997, 1998, 2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007,
                    2008, 2009, 2010, 2011, 2013, 2015, 2016, 2017, 2018, 2020, 2023, 2024)

#' @keywords internal
.ler_onda <- function(path) {
  ext <- tolower(tools::file_ext(path))
  if (ext == "dta") {
    resultado <- tryCatch(as.data.frame(haven::read_dta(path, encoding = "latin1")), error = function(e) NULL)
    if (is.null(resultado)) {
      if (!requireNamespace("readstata13", quietly = TRUE)) {
        stop("Arquivo ", basename(path), " exige o pacote 'readstata13' (haven falhou ao ler). Instale com install.packages('readstata13').", call. = FALSE)
      }
      # convert.factors = FALSE: devolve os codigos numericos, como o haven.
      # Com o padrao (TRUE), variaveis rotuladas viram factor e SEXO/IDENPA
      # de 2024 chegam como texto ("Woman", "[%32%] Argentina").
      resultado <- readstata13::read.dta13(path, convert.factors = FALSE, nonint.factors = FALSE)
    }
    return(resultado)
  }
  if (ext == "sav") return(as.data.frame(haven::read_sav(path)))
  stop("Formato nao suportado: ", ext, " (esperado .dta ou .sav). Se o arquivo baixado e .zip, descompacte antes.", call. = FALSE)
}

#' @keywords internal
.detectar_ano_do_arquivo <- function(filename) {
  achados <- regmatches(filename, gregexpr("(19|20)[0-9]{2}", filename))[[1]]
  achados <- as.numeric(achados)
  achados <- achados[achados %in% ONDAS_VALIDAS]
  if (length(achados) == 0) return(NA_integer_)
  achados[1]
}

#' Prepara os preditores de renda a partir dos microdados brutos do usuario
#'
#' Le arquivos `.dta` do Latinobarometro (baixados pelo usuario da fonte
#' oficial -- este pacote NAO distribui microdados), detecta a onda pelo
#' nome do arquivo, harmoniza os preditores do modelo de renda
#' (sexo/idade/carro/lavadora/pais/peso via crosswalk minimo; educacao
#' via [harmonize_educ3_latinobarometro()], restrita a anos validados).
#'
#' @param raw_dir diretorio com os arquivos `.dta` ou `.sav` brutos, ou o
#'   caminho de um unico arquivo. Um arquivo por onda, com o ano em algum
#'   lugar do nome (ex. "Latinobarometro_2018_Eng_Stata_v20190303.dta"). Se
#'   a mesma onda estiver nos dois formatos, deixe so um no diretorio. Para
#'   um arquivo unico sem o ano no nome, informe-o em `years`.
#' @param years vetor de anos a processar (default: todos os arquivos
#'   encontrados em `raw_dir`).
#' @param countries vetor de codigos ISO3 para filtrar (default: todos).
#' @return data.frame com `year, iso3, country_raw, respondent_row_id,
#'   weight, sexo_final, idade_final, educ3_final, owns_car,
#'   owns_washing_machine, source_file, harmonization_flags`. Atributos
#'   `ondas_detectadas` (ondas encontradas e solicitadas) e
#'   `ondas_ignoradas` (as que falharam na harmonizacao).
#' @examples
#' # exemplo runnable com dado 100% sintetico gravado como .dta
#' # temporario -- nenhum microdado real do Latinobarometro e usado
#' # ou distribuido. Em uso real, `raw_dir` aponta para arquivos .dta
#' # baixados pelo usuario em latinobarometro.org. Ano 2011 escolhido
#' # aqui por ter nomes de variavel bruta sem ponto (ex. "REEDUC1"),
#' # compativel com haven::write_dta(); alguns anos (ex. 2018,
#' # "REEDUC.1") tem ponto no nome original e nao podem ser
#' # regravados como .dta por essa via -- nao afeta a leitura normal
#' # de arquivos baixados do Latinobarometro, so a escrita sintetica
#' # deste exemplo.
#' sim <- simulate_latinobarometro_wave(2011, n = 30)
#' tmp_dir <- tempfile("lb_sim_"); dir.create(tmp_dir)
#' haven::write_dta(sim, file.path(tmp_dir, "Latinobarometro_2011_sim.dta"))
#' banco <- prepare_latinobarometro_income_inputs(tmp_dir, years = 2011)
#' str(banco)
#' unlink(tmp_dir, recursive = TRUE)
#' @export
prepare_latinobarometro_income_inputs <- function(raw_dir, years = NULL, countries = NULL) {
  arquivo_unico <- file.exists(raw_dir) && !dir.exists(raw_dir)
  if (arquivo_unico) {
    arquivos <- raw_dir
  } else {
    if (!dir.exists(raw_dir)) stop("Diretorio ou arquivo nao encontrado: ", raw_dir, call. = FALSE)
    arquivos <- list.files(raw_dir, pattern = "\\.(dta|sav)$", full.names = TRUE, ignore.case = TRUE)
    if (length(arquivos) == 0) stop("Nenhum arquivo .dta ou .sav encontrado em ", raw_dir, call. = FALSE)
  }

  anos_arquivo <- vapply(basename(arquivos), .detectar_ano_do_arquivo, numeric(1))
  if (arquivo_unico && is.na(anos_arquivo) && length(years) == 1 && years %in% ONDAS_VALIDAS) anos_arquivo <- years
  if (any(is.na(anos_arquivo))) {
    warning("Nao foi possivel detectar o ano destes arquivos (ignorados): ",
            paste(basename(arquivos)[is.na(anos_arquivo)], collapse = ", "), call. = FALSE)
  }
  mapa <- data.frame(arquivo = arquivos, ano = anos_arquivo, stringsAsFactors = FALSE)
  mapa <- mapa[!is.na(mapa$ano), ]

  if (!is.null(years)) mapa <- mapa[mapa$ano %in% years, ]
  if (nrow(mapa) == 0) stop("Nenhum arquivo correspondente aos anos solicitados.", call. = FALSE)
  if (anyDuplicated(mapa$ano)) {
    stop("Mais de um arquivo para a(s) onda(s) ", paste(unique(mapa$ano[duplicated(mapa$ano)]), collapse = ", "),
         " em ", raw_dir, ". Deixe um arquivo por onda.", call. = FALSE)
  }

  cw_pais <- read.csv(system.file("extdata", "country_crosswalk.csv", package = "incomeLato"), stringsAsFactors = FALSE)

  resultado <- lapply(seq_len(nrow(mapa)), function(i) {
    ano <- mapa$ano[i]; arq <- mapa$arquivo[i]
    d <- .ler_onda(arq)
    n <- nrow(d)

    core <- tryCatch(
      harmonize_core_predictors(d, ano),
      error = function(e) {
        warning("Onda ", ano, " (", basename(arq), ") IGNORADA -- falha ao harmonizar preditores: ",
                conditionMessage(e), call. = FALSE)
        NULL
      }
    )
    if (is.null(core)) return(NULL)

    educ <- tryCatch(
      harmonize_educ3_latinobarometro(d, ano, on_unvalidated_year = "error"),
      error = function(e) {
        warning("Educacao nao processada para o ano ", ano, ": ", conditionMessage(e), call. = FALSE)
        data.frame(educ3_final = rep(NA_character_, n), educ3_source_variable = NA_character_,
                   educ3_source_scheme = NA_character_, educ3_quality_flag = "erro_educacao")
      }
    )

    saida <- data.frame(
      year = ano,
      country_raw = core$country_raw,
      respondent_row_id = seq_len(n),
      weight = core$weight,
      sexo_final = core$sexo_final,
      idade_final = core$idade_final,
      educ3_final = educ$educ3_final,
      owns_car = core$owns_car,
      owns_washing_machine = core$owns_washing_machine,
      source_file = basename(arq),
      harmonization_flags = mapply(function(a, b) paste(stats::na.omit(c(a, b)), collapse = ";"),
                                    core$harmonization_flags, educ$educ3_quality_flag),
      stringsAsFactors = FALSE
    )
    saida$harmonization_flags[!nzchar(saida$harmonization_flags)] <- NA_character_
    saida <- merge(saida, cw_pais, by.x = "country_raw", by.y = "country_numeric", all.x = TRUE)
    saida
  })

  ondas_ignoradas <- mapa$ano[vapply(resultado, is.null, logical(1))]
  resultado <- Filter(Negate(is.null), resultado)
  if (length(resultado) == 0) stop("Nenhuma onda pode ser processada (todas falharam na harmonizacao de preditores). Ver warnings.", call. = FALSE)
  banco <- do.call(rbind, resultado)
  banco <- banco[order(banco$year, banco$country_raw, banco$respondent_row_id), ]
  if (!is.null(countries)) banco <- banco[banco$iso3 %in% countries, ]
  banco <- banco[, c("year", "iso3", "country_raw", "respondent_row_id", "weight",
                      "sexo_final", "idade_final", "educ3_final", "owns_car", "owns_washing_machine",
                      "source_file", "harmonization_flags")]
  rownames(banco) <- NULL
  attr(banco, "ondas_detectadas") <- sort(mapa$ano)
  attr(banco, "ondas_ignoradas") <- sort(ondas_ignoradas)
  banco
}
