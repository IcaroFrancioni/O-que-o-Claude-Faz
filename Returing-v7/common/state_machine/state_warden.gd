class_name StateWarden
extends BaseStateMachine
## StateWarden: máquina de estados dos inimigos com estados canônicos (Idle, Patrol, Chase, Attack, Dead).
## Aceita nomes variados de nós (ver CANDIDATES) e expõe a transição por enum.
##
## Por que a camada canônica existe: os estados pedem transições por NOME DE NÓ
## (request_transition(&"Chase")). Renomear um nó na cena, ou reaproveitar uma
## máquina em um inimigo que chama o estado de outro jeito, deixaria o pedido sem
## destino e o inimigo congelado. O Warden traduz o nome pedido para o estado
## canônico equivalente e cai no nó que existe: o inimigo degrada em vez de travar.
##
## Também guarda, sem custo por frame, o estado canônico atual, o anterior e há
## quanto tempo o inimigo está nele: o que a IA consulta com frequência vira leitura
## de campo, em vez de reclassificar o nome do nó a cada chamada.
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
var _current_canonical: State = State.NONE
var _previous_canonical: State = State.NONE
var _time_in_state: float = 0.0


## Resolve os nomes canônicos.
func _ready() -> void:
	# Conectado ANTES do super: start() já emite state_changed, e o estado
	# canônico atual precisa estar correto desde a primeira transição.
	state_changed.connect(_on_state_changed)
	super._ready()
	_resolve_canonical_states()


## Conta há quanto tempo o inimigo está no estado atual (tempo de jogo).
func _physics_process(delta: float) -> void:
	_time_in_state += delta
	super._physics_process(delta)


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
		_warn_once(StringName("canonical_%d" % canonical),
			"%s: sem nó de estado para %s (aceitos: %s). Estados registrados: %s." % [
				name, State.keys()[canonical], CANDIDATES[canonical], ", ".join(get_state_names())])
		return false
	return transition_to(_canonical_names[canonical])


## Estado canônico atual (NONE se não houver). Leitura direta: sem custo.
func get_canonical() -> State:
	return _current_canonical


## Estado canônico de onde o inimigo veio (NONE no primeiro estado).
func get_previous_canonical() -> State:
	return _previous_canonical


## Segundos de jogo no estado atual. Útil para IA ("já ataquei tempo demais").
func get_time_in_state() -> float:
	return _time_in_state


## True se o estado atual corresponde ao canônico.
func is_canonical(canonical: State) -> bool:
	return _current_canonical == canonical


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
## Nome de nó inexistente cai no estado canônico equivalente: um nó renomeado
## (ou um estado que pede &"Attack" num inimigo que só tem "AttackRanged")
## degrada para o mais próximo em vez de deixar o inimigo parado para sempre.
func transition_to(state_name: StringName) -> bool:
	if _dead and to_canonical(state_name) != State.DEAD:
		return false
	if has_state(state_name):
		return super.transition_to(state_name)

	var canonical: State = to_canonical(state_name)
	if canonical == State.NONE or not _canonical_names.has(canonical):
		_warn_once(state_name, "%s: estado '%s' não existe e não tem equivalente canônico. Registrados: %s." % [
			name, state_name, ", ".join(get_state_names())])
		return false
	var fallback: StringName = _canonical_names[canonical]
	_warn_once(state_name, "%s: estado '%s' não existe; usando '%s' (%s) no lugar." % [
		name, state_name, fallback, State.keys()[canonical]])
	return super.transition_to(fallback)


## Converte o nome de um nó de estado no estado canônico (por prefixo).
## Só roda em transição: get_canonical()/is_canonical() leem o campo já resolvido.
static func to_canonical(state_name: StringName) -> State:
	var key: String = String(state_name).to_lower()
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

	# Fallback: um nó com nome fora da lista (ex.: "SpecialAttack") ainda é
	# classificado por prefixo, para que o canônico não fique vazio à toa.
	for state_name: String in get_state_names():
		var canonical: State = to_canonical(StringName(state_name))
		if canonical != State.NONE and not _canonical_names.has(canonical):
			_canonical_names[canonical] = StringName(state_name)

	for required: State in REQUIRED:
		if not _canonical_names.has(required):
			push_warning("%s: nenhum nó de estado para %s (nomes aceitos: %s). Registrados: %s." % [
				name, State.keys()[required], CANDIDATES[required], ", ".join(get_state_names())])


## Trava a máquina ao entrar em Dead e emite o sinal canônico.
func _on_state_changed(previous: StringName, new_state: StringName) -> void:
	if _dead and to_canonical(new_state) == State.DEAD:
		locked = true
	_previous_canonical = to_canonical(previous)
	_current_canonical = to_canonical(new_state)
	_time_in_state = 0.0
	warden_state_changed.emit(_previous_canonical, _current_canonical)
