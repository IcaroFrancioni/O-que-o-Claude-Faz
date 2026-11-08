class_name PiercingProjectile
extends PlayerProjectile
## Tiro Perfurante: igual ao tiro do Player, mas atravessa inimigos (cada um é atingido uma vez).
## Continua parando nas paredes. Não altera `PlayerProjectile`: só sobrescreve o acerto em hurtbox.

var _already_hit: Dictionary = {}


func _on_pool_activate() -> void:
	_already_hit.clear()


## Bateu em uma hurtbox: causa dano e segue em frente.
func _on_area_entered(area: Area2D) -> void:
	if _consumido or not area.is_in_group(CombatUtils.GROUP_HURTBOX):
		return
	var alvo: Node = CombatUtils.get_actor(area)
	if alvo == shooter or alvo == null:
		return
	var id: int = alvo.get_instance_id()
	if _already_hit.has(id):
		return
	_already_hit[id] = true
	_aplicar_dano(area, alvo)
