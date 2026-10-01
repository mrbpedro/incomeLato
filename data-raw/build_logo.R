# =============================================================================
# build_logo.R
# Hex sticker do incomeLato: mapa da America Latina (Natural Earth, dominio
# publico) e o nome do pacote, em azuis amostrados de uma imagem de referencia
# fornecida pelo autor. So as cores: nenhum logotipo, tipografia ou elemento
# grafico do Latinobarometro, para nao sugerir vinculo institucional.
#
# hexSticker, rnaturalearth, rnaturalearthdata, sf, magick e rsvg NAO entram em
# Imports nem Suggests: o script roda fora do pacote. Em 2026-10-01 foram
# instalados numa biblioteca local do projeto (../_logo_2026-10-01/_lib), que
# este script acrescenta ao .libPaths() se existir.
#
# Uso, a partir da raiz do pacote:
#   Rscript data-raw/build_logo.R
# Saida, em ../_logo_2026-10-01/final/:
#   incomeLato_logo_silhueta.png/.svg   o logo (versao escolhida em 2026-10-01)
#   social_preview_silhueta.png         social preview do GitHub (1280x640)
# PNG e SVG com fundo transparente fora do hexagono. man/figures/logo.png e
# este PNG redimensionado para 240 px de largura (usethis::use_logo()).
#
# Variante descartada em 2026-10-01: os 15 paises do pacote em destaque. Em
# tamanho pequeno, Venezuela e Guianas viravam uma mancha escura que parecia
# um pedaco faltando no mapa, e ela realcava uma limitacao (a quarentena da
# Venezuela), nao a identidade do pacote. O codigo fica abaixo (mapa_15),
# fora do laco de geracao; os arquivos estao em ../_logo_2026-10-01/_descartadas_2026-10-01/.
#
# Enquadramento (2026-10-01): mapa ~14% maior que o da versao anterior e
# centralizado horizontalmente. Achado por busca medindo pixels: com o nome em
# p_y = 0.35, s_width = 1.20 da 332 px de altura de mapa (292 antes) e 8 px de
# folga ate a aresta; acima disso a Baja California encosta na borda.
# =============================================================================

lib_local <- "../_logo_2026-10-01/_lib"
if (dir.exists(lib_local)) .libPaths(c(lib_local, .libPaths()))
suppressPackageStartupMessages({
  library(ggplot2); library(sf); library(hexSticker); library(sysfonts); library(showtext); library(magick)
})
sf_use_s2(FALSE)
pdf(NULL)   # sem isto, o Rscript grava um Rplots.pdf na raiz do pacote
out_dir <- "../_logo_2026-10-01/final"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# --- paleta: k-means (7 grupos) sobre os pixels da imagem de referencia -----
azul <- c(ceu = "#78CDE6", marinho = "#002E69", escuro = "#015187", medio = "#0375A5",
          vivo = "#0695BF", claro = "#42B4D7", palido = "#AEE6F7")
destaque_15 <- "#AEE3F5"    # 15 paises do pacote (cor indicada pelo autor)
outros      <- "#025A83"    # demais paises: o fundo (#0375A5) escurecido

font_add("arial_bold", "/System/Library/Fonts/Supplemental/Arial Bold.ttf")
showtext_auto()

# --- mapa: America Latina continental + Caribe hispanico --------------------
# Haiti entra para a Hispaniola nao sair pela metade; Guiana, Suriname e a
# Guiana Francesa (recortada da Franca) para a silhueta nao ter buraco.
# Malvinas fora. Sem fronteiras internas dentro de cada grupo.
PAISES_PACOTE <- c("ARG", "BOL", "BRA", "CHL", "COL", "CRI", "ECU", "HND", "MEX",
                   "NIC", "PAN", "PER", "PRY", "SLV", "URY")
mundo <- rnaturalearth::ne_countries(scale = 50, returnclass = "sf")
paises <- mundo[(mundo$subregion %in% c("Central America", "South America") & mundo$name != "Falkland Is.") |
                  mundo$name %in% c("Cuba", "Dominican Rep.", "Haiti", "Puerto Rico"), ]
guiana_fr <- suppressWarnings(st_crop(mundo[mundo$name == "France", ],
                                      xmin = -55, xmax = -51, ymin = 2, ymax = 6.5))
uniao <- function(x) suppressMessages(st_union(st_make_valid(x)))
silhueta <- uniao(rbind(paises["geometry"], guiana_fr["geometry"]))
no_pacote <- uniao(paises[paises$iso_a3 %in% PAISES_PACOTE, "geometry"])
fora      <- uniao(rbind(paises[!paises$iso_a3 %in% PAISES_PACOTE, "geometry"], guiana_fr["geometry"]))
stopifnot(sum(paises$iso_a3 %in% PAISES_PACOTE) == 15)

