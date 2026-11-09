class_name AbilityComponent
extends Node
## Cérebro do sistema de habilidades (filho do Player): modo comando, sequência de setas,
## cooldowns, ativação e efeitos ativos. Não conhece a HUD nem o menu: eles escutam os sinais.

signal command_mode_changed(ativo: bool)
signal input_progress(sequencia_atual: Array[int], candidatas: Array[AbilityData])
signal input_failed
signal ability_activated(ability: AbilityData)
signal cooldown_changed(ability: AbilityData, restante: float, total: float)
signal abilities_changed
## O jogador apertou o Ctrl mas o modo não pode abrir por um motivo que ele precisa saber
## (`&"sem_habilidades"`). Estar em dash ou golpe não gera aviso: o modo abre ao terminar.
signal command_unavailable(motivo: StringName)

## Ctrl: abre o modo comando (aperta de novo para cancelar). Não precisa segurar.
const ACTION_COMMAND: StringName = &"command_mode"
## Enter: confirma a sequência digitada.
const ACTION_CONFIRM: StringName = &"cmd_confirm"
## Backspace: apaga a última seta digitada.
const ACTION_BACK: StringName = &"cmd_back"
## Ação de cada seta digitada no modo comando.
const ARROW_ACTIONS: Dictionary = {
	&"cmd_up": AbilityData.Dir.UP,
	&"cmd_down": AbilityData.Dir.DOWN,
	&"cmd_left": AbilityData.Dir.LEFT,
	&"cmd_right": AbilityData.Dir.RIGHT,
}

@export var catalog: AbilityCatalog
## Habilidades que o jogador possui. No jogo real são restauradas do `RunState`;
## o valor do Inspector serve para testar no editor.
@export var abilities: Array[AbilityData] = []

@export_group("Câmera lenta")
## Escala de tempo durante o modo comando (1.0 desliga o efeito). Vale enquanto o modo está aberto,
## e o modo só fecha com Enter, Ctrl ou pausa.
@export_range(0.05, 1.0) var command_time_scale: float = 0.2

## Bônus de atributo ativos (único ponto consultado pelo Player e pelos efeitos).
var stats: StatModifiers = StatModifiers.new()
var command_active: bool = false

var _player: Player = null
var _sequence: Array[int] = []
## id da habilidade -> segundos restantes de recarga.
var _cooldowns: Dictionary = {}
var _effects: Array[AbilityEffect] = []
var _slowed: bool = false
## True quando o modo foi aberto por toque (celular): a habilidade dispara ao completar a sequência
## (não há Enter) e o modo fica aberto até tocar de novo.
var _toggle_mode: bool = false
var _setup_done: bool = false
var _weapon_base_scale: Vector2 = Vector2.ONE
## Fração de vida roubada ainda não convertida em 1 unidade de vida.
var _steal_accumulated: float = 0.0


func _ready() -> void:
	_player = get_parent() as Player
	if _player == null:
		push_warning("AbilityComponent: precisa ser filho direto do Player.")
		return
	stats.changed.connect(_apply_stats)
	# O Player termina o próprio _ready depois dos filhos: a configuração espera o fim do frame.
	_setup.call_deferred()


func _exit_tree() -> void:
	close_command_mode()
	CombatUtils.disconnect_if_connected(EventBus.level_restart_requested, RunState.mark_restart)
	if _player != null:
		CombatUtils.disconnect_if_connected(_player.morreu, _on_player_died)
		if _player.weapon != null:
			CombatUtils.disconnect_if_connected(_player.weapon.hit_landed, _on_weapon_hit_landed)


func _notification(what: int) -> void:
	# Pausa (menu de pausa, quiz, menu de level-up): sai do modo comando e devolve o tempo normal.
	if what == NOTIFICATION_PAUSED:
		close_command_mode()


func _setup() -> void:
	if _player == null or not is_inside_tree():
		return
	var scene_root: Node = _player.owner if _player.owner != null else get_tree().current_scene
	RunState.begin_scene(scene_root.scene_file_path if scene_root != null else "")
	if catalog != null:
		catalog.validate_once()
		if not RunState.owned_ids.is_empty():
			abilities.clear()
			for ability_id: StringName in RunState.owned_ids:
				var data: AbilityData = catalog.find_by_id(ability_id)
				if data != null:
					abilities.append(data)
	if _player.weapon != null:
		_weapon_base_scale = _player.weapon.scale
		CombatUtils.connect_once(_player.weapon.hit_landed, _on_weapon_hit_landed)
	CombatUtils.connect_once(_player.morreu, _on_player_died)
	CombatUtils.connect_once(EventBus.level_restart_requested, RunState.mark_restart)
	_setup_done = true
	abilities_changed.emit()


