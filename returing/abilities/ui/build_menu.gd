class_name BuildMenu
extends CanvasLayer
## Menu "SUA BUILD": mostra, só para leitura, o nível, o XP e as habilidades que o jogador tem,
## com os slots ainda bloqueados e os efeitos ativos. Abre ao clicar ou tocar no amuleto da HUD de
## cooldown. Não escolhe, troca nem remove nada: quem abre e fecha (AbilitiesUI) cuida da pausa.

## Pedido de fechar (clique ou toque fora, `ui_cancel` ou o botão "Fechar").
signal close_requested

const CARD_SEPARATION: int = Palette.UNIT * 3
const BOX_SEPARATION: int = Palette.UNIT
## Quantos slots de habilidade a run tem (um por nível, até o nível máximo).
const SLOT_COUNT: int = 3
const PLACEHOLDER_SIZE: Vector2 = Vector2(240.0, 220.0)
const XP_BAR_SIZE: Vector2 = Vector2(320.0, 64.0)
const XP_BAR_AREA: Vector2 = Vector2(320.0, 64.0)
## Atraso (s) de CARD_STAGGER entre cartas e tempo (s) em que o clique fora ainda não fecha.
const CARD_STAGGER: float = 0.06
const CLOSE_GUARD_TIME: float = 0.25

var _root: Control = null
var _box: VBoxContainer = null
var _subtitle: Label = null
var _xp_holder: Control = null
var _cards_box: HBoxContainer = null
var _active_title: Label = null
var _active_list: VBoxContainer = null
var _close_button: Button = null

var _cards: Array[LevelUpCard] = []
var _is_open: bool = false
var _accepting_close: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # roda com o jogo pausado
	_build()
	visible = false


func is_open() -> bool:
	return _is_open


## Abre o menu. `focus_id`: habilidade clicada, que começa com foco/destaque.
func open(abilities: AbilityComponent, experience: ExperienceComponent, focus_id: StringName) -> void:
	_clear()
	var level: int = RunState.level
	_subtitle.text = "Nível %d de %d" % [level, experience.get_max_level()]
	_fill_xp(experience)
	var owned: Array[AbilityData] = abilities.abilities
	var focus_card: LevelUpCard = null
	for i: int in SLOT_COUNT:
		if i < owned.size():
			var card: LevelUpCard = LevelUpCard.new()
			_cards_box.add_child(card)
			card.setup(owned[i], false, true)  # só leitura
			card.play_entrance(float(i) * CARD_STAGGER)
			_cards.append(card)
			if owned[i].id == focus_id:
				focus_card = card
		else:
			var unlock_level: int = i + 1
			_cards_box.add_child(_make_placeholder(
					"Slot vazio" if level >= unlock_level else "Desbloqueia no nível %d" % unlock_level))
	_fill_active(abilities, owned)
	_is_open = true
	_accepting_close = false
	visible = true
	_root.modulate.a = 0.0
	var fade: Tween = UiTween.create(self)
	fade.tween_property(_root, ^"modulate:a", 1.0, Palette.FADE_TIME)
	if focus_card != null:
		focus_card.grab_focus.call_deferred()
	elif not _cards.is_empty():
		_cards[0].grab_focus.call_deferred()
	else:
		_close_button.grab_focus.call_deferred()
	# o toque que abriu o menu não pode fechá-lo logo em seguida
	await get_tree().create_timer(CLOSE_GUARD_TIME, true, false, true).timeout
	_accepting_close = _is_open


func close() -> void:
	_is_open = false
	_accepting_close = false
	visible = false
	_clear()


func _clear() -> void:
	for child: Node in _cards_box.get_children():
		child.queue_free()
	_cards.clear()
	for child: Node in _active_list.get_children():
		child.queue_free()
	for child: Node in _xp_holder.get_children():
		child.queue_free()


# --- Conteúdo ---

## `XpBar` horizontal reaproveitada no cabeçalho (sem animação: já abre no valor certo).
func _fill_xp(experience: ExperienceComponent) -> void:
	var bar: XpBar = (load("res://ui/hud/xp_bar.tscn") as PackedScene).instantiate() as XpBar
	bar.orientation = XpBar.BarLayout.HORIZONTAL
	bar.auto_bind = false
	bar.follow_health_block = false
	_xp_holder.add_child(bar)
	bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	bar.position = Vector2(0.0, (XP_BAR_AREA.y - XP_BAR_SIZE.y) * 0.5)
	bar.size = XP_BAR_SIZE
	var floor_xp: int = experience.get_level_floor()
	bar.set_xp_instant(RunState.xp - floor_xp, experience.get_next_threshold() - floor_xp, RunState.level,
			experience.is_max_level())


func _make_placeholder(text: String) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = PLACEHOLDER_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = &"HintLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return panel


## "Ativos agora": efeitos com duração em andamento e o tempo que falta (calculado do cooldown).
func _fill_active(abilities: AbilityComponent, owned: Array[AbilityData]) -> void:
	var lines: PackedStringArray = []
	for data: AbilityData in owned:
		var left: float = abilities.get_cooldown_left(data.id)
		var elapsed: float = data.cooldown - left
		if data.duration > 0.0 and left > 0.0 and elapsed < data.duration:
			var fase: String = "  (penalidade)" if data.is_penalty_at(elapsed) else ""
			lines.append("%s%s  ·  %.1f s" % [data.display_name, fase, data.duration - elapsed])
	_active_title.visible = not lines.is_empty()
	for line: String in lines:
		var label: Label = Label.new()
		label.text = line
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_active_list.add_child(label)


# --- Construção ---

func _build() -> void:
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_STOP  # o clique não vaza para o jogo
	_root.theme = Palette.load_theme()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.gui_input.connect(_on_root_gui_input)

	var dim: ColorRect = ColorRect.new()
	dim.color = Palette.dim_color()
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override(&"separation", BOX_SEPARATION)
	_box.mouse_filter = Control.MOUSE_FILTER_STOP  # clique dentro do conteúdo não fecha o menu
	center.add_child(_box)

	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(title_row)
	var title: Label = Label.new()
	title.theme_type_variation = &"PanelTitleLabel"
	title.text = "SUA BUILD"
	title_row.add_child(title)

	_subtitle = Label.new()
	_subtitle.theme_type_variation = &"HintLabel"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_subtitle)

	_xp_holder = Control.new()
	_xp_holder.custom_minimum_size = XP_BAR_AREA
	_xp_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_xp_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_xp_holder)

	_cards_box = HBoxContainer.new()
	_cards_box.add_theme_constant_override(&"separation", CARD_SEPARATION)
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_cards_box)

	_active_title = Label.new()
	_active_title.text = "ATIVOS AGORA"
	_active_title.theme_type_variation = &"HintLabel"
	_active_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_active_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_active_title)
	_active_list = VBoxContainer.new()
	_active_list.add_theme_constant_override(&"separation", 2)
	_active_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_active_list)

	_close_button = PixelButton.new()
	_close_button.text = "Fechar"
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close_button.custom_minimum_size = Vector2(Palette.UNIT * 20, 0.0)
	_close_button.pressed.connect(_request_close)
	_box.add_child(_close_button)


# --- Interação ---

func _input(event: InputEvent) -> void:
	if _is_open and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_request_close()


## Clique ou toque fora do conteúdo fecha o menu (o clique dentro é do conteúdo).
func _on_root_gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if not _accepting_close:
		return
	if _box.get_global_rect().has_point(click.global_position):
		return
	_request_close()


func _request_close() -> void:
	if _is_open:
		close_requested.emit()
