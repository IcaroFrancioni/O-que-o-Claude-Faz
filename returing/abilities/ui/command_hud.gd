class_name CommandHud
extends Control
## HUD de habilidades. Fora do modo comando: faixa compacta de slots (embaixo à direita, longe da barra de
## vida e da de XP) com varredura de cooldown. Durante o modo comando: painel com as habilidades, as setas
## e a barra de recarga. Só escuta os sinais do AbilityComponent: ele não conhece esta HUD.

## Clique ou toque no amuleto de uma habilidade (abre o menu de build).
signal slot_pressed(ability: AbilityData)

const COLOR_BAR_BG: Color = Color(0.1, 0.09, 0.14, 1.0)
const COLOR_BAR_FILL: Color = Color(0.56, 0.58, 0.64, 1.0)
const COLOR_BAR_READY: Color = UiPalette.GOLD

const ROW_AMULET_SIZE: float = 40.0
const NAME_WIDTH: float = 150.0
const BAR_SIZE: Vector2 = Vector2(70.0, 6.0)
## Largura da coluna de setas (cabe a sequência mais longa: 6 setas).
const ARROWS_COLUMN_WIDTH: float = 133.0
## Quantos slots a faixa compacta mostra (vazios aparecem discretos até as habilidades chegarem).
const MAX_SLOTS: int = 3
const SLOT_SEPARATION: int = UiPalette.UNIT
## No celular a faixa compacta desce (px) para ficar abaixo do botão de pausa.
const MOBILE_COMPACT_TOP: float = 70.0
## Margem inferior do painel de comando no celular (centralizado, entre os analógicos).
const MOBILE_PANEL_BOTTOM: int = 24
## Transparência das linhas que não combinam com o que foi digitado.
const DIMMED_ALPHA: float = 0.35
## Dica de como ativar (aparece sobre os slots até o jogador abrir o modo comando uma vez).
const HINT_PC: String = "Aperte CTRL, digite as setas e confirme com ENTER"
## Rodapé do painel de comando (teclado).
const FOOTER_PC: String = "ENTER confirma  -  BACKSPACE apaga  -  CTRL cancela"
## "Colinha": sequência em miniatura acima de cada slot da faixa compacta (sempre visível).
const CHEAT_ARROW_SIZE: float = 10.0
const CHEAT_ARROW_GAP: float = 3.0
const CHEAT_SLOT_GAP: int = 3
const HINT_MOBILE: String = "Toque em CMD e digite as setas"
const NOTICE_NO_ABILITIES: String = "Sem habilidades ainda: suba de nível"
## Quanto tempo (s) o aviso substitui a dica.
const NOTICE_TIME: float = 2.5

var _abilities: AbilityComponent = null
var _panel: PanelContainer = null
var _rows_box: VBoxContainer = null
var _compact: HBoxContainer = null
var _hint: Label = null
var _notice_token: int = 0
var _notice_active: bool = false
## id -> { "data", "row", "arrows", "bar", "amulet", "slot", "cooling", "dimmed" }
var _entries: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # a HUD nunca bloqueia cliques do jogo
	theme = UiPalette.load_theme()
	_build_panel()
	_build_compact()
	_panel.visible = false


func setup(abilities: AbilityComponent) -> void:
	_abilities = abilities
	CombatUtils.connect_once(abilities.abilities_changed, _rebuild)
	CombatUtils.connect_once(abilities.command_mode_changed, _on_command_mode_changed)
	CombatUtils.connect_once(abilities.input_progress, _on_input_progress)
	CombatUtils.connect_once(abilities.input_failed, _on_input_failed)
	CombatUtils.connect_once(abilities.cooldown_changed, _on_cooldown_changed)
	CombatUtils.connect_once(abilities.command_unavailable, _on_command_unavailable)
	_rebuild()


func _exit_tree() -> void:
	if not is_instance_valid(_abilities):
		return
	CombatUtils.disconnect_if_connected(_abilities.abilities_changed, _rebuild)
	CombatUtils.disconnect_if_connected(_abilities.command_mode_changed, _on_command_mode_changed)
	CombatUtils.disconnect_if_connected(_abilities.input_progress, _on_input_progress)
	CombatUtils.disconnect_if_connected(_abilities.input_failed, _on_input_failed)
	CombatUtils.disconnect_if_connected(_abilities.cooldown_changed, _on_cooldown_changed)
	CombatUtils.disconnect_if_connected(_abilities.command_unavailable, _on_command_unavailable)


# --- Construção ---

func _build_panel() -> void:
	_panel = PanelContainer.new()  # moldura dourada vem do tema
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override(&"separation", UiPalette.UNIT)
	_rows_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_rows_box)
	_panel.resized.connect(_place_panel)