# --- Entrada ---

func _input(event: InputEvent) -> void:
	if not _setup_done:
		return
	# Ctrl (esquerdo ou direito): abre; apertar de novo cancela. Eco de tecla segurada é ignorado.
	if event.is_action_pressed(ACTION_COMMAND):
		if command_active:
			close_command_mode()
		elif abilities.is_empty():
			command_unavailable.emit(&"sem_habilidades")
		elif can_open_command_mode():
			_open_command_mode()
		return
	if not command_active:
		return
	if event.is_action_pressed(ACTION_CONFIRM):
		_confirm()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(ACTION_BACK):
		_erase_last_arrow()
		get_viewport().set_input_as_handled()
		return
	for action: StringName in ARROW_ACTIONS:
		if event.is_action_pressed(action):
			_on_arrow(int(ARROW_ACTIONS[action]))
			get_viewport().set_input_as_handled()
			return


## Abre com habilidades, vivo e sem pausa/quiz/menu (todos pausam a árvore). O jogador continua
## livre para andar, esquivar e atacar enquanto o modo está aberto.
func can_open_command_mode() -> bool:
	if not _setup_done or _player == null or abilities.is_empty() or get_tree().paused:
		return false
	return not _player.esta_morto()


## Celular: abre ou fecha o modo comando com um toque (não há tecla para segurar).
func toggle_command_mode() -> void:
	if command_active:
		close_command_mode()
	elif can_open_command_mode():
		_open_command_mode(true)


## Celular: digita uma seta (valor de `AbilityData.Dir`) no modo comando.
func press_arrow(dir: int) -> void:
	if command_active:
		_on_arrow(dir)


func _open_command_mode(by_touch: bool = false) -> void:
	_toggle_mode = by_touch
	command_active = true
	_sequence.clear()
	if command_time_scale < 1.0:
		Engine.time_scale = command_time_scale
		_slowed = true
	command_mode_changed.emit(true)
	input_progress.emit(_sequence.duplicate(), _candidates())


## Fecha o modo comando, apaga a sequência e devolve `Engine.time_scale = 1.0`.
## Seguro de chamar a qualquer momento (soltar a tecla, morte, pausa, level-up, troca de cena).
func close_command_mode() -> void:
	if _slowed:
		Engine.time_scale = 1.0
		_slowed = false
	if not command_active:
		return
	command_active = false
	_toggle_mode = false
	_sequence.clear()
	command_mode_changed.emit(false)


func _on_player_died() -> void:
	close_command_mode()
	_cancel_all_effects()


# --- Sequência ---

func _on_arrow(dir: int) -> void:
	_sequence.append(dir)
	var candidatas: Array[AbilityData] = _candidates()
	if candidatas.is_empty():
		_fail()
		return
	# Teclado: só digita; quem dispara é o Enter. Celular (sem Enter): dispara ao completar.
	if _toggle_mode and _try_activate():
		input_progress.emit(_sequence.duplicate(), _candidates())
		return
	input_progress.emit(_sequence.duplicate(), candidatas)


## Enter: dispara a habilidade cuja sequência é exatamente a digitada e fecha o modo.
## Sequência que não bate (ou habilidade em recarga) conta como erro e zera o que foi digitado.
func _confirm() -> void:
	if _sequence.is_empty():
		return
	if _try_activate():
		close_command_mode()
	else:
		_fail()


## Ativa a habilidade que combina exatamente com a sequência digitada. False se nenhuma combina
## ou se está em recarga (a sequência é mantida; quem chamou decide se trata como erro).
func _try_activate() -> bool:
	for data: AbilityData in _candidates():
		if data.sequence.size() != _sequence.size():
			continue
		if get_cooldown_left(data.id) > 0.0:
			if _toggle_mode:
				_fail()  # celular: em recarga, trata como erro na hora
				return true
			return false
		_sequence.clear()
		_activate(data)
		return true
	return false


func _erase_last_arrow() -> void:
	if _sequence.is_empty():
		return
	_sequence.pop_back()
	input_progress.emit(_sequence.duplicate(), _candidates())


func _fail() -> void:
	_sequence.clear()
	input_failed.emit()
	input_progress.emit(_sequence.duplicate(), _candidates())


## Habilidades cuja sequência começa com o que já foi digitado.
func _candidates() -> Array[AbilityData]:
	var result: Array[AbilityData] = []
	for data: AbilityData in abilities:
		if data.sequence.size() < _sequence.size():
			continue
		var combina: bool = true
		for i: int in _sequence.size():
			if data.sequence[i] != _sequence[i]:
				combina = false
				break
		if combina:
			result.append(data)
	return result


