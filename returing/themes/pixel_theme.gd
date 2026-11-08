@tool
class_name PixelTheme
extends Theme
## Tema de todos os menus (usado por res://themes/main_theme.tres).
## Todos os estilos saem de `Palette` e são montados aqui, então mudar uma cor ou medida
## é editar UM lugar. As fontes são carregadas se existirem em res://assets/fonts/; sem elas o
## menu continua funcionando com a fonte padrão do Godot (e avisa no console).
##
## Variações de tipo disponíveis nas cenas (propriedade "Theme Type Variation"):
##   Label:  TitleLabel (título grande), PanelTitleLabel (título de caixa), HintLabel (apoio, TEXT_DIM)
##   Button: DangerButton (ação destrutiva: hover/foco em DANGER)
##   Panel:  BackdropPanel (fundo de tela cheia)  |  PanelContainer: PanelRaised (caixa elevada)

## Fonte de título, em ordem de preferência (a primeira que existir é usada).
const TITLE_FONT_PATHS: PackedStringArray = [
	"res://assets/fonts/PixelifySans-Bold.ttf",
	"res://assets/fonts/PixelifySans-Regular.ttf",
	"res://assets/fonts/PixelifySans-VariableFont_wght.ttf",
	"res://assets/fonts/PixelifySans[wght].ttf",
]
## Fonte de texto e botões.
const BODY_FONT_PATHS: PackedStringArray = [
	"res://assets/fonts/VT323-Regular.ttf",
]

## Espaçamento padrão (px) entre itens de caixas.
const SEPARATION: int = Palette.UNIT * 2
## Margem interna (px) horizontal e vertical dos botões.
const BUTTON_PAD_X: int = Palette.UNIT * 3
const BUTTON_PAD_Y: int = 12
## Margem interna (px) das caixas.
const PANEL_PAD: int = Palette.UNIT * 3
## Sombra dos botões: em repouso, com hover/foco (o botão sobe 2 px) e apertado (afunda 2 px).
## A base da sombra fica no mesmo lugar nos três estados, como se o botão saísse do chão.
const SHADOW_REST: Vector2i = Vector2i(0, 4)
const SHADOW_HOVER: Vector2i = Vector2i(0, 6)
const SHADOW_PRESSED: Vector2i = Vector2i(0, 2)

const GRABBER_SIZE: Vector2i = Vector2i(16, 24)
## Altura do trilho = 2 x esta margem (12 px: 4 de moldura de cada lado + 4 de miolo).
const SLIDER_TRACK_PAD: int = 6


func _init() -> void:
	_build()


func _build() -> void:
	var body_font: Font = _load_font(BODY_FONT_PATHS)
	var title_font: Font = _load_font(TITLE_FONT_PATHS)
	if body_font != null:
		default_font = body_font
	default_font_size = Palette.FONT_BODY
	_build_labels(title_font)
	_build_button(&"Button", Palette.ACCENT, Palette.ACCENT_PRESSED)
	set_type_variation(&"DangerButton", &"Button")
	_build_button(&"DangerButton", Palette.DANGER, Palette.DANGER)
	_build_panels()
	_build_slider()
	_build_separator()
	_build_inputs()
	set_constant(&"separation", &"VBoxContainer", SEPARATION)
	set_constant(&"separation", &"HBoxContainer", SEPARATION)


## Carrega a primeira fonte existente da lista e a deixa sem suavização (pixel nítido).
func _load_font(paths: PackedStringArray) -> Font:
	for path: String in paths:
		if not ResourceLoader.exists(path):
			continue
		var font: FontFile = load(path) as FontFile
		if font == null:
			continue
		font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		return font
	push_warning("PixelTheme: fonte não encontrada (%s). Usando a fonte padrão; veja res://assets/fonts/LEIAME.md." % paths[0])
	return null


# --- Textos ---