## Painel no canto inferior direito (longe das barras de vida e XP); no celular, no centro de baixo.
func _place_panel() -> void:
	if Platform.is_mobile:
		_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, MOBILE_PANEL_BOTTOM)
	else:
		_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, UiPalette.SAFE_MARGIN)


func _build_compact() -> void:
	_compact = HBoxContainer.new()
	_compact.add_theme_constant_override(&"separation", SLOT_SEPARATION)
	_compact.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_compact)
	_compact.minimum_size_changed.connect(_place_compact)
	_hint = Label.new()
	_hint.theme_type_variation = &"HintLabel"
	_hint.text = HINT_MOBILE if Platform.is_mobile else HINT_PC
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_color_override(&"font_outline_color", UiPalette.OUTLINE)
	_hint.add_theme_constant_override(&"outline_size", 4)
	add_child(_hint)
	_hint.minimum_size_changed.connect(_place_compact)


## Faixa compacta no canto inferior direito; no celular (analógicos embaixo), no topo, abaixo da pausa.
func _place_compact() -> void:
	if Platform.is_mobile:
		_compact.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, UiPalette.SAFE_MARGIN)
		_compact.position.y += MOBILE_COMPACT_TOP  # mexe na posição sem mudar o tamanho
	else:
		_compact.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, UiPalette.SAFE_MARGIN)
	# A dica fica junto dos slots (acima deles; no celular, abaixo).
	var slot_band: float = CooldownSlot.SLOT_SIZE + CHEAT_ARROW_SIZE + CHEAT_SLOT_GAP + UiPalette.UNIT
	if Platform.is_mobile:
		_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, UiPalette.SAFE_MARGIN)
		_hint.position.y += MOBILE_COMPACT_TOP + slot_band
	else:
		_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, UiPalette.SAFE_MARGIN)
		_hint.position.y -= slot_band


## Recria as linhas do painel e os slots compactos.
func _rebuild() -> void:
	for child: Node in _rows_box.get_children():
		child.queue_free()
	for child: Node in _compact.get_children():
		child.queue_free()
	_entries.clear()
	if _abilities == null:
		return
	for data: AbilityData in _abilities.abilities:
		_add_entry(data)
	for i: int in range(_abilities.abilities.size(), MAX_SLOTS):  # slots vazios, discretos
		_compact.add_child(_make_slot_column(CooldownSlot.new(), null))
	if not _abilities.abilities.is_empty() and not Platform.is_mobile:
		var footer: Label = Label.new()
		footer.theme_type_variation = &"HintLabel"
		footer.text = FOOTER_PC
		footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rows_box.add_child(footer)
	_refresh_visibility()
	_place_panel.call_deferred()
	_place_compact.call_deferred()


func _add_entry(data: AbilityData) -> void:
	var entry: Dictionary = {"data": data, "cooling": false, "dimmed": false}

	# Linha do painel (modo comando).
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var amulet: AmuletIcon = AmuletIcon.new()
	amulet.custom_minimum_size = Vector2(ROW_AMULET_SIZE, ROW_AMULET_SIZE)
	amulet.set_ability(data)
	row.add_child(amulet)
	var name_label: Label = Label.new()
	name_label.text = data.display_name
	name_label.custom_minimum_size.x = NAME_WIDTH
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)
	var arrows: ArrowSequenceView = ArrowSequenceView.new()
	arrows.set_sequence(data.sequence)
	arrows.custom_minimum_size.x = ARROWS_COLUMN_WIDTH  # a barra de recarga fica alinhada em todas as linhas
	arrows.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(arrows)
	var bar: ProgressBar = _make_bar()
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	_rows_box.add_child(row)
	entry["row"] = row
	entry["amulet"] = amulet
	entry["arrows"] = arrows
	entry["bar"] = bar

	# Slot compacto (fora do modo comando).
	var slot: CooldownSlot = CooldownSlot.new()
	slot.ability = data
	slot.pressed.connect(_on_slot_pressed)
	var cheat: ArrowSequenceView = ArrowSequenceView.new()
	cheat.arrow_size = CHEAT_ARROW_SIZE
	cheat.arrow_gap = CHEAT_ARROW_GAP
	cheat.set_sequence(data.sequence)
	_compact.add_child(_make_slot_column(slot, cheat))
	entry["slot"] = slot
	entry["cheat"] = cheat

	_entries[data.id] = entry
	_apply_cooldown(entry, _abilities.get_cooldown_left(data.id), data.cooldown, false)


## Coluna da faixa compacta: a colinha (setas da sequência) em cima e o slot embaixo.
## Slot vazio recebe um espaço do mesmo tamanho para os slots ficarem alinhados.
func _make_slot_column(slot: CooldownSlot, cheat: Control) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", CHEAT_SLOT_GAP)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if cheat == null:
		cheat = Control.new()
		cheat.custom_minimum_size = Vector2(0.0, CHEAT_ARROW_SIZE)
		cheat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cheat.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(cheat)
	column.add_child(slot)
	return column


