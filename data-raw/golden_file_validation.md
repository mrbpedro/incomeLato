# Golden file validation — v0.1, 2026-07-23

> **Registro histórico do modelo v1.4 (14 países).** O pacote passou a
> empacotar o modelo v1.5 (15 países) em 2026-09-29. A validação vigente é
> `golden_file_validation_v1_5.R`: 369.999/369.999 respondentes casados
> (1995–2024), diferença máxima 0 nas três probabilidades. O arquivo de 2024
> passou a ser lido (`readstata13` com `convert.factors = FALSE`); a
> "causa raiz" descrita abaixo para 2024 foi resolvida assim.

Comparação de `prepare_latinobarometro_income_inputs() → predict_latinobarometro_income()`
contra o produto v1.4 congelado (`data/output/predictions/latinobarometro_prob_bottom50_core5_lb_educ3_v1_4_per_20260711.rds`),
rodando sobre os `.dta` reais em `data/raw/latinobarometro/extracted/`.

## Resultado — todas as 23 ondas 1995-2023 (2024 excluída, comportamento padrão)

| Critério | Resultado |
|---|---|
| N elegível pacote vs. N produto v1.4 | 329.326 / 329.326 (idêntico) |
| N casado no join por (year, within_year_pos, iso3) | 329.326 (100%) |
| Correlação prob_bottom50 | 1,00000000 |
| Diferença absoluta máxima | 0,00000000 |
| Diferença absoluta média | 0,0000000000 |
| N com diferença > 0,001 | 0 |
| `educ3_final` divergente | 0 de 329.326 |
| Flags (`confianca_alvo_treino`, `flag_tier_reduzido`, `flag_margin`, `flag_fonte_censitaria`) divergentes | 0 em todas |
| N por país-onda idêntico | Sim, em todos os pares país-onda |

**Veredito: PASSOU — reprodução exata**, não aproximada.

## Bug encontrado e corrigido durante a validação

A primeira rodada da comparação (script de teste, não o pacote) deu
correlação 0,11 e diferenças de até 0,90 — alarmante à primeira vista.
Investigação: o produto v1.4 usa `within_year_pos` calculado sobre o
arquivo pooled **completo, não filtrado** (`Latinobarometro_harmonizado_1995_2024.rds`,
19 países); o script de comparação inicial recalculou essa posição a
partir do produto v1.4 **já filtrado** aos 14 países ativos elegíveis —
uma chave de junção diferente da original, o que embaralhava a
correspondência linha a linha mesmo com os valores computados
corretamente. Corrigido reconstruindo `within_year_pos` a partir do
arquivo pooled completo (mesma fórmula do `scripts/117`:
`ave(main$obs_id, main$year, FUN = function(x) x - min(x) + 1)`) antes
de comparar. **O bug estava no script de teste, não no pacote** — as 10
primeiras linhas de ARG/2018 já batiam exatamente antes da correção,
confirmando que a lógica de harmonização e predição do pacote estava
certa desde o início; só a chave de comparação do teste estava errada.

## Escopo do teste

- Todas as 23 ondas com dado real disponível em `extracted/` (1995-2023).
- Todos os 14 países ativos + confirmação de exclusão correta de
  Venezuela/México/Guatemala/República Dominicana/Espanha (0 linhas
  elegíveis para todos eles, como esperado).
- Os 3 esquemas de educação (`cat7`, `cat3`, `years17`) cobertos.

## Reconfirmação pós-acabamento — Bloco 16, 2026-07-24

Depois de `devtools::document()` (NAMESPACE/roxygen), da licença MIT, e
das correções encontradas pelo `R CMD check` e pelo teste real de 2024
(import explícito de `glmnet`/`utils::read.csv`; guard-rail de 0 linhas
em `predict_latinobarometro_income()`; detecção de coluna-`factor` em
`harmonize_core_predictors()`; isolamento por onda em
`prepare_latinobarometro_income_inputs()` para não derrubar o lote
inteiro), **o golden file test foi rodado de novo, do zero, nas mesmas
23 ondas** — resultado idêntico ao original: N casado 329.326/329.326,
correlação 1,00000000, diferença absoluta máxima 0,00000000. Nenhuma
das correções de acabamento tocou a lógica estatística validada.

## Teste real contra a onda 2024 (Bloco 16, Tarefa 4)

Rodado sobre `data/raw/latinobarometro/extracted/Latinobarometro_2024_Stata_eng_v20250817.dta`.

| Modo | Comportamento observado |
|---|---|
| `prepare_latinobarometro_income_inputs(anos=2024)` sozinho | Erro informativo: `"Nao foi possivel ler o preditor 'sex' (coluna 'SEXO', ano 2024): veio como factor..."` -- identifica a coluna e a causa exata. |
| `prepare_latinobarometro_income_inputs(anos=c(2020,2024))` | 2024 descartada com `warning()` ("IGNORADA"), 2020 processada normalmente (20.204 linhas) -- lote não é derrubado por uma onda quebrada. |
| `predict_latinobarometro_income(..., include_2024 = FALSE)` (padrão) | 2024 removida antes de prever; se o banco só tinha 2024, retorna 0 linhas sem erro. |
| `predict_latinobarometro_income(..., include_2024 = TRUE)` | Mantém 2024, emite warning adicional citando confiança reduzida -- mas ainda falha na harmonização se `haven`/`readstata13` devolver `factor` em vez de código numérico (não há como prever sem o dado correto). |

**Causa raiz encontrada** (achado real, não estava documentado antes do
Bloco 16): não é só a educação que tem confiança reduzida em 2024 --
`readstata13` devolve **`SEXO` e `IDENPA`** como `factor` com rótulo de
texto embutido (`"Woman"`, `"[%32%] Argentina"`), não código numérico.
`as.numeric()` sobre esse `factor` extrairia a posição do nível
silenciosamente (não vira `NA`, vira um número plausível mas errado) --
por isso a detecção em `harmonize_core_predictors()` verifica
explicitamente `is.factor()` antes de converter, e para com erro
nomeado em vez de prosseguir com valor errado. Não corrigido (não é
escopo desta tarefa) -- só detectado e reportado corretamente.