func _build_labels(title_font: Font) -> void:
	set_color(&"font_color", &"Label", Palette.TEXT)
	set_font_size(&"font_size", &"Label", Palette.FONT_BODY)
	set_color(&"default_color", &"RichTextLabel", Palette.TEXT)
	set_font_size(&"normal_font_size", &"RichTextLabel", Palette.FONT_BODY)

	set_type_variation(&"HintLabel", &"Label")
	set_color(&"font_color", &"HintLabel", Palette.TEXT_DIM)
	set_font_size(&"font_size", &"HintLabel", Palette.FONT_HINT)

	set_type_variation(&"TitleLabel", &"Label")
	set_color(&"font_color", &"TitleLabel", Palette.TEXT)
	set_font_size(&"font_size", &"TitleLabel", Palette.FONT_TITLE)
	set_color(&"font_shadow_color", &"TitleLabel", Palette.BORDER)  # sombra dura, sem blur
	set_constant(&"shadow_offset_x", &"TitleLabel", Palette.BORDER_THICK)
	set_constant(&"shadow_offset_y", &"TitleLabel", Palette.BORDER_THICK)

	set_type_variation(&"PanelTitleLabel", &"Label")
	set_color(&"font_color", &"PanelTitleLabel", Palette.TEXT)
	set_font_size(&"font_size", &"PanelTitleLabel", Palette.FONT_BODY)
	if title_font != null:
		set_font(&"font", &"TitleLabel", title_font)
		set_font(&"font", &"PanelTitleLabel", title_font)


# --- Botões ---

## Monta os 5 estados de um botão. `hot` = cor de hover/foco; `hot_pressed` = cor ao apertar.
func _build_button(type: StringName, hot: Color, hot_pressed: Color) -> void:
	var normal: PixelBox = _box(Palette.PANEL_RAISED, Palette.BORDER, SHADOW_REST, BUTTON_PAD_X, BUTTON_PAD_Y)
	var hover: PixelBox = _box(Palette.PANEL_RAISED, hot, SHADOW_HOVER, BUTTON_PAD_X, BUTTON_PAD_Y)
	var pressed: PixelBox = _box(Palette.PANEL, hot_pressed, SHADOW_PRESSED, BUTTON_PAD_X, BUTTON_PAD_Y)
	var disabled_box: PixelBox = _box(Palette.PANEL, Palette.DISABLED, SHADOW_REST, BUTTON_PAD_X, BUTTON_PAD_Y)
	set_stylebox(&"normal", type, normal)
	set_stylebox(&"hover", type, hover)
	# Foco com o mesmo visual do hover (o PixelButton troca por vazio e controla o destaque sozinho).
	set_stylebox(&"focus", type, hover)
	set_stylebox(&"pressed", type, pressed)
	set_stylebox(&"hover_pressed", type, pressed)
	set_stylebox(&"disabled", type, disabled_box)
	set_color(&"font_color", type, Palette.TEXT)
	set_color(&"font_hover_color", type, hot)
	set_color(&"font_focus_color", type, hot)
	set_color(&"font_pressed_color", type, hot_pressed)
	set_color(&"font_hover_pressed_color", type, hot_pressed)
	set_color(&"font_disabled_color", type, Palette.DISABLED_TEXT)
	set_font_size(&"font_size", type, Palette.FONT_BODY)
	set_constant(&"h_separation", type, Palette.UNIT)
	set_constant(&"outline_size", type, 0)


# --- Painéis ---

func _build_panels() -> void:
	var panel: PixelBox = _box(Palette.PANEL, Palette.BORDER, Palette.SHADOW_PANEL, PANEL_PAD, PANEL_PAD)
	set_stylebox(&"panel", &"PanelContainer", panel)
	set_stylebox(&"panel", &"Panel", panel)

	set_type_variation(&"PanelRaised", &"PanelContainer")
	set_stylebox(&"panel", &"PanelRaised",
			_box(Palette.PANEL_RAISED, Palette.BORDER, Palette.SHADOW_PANEL, PANEL_PAD, PANEL_PAD))

	# Fundo de tela cheia: cor lisa, sem moldura.
	set_type_variation(&"BackdropPanel", &"Panel")
	var backdrop: PixelBox = _box(Palette.BG, Palette.BG, Vector2i.ZERO, 0, 0)
	backdrop.border_width = 0
	backdrop.outline_width = 0
	backdrop.corner_cut = 0
	set_stylebox(&"panel", &"BackdropPanel", backdrop)


# --- Slider (HSlider): trilho em PANEL_RAISED, preenchimento e grabber em ACCENT ---

