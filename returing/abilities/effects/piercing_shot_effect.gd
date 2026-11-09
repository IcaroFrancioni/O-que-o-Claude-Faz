class_name PiercingShotEffect
extends AbilityEffect
## Tiro Perfurante: dispara um projétil de dano máximo na direção do cursor que atravessa inimigos.
## Reaproveita `PlayerProjectile` (subclasse) e o `PoolHub`.

## Quantos frames espera o pool criar a primeira instância antes de desistir.
const MAX_ATTEMPTS: int = 12

@export var projectile_scene: PackedScene
## 0 usa o dano do tiro com carga máxima do Player (`max_damage`).
@export var damage_override: int = 0

var _attempts: int = 0


func _on_activate() -> void:
	if projectile_scene == null:
		push_warning("PiercingShotEffect: 'projectile_scene' não atribuída.")
		_finish()
		return
	PoolHub.prewarm(projectile_scene, caster, 2)
	_try_fire()


## Enquanto o pool ainda cria a instância, tenta de novo a cada frame.
func _physics_process(_delta: float) -> void:
	_try_fire()


func _try_fire() -> void:
	if _cleaned:
		return
	if not is_instance_valid(caster) or not caster.is_inside_tree():
		_finish()
		return
	var shot: PiercingProjectile = PoolHub.acquire(projectile_scene, caster, PiercingProjectile) as PiercingProjectile
	if shot == null:
		_attempts += 1
		if _attempts >= MAX_ATTEMPTS:
			push_warning("PiercingShotEffect: o pool não entregou o projétil.")
			_finish()
		return
	var dano: int = damage_override if damage_override > 0 else caster.max_damage
	# Sem mira assistida (último parâmetro): o tiro segue a linha bruta do cursor/toque, sem curvar para
	# o inimigo. Vale só para este tiro; o tiro carregado normal continua usando `Platform.aim_assist`.
	shot.launch(caster.get_muzzle_position(), caster.get_shot_direction(), dano, 1.0, caster, false)
	CombatUtils.connect_once(shot.damage_dealt, Callable(caster, &"_on_projectile_damage_dealt"))
	_finish()