# --- Ativação e cooldown ---

func _activate(data: AbilityData) -> void:
	_cooldowns[data.id] = data.cooldown
	cooldown_changed.emit(data, data.cooldown, data.cooldown)
	_prune_effects()
	_cancel_effects_of(data.id)
	if data.effect_scene != null:
		var effect: AbilityEffect = data.effect_scene.instantiate() as AbilityEffect
		if effect == null:
			push_warning("AbilityComponent: a cena de '%s' precisa ter AbilityEffect na raiz." % data.id)
		else:
			effect.data = data
			_effects.append(effect)
			_player.add_child(effect)
			effect.activate(_player)
	ability_activated.emit(data)


func _physics_process(delta: float) -> void:
	if _cooldowns.is_empty():
		return
	for ability_id: StringName in _cooldowns.keys():
		var restante: float = maxf(float(_cooldowns[ability_id]) - delta, 0.0)
		if restante <= 0.0:
			_cooldowns.erase(ability_id)
		else:
			_cooldowns[ability_id] = restante
		var data: AbilityData = _find_owned(ability_id)
		if data != null:
			cooldown_changed.emit(data, restante, data.cooldown)


## Segundos restantes de recarga (0 = pronta).
func get_cooldown_left(ability_id: StringName) -> float:
	return float(_cooldowns.get(ability_id, 0.0))


func has_ability(ability_id: StringName) -> bool:
	return _find_owned(ability_id) != null


## True se alguma habilidade possuída é lendária.
func has_legendary() -> bool:
	for data: AbilityData in abilities:
		if data.rarity == AbilityData.Rarity.LENDARIA:
			return true
	return false


func _find_owned(ability_id: StringName) -> AbilityData:
	for data: AbilityData in abilities:
		if data.id == ability_id:
			return data
	return null


# --- Aprender e substituir ---

## Acrescenta uma habilidade.
func learn(data: AbilityData) -> void:
	if data == null or has_ability(data.id):
		return
	abilities.append(data)
	if not RunState.owned_ids.has(data.id):
		RunState.owned_ids.append(data.id)
	abilities_changed.emit()


## Lendária: remove todas as outras, cancela os efeitos ativos e zera os cooldowns das removidas.
func replace_all_with(data: AbilityData) -> void:
	if data == null:
		return
	_cancel_all_effects()
	_cooldowns.clear()
	stats.clear()
	abilities.clear()
	abilities.append(data)
	RunState.owned_ids.clear()
	RunState.owned_ids.append(data.id)
	abilities_changed.emit()


func _cancel_all_effects() -> void:
	for effect: AbilityEffect in _effects:
		if is_instance_valid(effect) and not effect.is_queued_for_deletion():
			effect.cancel()
	_effects.clear()


## Reativar uma habilidade que ainda está ativa renova o efeito: o antigo é desfeito e não acumula.
func _cancel_effects_of(ability_id: StringName) -> void:
	for i: int in range(_effects.size() - 1, -1, -1):
		var effect: AbilityEffect = _effects[i]
		if is_instance_valid(effect) and not effect.is_queued_for_deletion() \
				and effect.data != null and effect.data.id == ability_id:
			effect.cancel()
			_effects.remove_at(i)


func _prune_effects() -> void:
	for i: int in range(_effects.size() - 1, -1, -1):
		if not is_instance_valid(_effects[i]) or _effects[i].is_queued_for_deletion():
			_effects.remove_at(i)


# --- Atributos que dependem de nós externos ---

## Reaplica o que os modificadores mudam fora do Player: área e dano da espada e vida máxima.
func _apply_stats() -> void:
	if not _setup_done or not is_instance_valid(_player) or not _player.is_inside_tree():
		return
	var weapon: Weapon = _player.weapon
	if weapon != null:
		weapon.scale = _weapon_base_scale * stats.get_mult(StatModifiers.SWORD_AREA)
		weapon.damage = roundi(float(_player.sword_damage) * stats.get_mult(StatModifiers.DAMAGE))
	_player.recalcular_hp_maximo()


## Roubo de vida: acumula a fração do dano e cura quando completa 1 unidade.
func _on_weapon_hit_landed(_target: Node, damage_dealt: int) -> void:
	var rate: float = stats.get_add(StatModifiers.LIFE_STEAL)
	if rate <= 0.0 or not is_instance_valid(_player):
		return
	_steal_accumulated += float(damage_dealt) * rate
	var inteiro: int = int(_steal_accumulated)
	if inteiro > 0:
		_steal_accumulated -= float(inteiro)
		_player.curar(inteiro)
