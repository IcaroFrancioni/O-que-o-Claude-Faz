class_name StatModifiers
extends RefCounted
## Único ponto de bônus de atributo das habilidades.
## Efeitos registram modificadores com `fonte = self` e removem tudo com `remove_source(self)`.

## Avisa quando qualquer modificador entra ou sai (o AbilityComponent reaplica o que depende disso).
signal changed

## MULT: `valor` é o multiplicador final (1.2 = +20%). Vários MULT se multiplicam.
## ADD: `valor` é somado (0.05 = +5 pontos percentuais, ou +N unidades).
enum Mode { MULT, ADD }

const MOVE_SPEED: StringName = &"move_speed"
const DASH_DISTANCE: StringName = &"dash_distance"
const PROJECTILE_SPEED: StringName = &"projectile_speed"
const SWORD_AREA: StringName = &"sword_area"
const LIFE_STEAL: StringName = &"life_steal"
const MAX_HEALTH: StringName = &"max_health"
const HEAL_RECEIVED: StringName = &"heal_received"
const DAMAGE: StringName = &"damage"

## Cada item: { "stat": StringName, "value": float, "mode": Mode, "source": int (instance id) }.
var _entries: Array[Dictionary] = []


## Registra um modificador. `fonte` identifica quem o criou (para remover depois).
func add(stat: StringName, valor: float, modo: Mode, fonte: Object) -> void:
	if fonte == null:
		push_warning("StatModifiers.add: 'fonte' nula; o modificador não poderá ser removido.")
		return
	_entries.append({
		"stat": stat,
		"value": valor,
		"mode": modo,
		"source": fonte.get_instance_id(),
	})
	changed.emit()


## Remove todos os modificadores registrados pela fonte.
func remove_source(fonte: Object) -> void:
	if fonte == null:
		return
	var id: int = fonte.get_instance_id()
	var removeu: bool = false
	for i: int in range(_entries.size() - 1, -1, -1):
		if _entries[i]["source"] == id:
			_entries.remove_at(i)
			removeu = true
	if removeu:
		changed.emit()


## Remove tudo (ex.: lendária apagando as outras habilidades).
func clear() -> void:
	if _entries.is_empty():
		return
	_entries.clear()
	changed.emit()


## Produto de todos os modificadores MULT do atributo (1.0 se não houver).
func get_mult(stat: StringName) -> float:
	var total: float = 1.0
	for entry: Dictionary in _entries:
		if entry["stat"] == stat and entry["mode"] == Mode.MULT:
			total *= float(entry["value"])
	return total


## Soma de todos os modificadores ADD do atributo (0.0 se não houver).
func get_add(stat: StringName) -> float:
	var total: float = 0.0
	for entry: Dictionary in _entries:
		if entry["stat"] == stat and entry["mode"] == Mode.ADD:
			total += float(entry["value"])
	return total
