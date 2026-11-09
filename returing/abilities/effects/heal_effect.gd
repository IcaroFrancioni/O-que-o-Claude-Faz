class_name HealEffect
extends AbilityEffect
## Cura: recupera algumas unidades da barra de vida (a barra tem `bar_total` quadros).
## A cura passa por `Player.curar`, que já aplica o bônus de cura recebida.

@export_group("Cura")
## Unidades da barra recuperadas e total de unidades da barra.
@export_range(1, 12) var bar_units: int = 4
@export_range(1, 24) var bar_total: int = 12
@export var heal_color: Color = Color(0.4, 1.0, 0.5, 1.0)
## Duração (s) do símbolo de cura subindo.
@export_range(0.1, 2.0, 0.05) var show_time: float = 0.7

var _age: float = 0.0


func _on_activate() -> void:
	var amount: int = roundi(float(caster.hp_maximo) * float(bar_units) / float(maxi(bar_total, 1)))
	caster.curar(maxi(amount, 1))
	queue_redraw()


func _physics_process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= show_time:
		_finish()


func _draw() -> void:
	var t: float = clampf(_age / show_time, 0.0, 1.0)
	var cor: Color = heal_color
	cor.a = 1.0 - t
	var centro: Vector2 = Vector2(0.0, -20.0 - 22.0 * t)
	var braco: float = 7.0
	var grossura: float = 3.0
	draw_line(centro + Vector2(-braco, 0.0), centro + Vector2(braco, 0.0), cor, grossura)
	draw_line(centro + Vector2(0.0, -braco), centro + Vector2(0.0, braco), cor, grossura)
