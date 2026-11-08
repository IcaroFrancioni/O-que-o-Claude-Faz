class_name StatBuffEffect
extends AbilityEffect
## Buff genérico de atributos. Os valores vêm do `.tres` da habilidade (`stat_mult` e `stat_add`),
## então várias habilidades reaproveitam esta mesma cena. Dura `data.duration` segundos.

var _time_left: float = 0.0


func _on_activate() -> void:
	_apply_stats()
	_time_left = data.duration if data != null else 0.0
	if _time_left <= 0.0:
		_finish()


func _physics_process(delta: float) -> void:
	if _time_left <= 0.0:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_finish()


func _on_cleanup() -> void:
	var stats: StatModifiers = get_stats()
	if stats != null:
		stats.remove_source(self)


## Registra os modificadores da habilidade (filhas podem acrescentar outros).
func _apply_stats() -> void:
	var stats: StatModifiers = get_stats()
	if stats == null or data == null:
		return
	for key: Variant in data.stat_mult:
		stats.add(StringName(key), float(data.stat_mult[key]), StatModifiers.Mode.MULT, self)
	for key: Variant in data.stat_add:
		stats.add(StringName(key), float(data.stat_add[key]), StatModifiers.Mode.ADD, self)


## Remove e registra de novo os modificadores (usado quando o valor muda durante o efeito).
func _refresh_stats() -> void:
	var stats: StatModifiers = get_stats()
	if stats == null:
		return
	stats.remove_source(self)
	_apply_stats()
