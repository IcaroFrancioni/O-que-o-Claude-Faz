class_name AbilityEffect
extends Node2D
## Base dos efeitos de habilidade. A cena do efeito é instanciada como filha do Player.
## As filhas sobrescrevem `_on_activate()` e `_on_cleanup()`; o efeito se remove sozinho ao terminar.

## Dados da habilidade que gerou o efeito (preenchido antes de `activate`).
var data: AbilityData = null
var caster: Player = null

var _cleaned: bool = false


## Liga o efeito.
func activate(new_caster: Player) -> void:
	caster = new_caster
	_on_activate()


## Interrompe o efeito (morte do Player, lendária apagando as outras) e desfaz o que ele aplicou.
func cancel() -> void:
	_cleanup()
	queue_free()


func _exit_tree() -> void:
	_cleanup()


## Termina normalmente: desfaz o que aplicou e some.
func _finish() -> void:
	_cleanup()
	queue_free()


## Modificadores de atributo do Player (null se o componente já não existe).
func get_stats() -> StatModifiers:
	if not is_instance_valid(caster):
		return null
	var component: AbilityComponent = caster.abilities
	if not is_instance_valid(component):
		return null
	return component.stats


func _cleanup() -> void:
	if _cleaned:
		return
	_cleaned = true
	_on_cleanup()


## Gancho: começa o efeito.
func _on_activate() -> void:
	pass


## Gancho: desfaz tudo que o efeito aplicou (roda uma única vez).
func _on_cleanup() -> void:
	pass
