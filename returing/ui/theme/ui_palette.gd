class_name UiPalette
extends RefCounted
## Cores e medidas compartilhadas das HUDs e menus (linguagem dourada). Uma única fonte da verdade.

const GOLD: Color = Color("#e8c15a")
const GOLD_BRIGHT: Color = Color("#fee286")
const TEXT: Color = Color("#f6f1df")
const TEXT_MUTED: Color = Color("#b4b0a2")
const TEXT_DISABLED: Color = Color("#8a8a8a")
const LIFE: Color = Color("#f62626")
const XP: Color = Color("#86befe")
const DANGER: Color = Color("#ff9a3c")
const DANGER_BG: Color = Color(0.35, 0.16, 0.0, 0.55)
const PANEL_BG: Color = Color(0.03, 0.03, 0.05, 0.86)
const DIM: Color = Color(0.0, 0.0, 0.0, 0.62)
const OUTLINE: Color = Color(0.0, 0.0, 0.0, 0.9)

## Unidade de espaçamento: margens, separações e paddings são múltiplos dela.
const UNIT: int = 8
## Tamanhos de fonte da hierarquia (título, corpo, dica).
const FONT_TITLE: int = 34
const FONT_BODY: int = 16
const FONT_HINT: int = 12
## Margem de segurança (px) das HUDs em relação às bordas da tela.
const SAFE_MARGIN: int = 16
## Duração (s) das animações curtas (fade, slide, brilho).
const ANIM_TIME: float = 0.2

const THEME_PATH: String = "res://ui/theme/returing_theme.tres"


## Carrega o tema compartilhado (aplicar só na raiz de cada HUD ou menu).
static func load_theme() -> Theme:
	return load(THEME_PATH) as Theme


## Razão de contraste WCAG entre duas cores opacas.
static func contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


static func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
