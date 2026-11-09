class_name LevelUpMenu
extends CanvasLayer
## Menu de level-up: fundo escurecido, título e 3 cartas lado a lado.
## Funciona com a árvore pausada. Escolher uma lendária pede confirmação listando o que será perdido.
## Não conhece o Player: quem abre (AbilitiesUI) aplica a escolha.

## Uma carta foi escolhida (e, se lendária, confirmada).
signal ability_chosen(ability: AbilityData)
## O jogador preferiu manter as habilidades que tem (só quando as 3 cartas são lendárias).
signal kept_current
## O jogador pediu o reroll (sortear as cartas de novo). Quem abre o menu decide se pode e sorteia.
signal reroll_requested

const CARD_SEPARATION: int = Palette.UNIT * 3
const BOX_SEPARATION: int = Palette.UNIT * 3
const CONFIRM_WIDTH: float = 460.0
const REROLL_TEXT: String = "Rerrolar (1 por run)"
const REROLL_USED_TEXT: String = "Rerrolar (já usado)"
## Atraso (s) entre o aparecimento de uma carta e a seguinte.
const CARD_STAGGER: float = 0.08

@export_group("Entrada")
## Tempo (s) em que toda entrada é ignorada ao abrir (evita escolher sem querer em combate).
@export_range(0.0, 3.0, 0.05) var input_delay: float = 0.5
## Duração (s) do fade-in.
@export_range(0.0, 2.0, 0.05) var fade_time: float = 0.25

var _root: Control = null
var _title: Label = null
var _cards_box: HBoxContainer = null
var _keep_button: Button = null
var _reroll_button: Button = null
var _confirm: Control = null
var _confirm_text: Label = null
var _confirm_ok: Button = null
var _confirm_back: Button = null

var _cards: Array[LevelUpCard] = []
var _owned: Array[AbilityData] = []
var _pending: AbilityData = null
var _is_open: bool = false
var _locked: bool = false
var _confirming: bool = false
var _reroll_used: bool = false
## Cada abertura/reroll ganha um número; só o último destrava a entrada (o atraso anti-clique não encurta).
var _lock_token: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # roda com o jogo pausado
	_build()
	visible = false


func is_open() -> bool:
	return _is_open


## Abre o menu com as cartas sorteadas. `owned` são as habilidades atuais (para o aviso de perda).
func open(level: int, offer: Array[AbilityData], owned: Array[AbilityData]) -> void:
	_clear_cards()
	_owned = owned.duplicate()
	_pending = null
	_confirming = false
	_confirm.visible = false
	_title.text = "NÍVEL %d — ESCOLHA UMA HABILIDADE" % level
	_fill_cards(offer)

	_is_open = true
	visible = true
	_root.modulate.a = 0.0
	var tween: Tween = UiTween.create(self)
	tween.tween_property(_root, ^"modulate:a", 1.0, fade_time)
	await _lock_input()


## Reroll: troca as cartas por um novo sorteio (o aviso e a confirmação das lendárias seguem iguais).
## A entrada fica travada de novo pelo mesmo atraso anti-clique acidental.
func reroll(offer: Array[AbilityData]) -> void:
	if not _is_open:
		return
	_clear_cards()
	_pending = null
	_confirming = false
	_confirm.visible = false
	_fill_cards(offer)
	await _lock_input()


## Mostra o botão de reroll como disponível ou como já usado (desabilitado).
func set_reroll_used(used: bool) -> void:
	_reroll_used = used
	_reroll_button.disabled = used
	_reroll_button.text = REROLL_USED_TEXT if used else REROLL_TEXT


## Cria as cartas da oferta, liga o foco e anima a entrada.
func _fill_cards(offer: Array[AbilityData]) -> void:
	var all_legendary: bool = not offer.is_empty()
	var has_legendary: bool = false
	for data: AbilityData in offer:
		if data.rarity == AbilityData.Rarity.LENDARIA:
			has_legendary = true
	for data: AbilityData in offer:
		var card: LevelUpCard = LevelUpCard.new()
		_cards_box.add_child(card)
		card.setup(data, has_legendary)
		card.selected.connect(_on_card_selected)
		_cards.append(card)
		if data.rarity != AbilityData.Rarity.LENDARIA:
			all_legendary = false
	# As 3 cartas lendárias: a perda de tudo nunca é obrigatória.
	_keep_button.visible = all_legendary
	_set_focusable(true)

	for i: int in _cards.size():
		_cards[i].play_entrance(float(i) * CARD_STAGGER)


## Ignora toda entrada por `input_delay` segundos (evita escolher sem querer em combate) e depois foca a 1ª carta.
func _lock_input() -> void:
	_locked = true
	_lock_token += 1
	var token: int = _lock_token
	await get_tree().create_timer(input_delay, true, false, true).timeout
	if token != _lock_token:
		return  # abriu ou rerrolou de novo: quem veio por último destrava
	_locked = false
	if _is_open and not _cards.is_empty():
		_cards[0].grab_focus()


