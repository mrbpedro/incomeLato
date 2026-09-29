# CONTEXT.md — incomeLato

Mapa de contexto do **pacote**, para quem volta a este código depois de um
tempo. Não é o mapa da pesquisa que o originou (esse está em
`docs/ESTADO_E_RETOMADA.md` do projeto de pesquisa). Versão anterior deste
arquivo, que descrevia o pacote com o modelo v1.4, está em
`../incomeLato_backup_2026-09-29/CONTEXT.md`.

## O que o pacote faz

Aplica o modelo de renda **v1.5** (pooled15, 15 países, congelado, promovido
em 2026-07-13) aos microdados do Latinobarómetro que o usuário baixa. Devolve
`P(bottom50)`, `P(middle40)`, `P(top10)` por respondente, como peso contínuo
para análise agregada, nunca como classificação individual.

## O que vai dentro (e o que não vai)

| Objeto | Origem | Observação |
|---|---|---|
| `inst/model/modelo_income_quantile_v1_5.rds` | artefato promovido, copiado byte a byte | SHA-256 `c935cb87…`; metadado interno obsoleto corrigido só em memória (`.carregar_modelo()`) |
| `inst/model/recalibradores_v1_4.rds` | recalibradores v1.4, 14 países, sem model frame do LAPOP | SHA-256 `ace59730…`; México não tem recalibrador |
| `inst/extdata/*_crosswalk.csv`, `educ3_validated_years.csv` | nomes de variável por onda | metadado |
| `inst/extdata/confianca_por_pais.csv` | composição das fontes de treino | metadado; linha MEX acrescentada à mão |
| `R/sysdata.rda` | `data-raw/build_sysdata.R`, valores literais | veredito de margem por país; ondas fora da janela |

**Não vai:** microdados ou estatísticas calculadas sobre microdados
(Latinobarómetro, LAPOP, surveys de treino). Em 2026-09-29 saíram do pacote
e do futuro repositório `deriva_temporal_veredito_por_pais.csv`,
`bottom50_weights_classification_final.csv`, `tier_final_janela_por_pais.csv`
e `predictor_set_registry.csv` (este não era usado). Estão em
`../_archive_extdata_derivados_2026-09-29/`.

## Receita (por que modelo v1.5 com recalibradores v1.4)

É a receita do produto promovido do artigo. Testada contra as 369.999
predições: v1.5 bruto difere até 0,31; v1.5 + recalibradores v1.5 difere até
0,093; **v1.5 + recalibradores v1.4 nos 14 + México bruto difere 0**.

## Estado (2026-09-29)

- Golden file ponta a ponta (`data-raw/golden_file_validation_v1_5.R`):
  369.999/369.999, 1995–2024, max |Δ| = 0. Única divergência de flag:
  `flag_piso_confianca` do MEX (NA no produto, FALSE no pacote, deliberado).
- `R CMD check --as-cran`: 0 erros, 0 warnings; NOTEs só de ambiente
  (sem pandoc local) e do DOI ainda placeholder.
- 42 testes `testthat`, todos com dado sintético, incluindo regressão contra
  `tests/testthat/fixtures/regressao_v1_5.rds` e o caminho de onda única.
- `income_lato()` aceita arquivo único ou pasta e termina com um resumo
  (`message()`). Onda única real conferida: 2018, 16.901/16.901, Δ = 0.
- Todos os scripts de `data-raw/` reconstroem os artefatos byte a byte, sem
  caminho absoluto (`INCOMELATO_PROJ_ROOT`, padrão `../..`).
- Onda 2024 lida (`readstata13`, `convert.factors = FALSE`); continua fora
  por padrão porque os códigos de educação são inferidos.

## Pendências

1. Validação por classe (bottom50/middle40/top10) sob v1.5 — primeira issue,
   v0.1.1. O README cita a da v1.4, rotulada como tal.
2. Repositório GitHub, tag `v0.1.0`, DOI Zenodo (substituir
   `10.5281/zenodo.XXXXXXX` em `inst/CITATION`), `packages.json` do
   r-universe, URL/BugReports no DESCRIPTION — ações do autor.
3. Formato oficial de citação do Latinobarómetro por rodada — o site não o
   publica nas páginas consultadas; `inst/CITATION` traz um modelo genérico.
4. Desde a v0.1.1, mensagens, avisos, ajuda das funções e códigos de
   `motivo_exclusao` estão em inglês. Os nomes de colunas (`elegivel`,
   `motivo_exclusao`, `veredito_deriva_temporal` etc.) continuam em
   português; padronizar exige aviso de depreciação numa versão futura.

## Estender para uma onda nova

Acrescentar a onda em `inst/extdata/lb_income_predictor_crosswalk.csv` e
`inst/extdata/educ3_validated_years.csv` (via os scripts de `data-raw/`),
validar contra o codebook da onda. Sem isso o pacote recusa a onda com erro.
