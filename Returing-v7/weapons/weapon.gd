class_name Weapon
extends Node2D
## Base de armas empunhadas por personagens.
## Contrato com o portador (wielder):
##   1. equip(portador)          -> a arma passa a ignorar a Hurtbox do portador
##   2. attack(direção) -> bool  -> inicia um ataque (false = ocupado / em recarga)
##   3. attack_finished(ok)      -> SEMPRE emitido uma vez por ataque iniciado,
##                                  inclusive quando cancel() interrompe o golpe
##   4. hit_landed(alvo, dano)   -> cada acerto confirmado.

signal attack_started
signal attack_finished(completed: bool)
signal hit_landed(target: Node, damage_dealt: int)

@export var damage: int = 10
## Espera mínima entre o fim de um ataque e o próximo.
@export_range(0.0, 5.0, 0.01, "or_greater") var cooldown: float = 0.0

var wielder: Node = null

var _attacking: bool = false
## Recarga restante em segundos de jogo. Contada por delta (e não pelo relógio do
## sistema) para respeitar a pausa e o Engine.time_scale, como o resto do projeto.
var _cooldown_left: float = 0.0


func _ready() -> void:
	set_physics_process(false)  # só conta enquanto houver recarga pendente


## Desconta a recarga; desliga o processamento assim que ela termina.
func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _cooldown_left <= 0.0:
		set_physics_process(false)


## Associa a arma ao portador.
func equip(new_wielder: Node) -> void:
	wielder = new_wielder
	_on_equipped()


func is_attacking() -> bool:
	return _attacking


func can_attack() -> bool:
	return not _attacking and _cooldown_left <= 0.0


## Inicia um ataque na direção dada. Subclasses implementam _start_attack().
func attack(direction: Vector2) -> bool:
	if not can_attack():
		return false
	_attacking = true
	attack_started.emit()
	_start_attack(direction if direction != Vector2.ZERO else Vector2.RIGHT)
	return true


## Reorienta a arma durante o ataque (ex.: acompanhar o cursor do mouse).
## Padrão: não faz nada. Subclasses decidem em quais fases aceitam a nova direção.
func aim_at(_direction: Vector2) -> void:
	pass


## Interrompe o ataque atual (morte, stun, dash...). Seguro chamar a qualquer momento.
func cancel() -> void:
	if not _attacking:
		return
	_stop_attack()
	_finish(false)


## Duração total de um ataque (usada para sincronizar a animação do portador).
func get_attack_duration() -> float:
	return 0.0


## Chamado pelas subclasses ao concluir (ou abortar) o golpe.
func _finish(completed: bool) -> void:
	if not _attacking:
		return
	_attacking = false
	_cooldown_left = maxf(cooldown, 0.0)
	set_physics_process(_cooldown_left > 0.0)
	attack_finished.emit(completed)


func _on_equipped() -> void:
	pass


func _start_attack(_direction: Vector2) -> void:
	_finish(true)


func _stop_attack() -> void:
	pass
