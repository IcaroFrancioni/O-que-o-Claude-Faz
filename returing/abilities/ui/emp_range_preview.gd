class_name EmpRangePreview
extends Node2D
## Prévia do alcance do Pulso EMP: um círculo fraco e translúcido ao redor do Player, com o raio real
## do efeito, para ajudar a posicionar antes de usar. Aparece com o modo comando aberto, o EMP fora de
## recarga e a sequência digitada (a partir da 1ª seta) ainda combinando com o EMP. Some ao fechar o
## modo, errar, ativar ou entrar em recarga.
## Só ESCUTA os sinais do `AbilityComponent` (ele não conhece esta prévia). O raio vem do mesmo
## `radius` da cena do efeito (`EmpPulseEffect.DEFAULT_RADIUS` se a cena não o altera): fonte única.

const EMP_ID: StringName = &"pulso_emp"
@export var fill_color: Color = Color(0.45, 0.85, 1.0, 0.07)
@export var line_color: Color = Color(0.45, 0.85, 1.0, 0.4)
@export var line_width: float = 2.0

var _abilities: AbilityComponent = null
var _emp: AbilityData = null
var _radius: float = EmpPulseEffect.DEFAULT_RADIUS
var _sequence: Array[int] = []
var _candidates: Array[AbilityData] = []
var _active: bool = false


## Liga a prévia ao componente do Player (esta prévia é filha do Player).
func setup(abilities: AbilityComponent) -> void:
	_abilities = abilities
	top_level = true  # o raio é em px do mundo, sem herdar a escala do Player
	visible = false
	set_process(false)
	CombatUtils.connect_once(abilities.input_progress, _on_input_progress)
	CombatUtils.connect_once(abilities.command_mode_changed, _on_mode_changed)
	CombatUtils.connect_once(abilities.cooldown_changed, _on_cooldown_changed)
	CombatUtils.connect_once(abilities.ability_activated, _on_ability_activated)
	CombatUtils.connect_once(abilities.abilities_changed, _find_emp)
	_find_emp()


func _exit_tree() -> void:
	if not is_instance_valid(_abilities):
		return
	CombatUtils.disconnect_if_connected(_abilities.input_progress, _on_input_progress)
	CombatUtils.disconnect_if_connected(_abilities.command_mode_changed, _on_mode_changed)
	CombatUtils.disconnect_if_connected(_abilities.cooldown_changed, _on_cooldown_changed)
	CombatUtils.disconnect_if_connected(_abilities.ability_activated, _on_ability_activated)
	CombatUtils.disconnect_if_connected(_abilities.abilities_changed, _find_emp)


## Raio (px) que a prévia desenha (o mesmo do efeito).
func get_radius() -> float:
	return _radius


func _find_emp() -> void:
	_emp = null
	for data: AbilityData in _abilities.abilities:
		if data.id == EMP_ID:
			_emp = data
	if _emp != null:
		_radius = float(CombatUtils.get_scene_root_property(_emp.effect_scene, &"radius", EmpPulseEffect.DEFAULT_RADIUS))
	_refresh()


func _on_input_progress(sequence: Array[int], candidates: Array[AbilityData]) -> void:
	_sequence = sequence
	_candidates = candidates
	_refresh()


func _on_mode_changed(_active_now: bool) -> void:
	_sequence = []
	_candidates = []
	_refresh()


func _on_cooldown_changed(_ability: AbilityData, _remaining: float, _total: float) -> void:
	_refresh()


func _on_ability_activated(_ability: AbilityData) -> void:
	_sequence = []
	_candidates = []
	_refresh()


## Decide se o círculo aparece.
func _refresh() -> void:
	_active = _abilities != null and _abilities.command_active and _emp != null \
			and _abilities.get_cooldown_left(EMP_ID) <= 0.0 \
			and not _sequence.is_empty() and _candidates.has(_emp)
	visible = _active
	set_process(_active)
	if _active:
		_follow_player()
		queue_redraw()


func _process(_delta: float) -> void:
	_follow_player()


func _follow_player() -> void:
	var player: Node2D = get_parent() as Node2D
	if player != null:
		global_position = player.global_position


func _draw() -> void:
	if not _active:
		return
	draw_circle(Vector2.ZERO, _radius, fill_color)
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 64, line_color, line_width)