func _make_bar() -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = BAR_SIZE
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 1.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = COLOR_BAR_BG
	bar.add_theme_stylebox_override(&"background", background)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = COLOR_BAR_FILL
	bar.add_theme_stylebox_override(&"fill", fill)
	return bar


# --- Sinais do AbilityComponent ---

func _on_slot_pressed(ability: AbilityData) -> void:
	slot_pressed.emit(ability)


## Áreas (coordenadas da tela) dos slots clicáveis da faixa compacta, para o toque no celular.
func get_slot_hit_rects() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _compact == null or not _compact.visible:
		return result
	for entry: Dictionary in _entries.values():
		var slot: CooldownSlot = entry["slot"] as CooldownSlot
		result.append({"ability": entry["data"], "rect": slot.get_global_rect()})
	return result


## Ctrl apertado sem nenhuma habilidade: o aviso substitui a dica por alguns segundos.
func _on_command_unavailable(motivo: StringName) -> void:
	if motivo != &"sem_habilidades":
		return
	_hint.text = NOTICE_NO_ABILITIES
	_notice_active = true
	_notice_token += 1
	var token: int = _notice_token
	_refresh_visibility()
	await get_tree().create_timer(NOTICE_TIME, false).timeout
	if token == _notice_token:
		_notice_active = false
		_hint.text = HINT_MOBILE if Platform.is_mobile else HINT_PC
		_refresh_visibility()


func _on_command_mode_changed(active: bool) -> void:
	if active:
		RunState.command_hint_seen = true
	_refresh_visibility()


func _refresh_visibility() -> void:
	var active: bool = _abilities != null and _abilities.command_active
	_panel.visible = active and not _entries.is_empty()
	_compact.visible = not active
	_hint.visible = not active and (_notice_active or (not _entries.is_empty() and not RunState.command_hint_seen))
	if _panel.visible:
		_place_panel.call_deferred()


func _on_input_progress(sequence: Array[int], candidates: Array[AbilityData]) -> void:
	for entry: Dictionary in _entries.values():
		var data: AbilityData = entry["data"] as AbilityData
		var arrows: ArrowSequenceView = entry["arrows"] as ArrowSequenceView
		var row: Control = entry["row"] as Control
		var matches: bool = candidates.has(data)
		entry["dimmed"] = not matches
		row.modulate.a = 1.0 if matches else DIMMED_ALPHA
		arrows.set_progress(sequence.size() if matches else 0)
		if not matches:
			arrows.set_state(ArrowSequenceView.State.DIMMED)
		else:
			arrows.set_state(ArrowSequenceView.State.COOLDOWN if bool(entry["cooling"])
					else ArrowSequenceView.State.NORMAL)


func _on_input_failed() -> void:
	for entry: Dictionary in _entries.values():
		(entry["arrows"] as ArrowSequenceView).shake()


func _on_cooldown_changed(ability: AbilityData, remaining: float, total: float) -> void:
	if not _entries.has(ability.id):
		return
	_apply_cooldown(_entries[ability.id] as Dictionary, remaining, total, true)


func _apply_cooldown(entry: Dictionary, remaining: float, total: float, animate: bool) -> void:
	var cooling: bool = remaining > 0.0
	var was_cooling: bool = bool(entry["cooling"])
	entry["cooling"] = cooling
	var bar: ProgressBar = entry["bar"] as ProgressBar
	var arrows: ArrowSequenceView = entry["arrows"] as ArrowSequenceView
	var slot: CooldownSlot = entry["slot"] as CooldownSlot
	var ratio: float = clampf(remaining / maxf(total, 0.01), 0.0, 1.0)
	bar.value = 1.0 - ratio
	var fill: StyleBoxFlat = bar.get_theme_stylebox(&"fill") as StyleBoxFlat
	if fill != null:
		fill.bg_color = COLOR_BAR_FILL if cooling else COLOR_BAR_READY
	slot.update_cooldown(remaining, total, animate)
	var cheat: ArrowSequenceView = entry["cheat"] as ArrowSequenceView
	cheat.set_state(ArrowSequenceView.State.COOLDOWN if cooling else ArrowSequenceView.State.NORMAL)
	if bool(entry["dimmed"]):
		arrows.set_state(ArrowSequenceView.State.DIMMED)
	else:
		arrows.set_state(ArrowSequenceView.State.COOLDOWN if cooling else ArrowSequenceView.State.NORMAL)
	if animate and was_cooling and not cooling:
		arrows.pulse()
		cheat.pulse()
