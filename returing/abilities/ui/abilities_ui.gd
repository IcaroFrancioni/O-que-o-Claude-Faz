class_name AbilitiesUI
extends CanvasLayer
## Interface das habilidades (filha do Player): HUD de comando, barra de XP e menu de level-up.
## Liga os sinais dos componentes e cuida da fila de level-ups: o menu só abre com o jogo livre
## (sem pausa, quiz ou Player morto); level-ups durante pausa ficam na fila.

@onready var _command_hud: CommandHud = $CommandHud
@onready var _touch_pad: TouchCommandPad = $TouchPad
@onready var _menu: LevelUpMenu = $LevelUpMenu
@onready var _build_menu: BuildMenu = $BuildMenu

var _player: Player = null
var _abilities: AbilityComponent = null
var _experience: ExperienceComponent = null
var _catalog: AbilityCatalog = null

## Níveis alcançados esperando o menu (em ordem).
var _queue: Array[int] = []
var _current_level: int = 0
var _current_offer: Array[AbilityData] = []
var _menu_open: bool = false
var _build_open: bool = false
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	_player = get_parent() as Player
	# Nas telas de fim de jogo e de fase concluída a interface das habilidades some.
	CombatUtils.connect_once(EventBus.game_over, _hide_for_end_screen)
	CombatUtils.connect_once(EventBus.level_completed, _hide_for_end_screen)
	_setup.call_deferred()


func _exit_tree() -> void:
	CombatUtils.disconnect_if_connected(EventBus.game_over, _hide_for_end_screen)
	CombatUtils.disconnect_if_connected(EventBus.level_completed, _hide_for_end_screen)
	if (_menu_open or _build_open) and is_inside_tree():
		get_tree().paused = false
		Input.mouse_mode = _previous_mouse_mode
	if is_instance_valid(_experience):
		CombatUtils.disconnect_if_connected(_experience.level_up, _on_level_up)


func _setup() -> void:
	if _player == null or not is_inside_tree():
		return
	_abilities = _player.get_node_or_null(^"AbilityComponent") as AbilityComponent
	_experience = _player.get_node_or_null(^"ExperienceComponent") as ExperienceComponent
	if _abilities == null or _experience == null:
		push_warning("AbilitiesUI: o Player precisa ter AbilityComponent e ExperienceComponent.")
		return
	_catalog = _abilities.catalog
	_command_hud.setup(_abilities)
	_touch_pad.setup(_abilities, _command_hud)
	CombatUtils.connect_once(_command_hud.slot_pressed, _on_slot_pressed)
	CombatUtils.connect_once(_touch_pad.build_requested, _on_slot_pressed)
	CombatUtils.connect_once(_build_menu.close_requested, _close_build_menu)
	CombatUtils.connect_once(_experience.level_up, _on_level_up)
	CombatUtils.connect_once(_menu.ability_chosen, _on_ability_chosen)
	CombatUtils.connect_once(_menu.kept_current, _on_kept_current)
	# Níveis que subiram em outra fase (ou antes do menu poder abrir) e ainda não foram resolvidos.
	for level: int in _experience.get_pending_levels():
		_queue.append(level)


func _hide_for_end_screen(_unused: Variant = null) -> void:
	visible = false


func _on_level_up(new_level: int) -> void:
	_queue.append(new_level)


## Abre o próximo menu assim que o jogo estiver livre. `_process` não roda com a árvore pausada,
## então pausa, quiz e o próprio menu seguram a fila automaticamente.
func _process(_delta: float) -> void:
	if _queue.is_empty() or _menu_open or _build_open or _player == null or _abilities == null:
		return
	if _player.esta_morto() or get_tree().paused:
		return
	_open_next()


func _open_next() -> void:
	var level: int = _queue.pop_front()
	_abilities.close_command_mode()  # devolve Engine.time_scale = 1.0 antes de pausar
	var offer: Array[AbilityData] = []
	if _catalog != null:
		offer = _catalog.draw_offer(level, RunState.excluded_ids())
	if offer.is_empty():
		RunState.resolve_level(level)  # nada para oferecer: pula o menu
		return
	_current_level = level
	_current_offer = offer
	_menu_open = true
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_menu.open(level, offer, _abilities.abilities)


func _on_ability_chosen(data: AbilityData) -> void:
	# As não escolhidas nunca mais aparecem nesta run.
	var rejected: Array[StringName] = []
	for offered: AbilityData in _current_offer:
		if offered != data:
			rejected.append(offered.id)
	RunState.reject(rejected)
	if data.rarity == AbilityData.Rarity.LENDARIA:
		_abilities.replace_all_with(data)
	else:
		_abilities.learn(data)
	_finish_menu()


func _on_kept_current() -> void:
	var rejected: Array[StringName] = []
	for offered: AbilityData in _current_offer:
		rejected.append(offered.id)
	RunState.reject(rejected)
	_finish_menu()


func _finish_menu() -> void:
	RunState.resolve_level(_current_level)
	_menu.close()
	_menu_open = false
	UiFx.swallow_attack_input()  # o clique na carta não pode virar um golpe
	get_tree().paused = false
	Input.mouse_mode = _previous_mouse_mode


# --- Menu de build (só leitura) ---

func _on_slot_pressed(ability: AbilityData) -> void:
	open_build_menu(ability.id)


## Abre o menu "SUA BUILD" com a habilidade `focus_id` em destaque. Pausa o jogo, como o menu de
## escolha. Não abre com outro menu aberto, a árvore pausada (quiz, pause) ou o Player morto.
func open_build_menu(focus_id: StringName = &"") -> bool:
	if _player == null or _abilities == null or _experience == null:
		return false
	if _build_open or _menu_open or get_tree().paused or _player.esta_morto() or not visible:
		return false
	_abilities.close_command_mode()  # devolve Engine.time_scale = 1.0 antes de pausar
	_build_open = true
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	UiFx.swallow_attack_input()
	_build_menu.open(_abilities, _experience, focus_id)
	return true


func _close_build_menu() -> void:
	if not _build_open:
		return
	_build_menu.close()
	_build_open = false
	UiFx.swallow_attack_input()  # o clique que fechou o menu não pode virar um golpe
	get_tree().paused = false
	Input.mouse_mode = _previous_mouse_mode
