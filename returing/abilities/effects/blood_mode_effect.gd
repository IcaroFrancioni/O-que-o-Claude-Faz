class_name BloodModeEffect
extends StatBuffEffect
## Modo Sanguinário (lendária): cada inimigo morto durante o efeito dá aumento temporário de ataque
## (acumula até o teto) e recupera vida.

@export_group("Sanguinário")
## Bônus de ataque por abate (0.05 = +5%).
@export_range(0.0, 1.0, 0.01) var damage_per_kill: float = 0.05
## Máximo de abates acumulados (teto de bônus = damage_per_kill x max_stacks).
@export_range(1, 50) var max_stacks: int = 10
## Vida recuperada por abate.
@export_range(0, 50) var heal_per_kill: int = 2

var _stacks: int = 0


func _on_activate() -> void:
	CombatUtils.connect_once(EventBus.enemy_died, _on_enemy_died)
	super._on_activate()


func _apply_stats() -> void:
	super._apply_stats()
	var stats: StatModifiers = get_stats()
	if stats != null and _stacks > 0:
		stats.add(StatModifiers.DAMAGE, 1.0 + damage_per_kill * float(_stacks), StatModifiers.Mode.MULT, self)


func _on_enemy_died(_enemy: Node2D, _kind: StringName, _world_position: Vector2) -> void:
	if not is_instance_valid(caster) or caster.esta_morto():
		return
	_stacks = mini(_stacks + 1, max_stacks)
	_refresh_stats()
	if heal_per_kill > 0:
		caster.curar(heal_per_kill)


func _on_cleanup() -> void:
	CombatUtils.disconnect_if_connected(EventBus.enemy_died, _on_enemy_died)
	super._on_cleanup()