func close() -> void:
	_is_open = false
	_confirming = false
	visible = false
	_clear_cards()


func _clear_cards() -> void:
	for card: LevelUpCard in _cards:
		if is_instance_valid(card):
			_cards_box.remove_child(card)  # sai já: o reroll não pode deixar a carta velha aparecer junto
			card.queue_free()
	_cards.clear()


# --- Construção ---

func _build() -> void:
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = Palette.load_theme()  # tema dos menus só nesta raiz
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim: ColorRect = ColorRect.new()
	dim.color = Palette.dim_color()
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", BOX_SEPARATION)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)

	# Título
	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title_row)
	_title = Label.new()
	_title.theme_type_variation = &"PanelTitleLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_row.add_child(_title)

	_cards_box = HBoxContainer.new()
	_cards_box.add_theme_constant_override(&"separation", CARD_SEPARATION)
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_cards_box)

	_keep_button = PixelButton.new()
	_keep_button.text = "Manter minhas habilidades"
	_keep_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_keep_button.pressed.connect(_on_keep_pressed)
	_keep_button.visible = false
	box.add_child(_keep_button)

	_reroll_button = PixelButton.new()
	_reroll_button.text = REROLL_TEXT
	_reroll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_reroll_button.pressed.connect(_on_reroll_pressed)
	box.add_child(_reroll_button)

	_build_confirm()


## Passo de confirmação da lendária (lista o que será perdido).
func _build_confirm() -> void:
	_confirm = Control.new()
	_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_confirm)
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.visible = false

	var dim: ColorRect = ColorRect.new()
	dim.color = Palette.dim_color()
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel: PanelContainer = PanelContainer.new()
	center.add_child(panel)

	var column: VBoxContainer = VBoxContainer.new()
	panel.add_child(column)

	var heading: Label = Label.new()
	heading.text = "CONFIRMAR ESCOLHA LENDÁRIA"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override(&"font_color", Palette.DANGER)  # escolha lendária = perda (destrutiva)
	column.add_child(heading)

	_confirm_text = Label.new()
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_text.custom_minimum_size.x = CONFIRM_WIDTH
	column.add_child(_confirm_text)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	_confirm_ok = PixelButton.new()
	_confirm_ok.text = "Confirmar"
	_confirm_ok.custom_minimum_size = Vector2(Palette.UNIT * 16, 0.0)
	_confirm_ok.pressed.connect(_on_confirm_pressed)
	buttons.add_child(_confirm_ok)
	_confirm_back = PixelButton.new()
	_confirm_back.text = "Voltar"
	_confirm_back.custom_minimum_size = Vector2(Palette.UNIT * 16, 0.0)
	_confirm_back.pressed.connect(_on_back_pressed)
	buttons.add_child(_confirm_back)


# --- Interação ---

func _input(event: InputEvent) -> void:
	if _is_open and _confirming and not _locked and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _on_card_selected(data: AbilityData) -> void:
	if _locked or not _is_open or _confirming:
		return
	if data.rarity == AbilityData.Rarity.LENDARIA:
		_show_confirm(data)
	else:
		ability_chosen.emit(data)


func _show_confirm(data: AbilityData) -> void:
	_pending = data
	_confirming = true
	var lines: PackedStringArray = PackedStringArray()
	for owned: AbilityData in _owned:
		lines.append("• " + owned.display_name)
	var lost: String = "\n".join(lines) if not lines.is_empty() else "(nenhuma)"
	_confirm_text.text = "Ao escolher %s você perde TODAS as outras habilidades desta run:\n\n%s" % [data.display_name, lost]
	_confirm.visible = true
	_set_focusable(false)
	_confirm_back.grab_focus()


func _on_confirm_pressed() -> void:
	if _locked or _pending == null:
		return
	var data: AbilityData = _pending
	_pending = null
	ability_chosen.emit(data)


func _on_back_pressed() -> void:
	if not _confirming:
		return
	_confirming = false
	_confirm.visible = false
	_set_focusable(true)
	for card: LevelUpCard in _cards:
		if card.ability == _pending:
			card.grab_focus()
	_pending = null


func _on_reroll_pressed() -> void:
	if _locked or not _is_open or _confirming or _reroll_used:
		return
	reroll_requested.emit()


func _on_keep_pressed() -> void:
	if _locked or not _is_open or _confirming:
		return
	kept_current.emit()


## Liga/desliga o foco das cartas e do botão (o passo de confirmação tem o dele).
func _set_focusable(enabled: bool) -> void:
	var mode: Control.FocusMode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	for card: LevelUpCard in _cards:
		card.focus_mode = mode
	_keep_button.focus_mode = mode
	_reroll_button.focus_mode = mode
