extends SceneTree
## Auditoria da paleta e do tema dos menus: contraste mínimo de texto (4,5:1), ausência de branco/preto
## puros e carga do res://themes/main_theme.tres.
## Rodar: godot --headless --path . --script res://qa/palette_audit.gd

const MIN_CONTRAST: float = 4.5
const THEME_PATH: String = "res://themes/main_theme.tres"


func _initialize() -> void:
	var falhas: int = 0
	# Texto sobre as superfícies onde ele realmente aparece.
	var textos: Dictionary[String, Color] = {
		"TEXT": Palette.TEXT,
		"TEXT_DIM": Palette.TEXT_DIM,
		"ACCENT": Palette.ACCENT,
		"ACCENT_PRESSED": Palette.ACCENT_PRESSED,
		"DANGER": Palette.DANGER,
		"DISABLED_TEXT": Palette.DISABLED_TEXT,
	}
	var fundos: Dictionary[String, Color] = {
		"BG": Palette.BG,
		"PANEL": Palette.PANEL,
		"PANEL_RAISED": Palette.PANEL_RAISED,
	}
	for nome_texto: String in textos:
		for nome_fundo: String in fundos:
			var razao: float = Palette.contrast(textos[nome_texto], fundos[nome_fundo])
			# Texto desabilitado é isento da regra (WCAG), mas o resultado sai no log.
			var exigido: bool = nome_texto != "DISABLED_TEXT"
			var ok: bool = razao >= MIN_CONTRAST
			var marca: String = "ok" if ok else ("ABAIXO" if exigido else "abaixo (isento)")
			print("%-15s sobre %-13s %5.2f  %s" % [nome_texto, nome_fundo, razao, marca])
			if exigido and not ok:
				falhas += 1
	for cor: Color in [Palette.BG, Palette.PANEL, Palette.PANEL_RAISED, Palette.BORDER, Palette.TEXT,
			Palette.TEXT_DIM, Palette.ACCENT, Palette.ACCENT_PRESSED, Palette.DANGER,
			Palette.DISABLED, Palette.DISABLED_TEXT]:
		if cor == Color.WHITE or cor == Color.BLACK:
			printerr("Cor pura (branco/preto) na paleta: ", cor)
			falhas += 1
	var tema: Theme = load(THEME_PATH) as Theme
	if tema == null or not tema is PixelTheme:
		printerr("Falha ao carregar ", THEME_PATH, " como PixelTheme")
		falhas += 1
	else:
		if not tema.has_stylebox(&"normal", &"Button") or not tema.has_stylebox(&"slider", &"HSlider"):
			printerr("Tema sem estilos esperados (Button/normal ou HSlider/slider)")
			falhas += 1
	print("palette_audit: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)