bb <- st_bbox(silhueta)
XL <- c(bb[["xmin"]] - 0.5, bb[["xmax"]] + 0.5); YL <- c(bb[["ymin"]] - 0.5, bb[["ymax"]] + 0.5)
base_mapa <- function(p) p + coord_sf(xlim = XL, ylim = YL, expand = FALSE, datum = NA) +
  theme_void() + theme_transparent()
mapa_silhueta <- base_mapa(ggplot() + geom_sf(data = silhueta, fill = azul[["palido"]], colour = NA))
mapa_15 <- base_mapa(ggplot() + geom_sf(data = fora, fill = outros, colour = NA) +
                       geom_sf(data = no_pacote, fill = destaque_15, colour = NA))

# faixa 50/40/10: tres segmentos com as larguras das classes do pacote
faixa <- function() {
  d <- data.frame(xmin = c(0, 50, 90), xmax = c(50, 90, 100),
                  cor = c(azul[["marinho"]], azul[["claro"]], azul[["palido"]]))
  ggplot(d) + geom_rect(aes(xmin = xmin, xmax = xmax, ymin = 0, ymax = 1, fill = cor)) +
    scale_fill_identity() + coord_cartesian(expand = FALSE) + theme_void() + theme_transparent()
}

LAYOUT <- list(s_x = 1.01, s_y = 1.063, s = 1.20, p_size = 13.5, p_y = 0.35,
               faixa_y = 0.225, faixa_w = 0.68, faixa_h = 0.026)

# p_size calibrado para PNG a 300 dpi; no SVG o showtext usa 96 dpi de
# referencia e desenharia o texto 300/96 vezes maior, entao a escala e
# corrigida aqui (conferido rasterizando o SVG).
gerar_hex <- function(mapa, arquivo, escala_texto = if (grepl("\\.svg$", arquivo)) 96 / 300 else 1) {
  L <- LAYOUT
  s <- sticker(mapa, s_x = L$s_x, s_y = L$s_y, s_width = L$s, s_height = L$s,
               package = "incomeLato", p_family = "arial_bold", p_color = "#FFFFFF",
               p_size = L$p_size * escala_texto, p_y = L$p_y,
               h_fill = azul[["medio"]], h_color = azul[["marinho"]], h_size = 1.6,
               filename = arquivo, dpi = 300, white_around_sticker = FALSE)
  s <- s + ggimage::geom_subview(subview = faixa(), x = 1, y = L$faixa_y, width = L$faixa_w, height = L$faixa_h)
  save_sticker(arquivo, s, dpi = 300)
}

# social preview do GitHub (1280x640): hex a esquerda, titulo e subtitulo
# (uma linha) a direita, fundo branco. O hex e rasterizado a partir do SVG
# (rsvg) ja no tamanho final em pixels (560 px de altura) e colocado em
# coordenadas inteiras de pixel (100 px por unidade), sem reamostragem.
social_preview <- function(hex_svg, arquivo) {
  px <- 100                                     # 1280 px / 12.8 unidades
  img <- rsvg::rsvg(hex_svg, height = 560)
  alt <- dim(img)[1] / px; larg <- dim(img)[2] / px
  p <- ggplot() + scale_x_continuous(limits = c(0, 12.8), expand = c(0, 0)) +
    scale_y_continuous(limits = c(0, 6.4), expand = c(0, 0)) +
    annotation_raster(img, xmin = 0.4, xmax = 0.4 + larg, ymin = 0.4, ymax = 0.4 + alt,
                      interpolate = FALSE) +
    annotate("text", x = 5.45, y = 3.6, label = "incomeLato", hjust = 0, family = "arial_bold",
             size = 32, colour = azul[["marinho"]]) +
    annotate("text", x = 5.5, y = 2.5, hjust = 0, family = "arial_bold", size = 6.9,
             colour = azul[["medio"]], label = "income position for Latinobarómetro respondents") +
    theme_void() + theme(plot.background = element_rect(fill = "#FFFFFF", colour = NA))
  showtext_opts(dpi = 100)
  ggsave(arquivo, p, width = 12.8, height = 6.4, dpi = 100)
  showtext_opts(dpi = 96)
}

svg_f <- file.path(out_dir, "incomeLato_logo_silhueta.svg")
gerar_hex(mapa_silhueta, file.path(out_dir, "incomeLato_logo_silhueta.png"))
gerar_hex(mapa_silhueta, svg_f)
social_preview(svg_f, file.path(out_dir, "social_preview_silhueta.png"))
cat("Gerado em", normalizePath(out_dir), "\n")
