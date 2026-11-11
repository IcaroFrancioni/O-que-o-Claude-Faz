class_name SkipCutsceneButton
extends PixelButton
## Botão "Avançar cutscene" (só no celular): no lugar de "segure TAB/ESC para pular". Usa a caixa marrom
## do tema do jogo (mesmo estilo dos botões e das caixas de diálogo) e a fonte do jogo.

## Texto do botão.
const LABEL: String = "Avançar cutscene"
const FONT_SIZE: int = 26  # Tamanho da fonte (múltiplo do pixel da fonte do jogo).
const SIZE: Vector2 = Vector2(264.0, 56.0)  # Tamanho mínimo (toque confortável).
const MARGIN: float = 16.0  # Distância das bordas (canto superior direito).

## O jogador tocou no botão.
signal skip_requested


## Cria o botão dentro de `parent` (um Control com o tema do jogo) e liga `on_press`. No computador não cria
## nada e devolve null: lá continua "segure TAB/ESC para pular".
static func attach(parent: Node, on_press: Callable) -> SkipCutsceneButton:
	if not Platform.is_mobile():
		return null
	var button: SkipCutsceneButton = SkipCutsceneButton.new()
	button.name = &"BotaoAvancarCutscene"
	button.text = LABEL
	button.custom_minimum_size = SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	button.offset_left = -SIZE.x - MARGIN
	button.offset_right = -MARGIN
	button.offset_top = MARGIN
	button.offset_bottom = MARGIN + SIZE.y
	button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	button.add_theme_font_size_override(&"font_size", FONT_SIZE)
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	if parent is Control and (parent as Control).theme == null:
		button.theme = Palette.load_theme()
	button.pressed.connect(func() -> void:
		button.skip_requested.emit()
		on_press.call())
	parent.add_child(button)
	return button
