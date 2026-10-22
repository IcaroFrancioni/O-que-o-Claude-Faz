class_name StateWarden
extends BaseStateMachine
## StateWarden: máquina de estados dos inimigos com estados canônicos (Idle, Patrol, Chase, Attack, Dead).
## Aceita nomes variados de nós (ver CANDIDATES) e expõe a transição por enum.
enum State { IDLE, CHASE, ATTACK, DEAD, PATROL, NONE }

## Equivalente de `state_changed`, já traduzido para estados canônicos.
signal warden_state_changed(previous: State, current: State)
## Emitido uma única vez quando die() é chamado.
signal warden_died

const CANDIDATES: Dictionary = {
	State.IDLE: [&"idle", &"idlestate"],
	State.CHASE: [&"chase", &"chasestate"],
	State.ATTACK: [&"attack", &"attackstate", &"attackranged", &"attackmelee"],
	State.DEAD: [&"dead", &"deadstate", &"death", &"deathstate"],
	State.PATROL: [&"patrol", &"patrolstate", &"wander"],
}
## Estados canônicos que todo inimigo precisa ter (Patrol é opcional).
const REQUIRED: Array = [State.IDLE, State.CHASE, State.ATTACK]

var _canonical_names: Dictionary[State, StringName] = {}
var _dead: bool = false


## Resolve os nomes canônicos.
func _ready() -> void:
	super._ready()
	_resolve_canonical_states()
	state_changed.connect(_on_state_changed)

## True se existe um nó para o estado canônico.
func has_canonical(canonical: State) -> bool:
	return _canonical_names.has(canonical)


## Pede a troca para um estado. true se a troca ocorreu.
func request(canonical: State) -> bool:
	if _dead:
		return false
	if canonical == State.DEAD:
		die()
		return true
	if not _canonical_names.has(canonical):
		push_warning("%s: sem nó de estado para %s." % [name, State.keys()[canonical]])
		return false
	return transition_to(_canonical_names[canonical])


## Estado canônico atual (NONE se não houver).
func get_canonical() -> State:
	return to_canonical(current_state.name) if current_state != null else State.NONE


## True se o estado atual corresponde ao canônico.
func is_canonical(canonical: State) -> bool:
	return get_canonical() == canonical


## True depois de die().
func is_dead() -> bool:
	return _dead


## Morte: entra no estado Dead e trava a máquina; sem estado Dead, apenas a encerra.
func die() -> void:
	if _dead:
		return
	_dead = true
	var dead_name: StringName = _canonical_names[State.DEAD] if _canonical_names.has(State.DEAD) else &""
	if dead_name != &"" and transition_to(dead_name):
		# Se die() veio de um enter()/exit(), a transição fica pendente e o
		# bloqueio é aplicado em _on_state_changed.
		if is_in_state(dead_name):
			locked = true  # nada tira o inimigo do estado de morte
	else:
		stop()
	warden_died.emit()


## Depois de die() só o estado Dead é aceito.
func transition_to(state_name: StringName) -> bool:
	if _dead and to_canonical(state_name) != State.DEAD:
		return false
	return super.transition_to(state_name)


## Converte o nome de um nó de estado no estado canônico (por prefixo).
static func to_canonical(state_name: StringName) -> State:
	var key := String(state_name).to_lower()
	if key.is_empty():
		return State.NONE
	if key.begins_with("idle"):
		return State.IDLE
	if key.begins_with("chase"):
		return State.CHASE
	if key.begins_with("patrol") or key.begins_with("wander"):
		return State.PATROL
	if key.begins_with("dead") or key.begins_with("death"):
		return State.DEAD
	if key.contains("attack") or key.begins_with("energywave"):
		return State.ATTACK
	return State.NONE

## Localiza os nós Idle/Chase/Attack/Dead entre os filhos.
func _resolve_canonical_states() -> void:
	_canonical_names.clear()
	for canonical: State in CANDIDATES:
		for candidate: StringName in CANDIDATES[canonical]:
			if has_state(candidate):
				_canonical_names[canonical] = get_state(candidate).name
				break

	for required: State in REQUIRED:
		if not _canonical_names.has(required):
			push_warning("%s: nenhum nó de estado para %s (nomes aceitos: %s)." % [
				name, State.keys()[required], CANDIDATES[required]])


## Trava a máquina ao entrar em Dead e emite o sinal canônico.
func _on_state_changed(previous: StringName, new_state: StringName) -> void:
	if _dead and to_canonical(new_state) == State.DEAD:
		locked = true
	warden_state_changed.emit(to_canonical(previous), to_canonical(new_state))