func _build_slider() -> void:
	var track: PixelBox = _box(Palette.PANEL_RAISED, Palette.BORDER, Vector2i.ZERO, 0, SLIDER_TRACK_PAD)
	set_stylebox(&"slider", &"HSlider", track)
	# Preenchimento: desenhado dentro do trilho (descontando contorno + borda = 4 px).
	var fill: PixelBox = PixelBox.new()
	fill.fill_color = Palette.ACCENT
	fill.border_width = 0
	fill.outline_width = 0
	fill.corner_cut = 0
	fill.inset = Palette.BORDER_THICK
	set_stylebox(&"grabber_area", &"HSlider", fill)
	set_stylebox(&"grabber_area_highlight", &"HSlider", fill)
	set_icon(&"grabber", &"HSlider", _make_grabber(Palette.ACCENT, Palette.BG))
	# Hover/foco/arraste: mesmo grabber com anel claro para o foco ficar visível.
	set_icon(&"grabber_highlight", &"HSlider", _make_grabber(Palette.ACCENT, Palette.TEXT))
	set_icon(&"grabber_disabled", &"HSlider", _make_grabber(Palette.DISABLED, Palette.BG))


## Grabber retangular com anel de 2 px e cantos cortados, gerado em código (sem arte).
func _make_grabber(fill: Color, ring: Color) -> ImageTexture:
	var image: Image = Image.create(GRABBER_SIZE.x, GRABBER_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(Vector2i.ZERO, GRABBER_SIZE), ring)
	image.fill_rect(Rect2i(Vector2i(2, 2), GRABBER_SIZE - Vector2i(4, 4)), fill)
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(GRABBER_SIZE.x - 2, 0),
			Vector2i(0, GRABBER_SIZE.y - 2), Vector2i(GRABBER_SIZE.x - 2, GRABBER_SIZE.y - 2)]:
		image.fill_rect(Rect2i(corner, Vector2i(2, 2)), Color.TRANSPARENT)
	return ImageTexture.create_from_image(image)


# --- Campo de texto (LineEdit) e barra de progresso ---

func _build_inputs() -> void:
	var pad_x: int = Palette.UNIT * 2
	var pad_y: int = Palette.UNIT
	set_stylebox(&"normal", &"LineEdit", _box(Palette.PANEL, Palette.BORDER, Vector2i.ZERO, pad_x, pad_y))
	set_stylebox(&"focus", &"LineEdit", _box(Palette.PANEL, Palette.ACCENT, Vector2i.ZERO, pad_x, pad_y))
	set_stylebox(&"read_only", &"LineEdit", _box(Palette.PANEL, Palette.DISABLED, Vector2i.ZERO, pad_x, pad_y))
	set_color(&"font_color", &"LineEdit", Palette.TEXT)
	set_color(&"font_selected_color", &"LineEdit", Palette.TEXT)
	set_color(&"font_uneditable_color", &"LineEdit", Palette.DISABLED_TEXT)
	set_color(&"font_placeholder_color", &"LineEdit", Palette.TEXT_DIM)
	set_color(&"caret_color", &"LineEdit", Palette.ACCENT)
	set_color(&"selection_color", &"LineEdit", Palette.with_alpha(Palette.ACCENT, 0.35))
	set_font_size(&"font_size", &"LineEdit", Palette.FONT_BODY)

	# Barra: trilho em PANEL_RAISED e preenchimento em ACCENT (a margem de 4 px deixa a moldura aparecer).
	set_stylebox(&"background", &"ProgressBar",
			_box(Palette.PANEL_RAISED, Palette.BORDER, Vector2i.ZERO, Palette.BORDER_THICK, Palette.BORDER_THICK))
	var bar_fill: PixelBox = PixelBox.new()
	bar_fill.fill_color = Palette.ACCENT
	bar_fill.border_width = 0
	bar_fill.outline_width = 0
	bar_fill.corner_cut = 0
	set_stylebox(&"fill", &"ProgressBar", bar_fill)
	set_color(&"font_color", &"ProgressBar", Palette.TEXT)
	set_font_size(&"font_size", &"ProgressBar", Palette.FONT_SMALL)


# --- Separador ---

func _build_separator() -> void:
	var line: PixelBox = PixelBox.new()
	line.fill_color = Palette.BORDER
	line.border_width = 0
	line.outline_width = 0
	line.corner_cut = 0
	line.content_margin_top = Palette.BORDER_THIN / 2.0
	line.content_margin_bottom = Palette.BORDER_THIN / 2.0
	set_stylebox(&"separator", &"HSeparator", line)
	set_constant(&"separation", &"HSeparator", Palette.UNIT)


## Cria uma caixa. `fill`/`border` em cores da paleta; margens internas em px.
func _box(fill: Color, border: Color, shadow: Vector2i, pad_x: int, pad_y: int) -> PixelBox:
	var box: PixelBox = PixelBox.new()
	box.fill_color = fill
	box.border_color = border
	box.shadow_offset = shadow
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	return box
