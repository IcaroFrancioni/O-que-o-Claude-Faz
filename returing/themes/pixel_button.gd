class_name PixelButton
extends Button
## Botão de menu com o comportamento da identidade visual:
##  - hover ou foco: sobe 2 px e cresce 4% (Tween curto); borda e texto vão para a cor de destaque;
##  - apertado: afunda 2 px;
##  - o foco de teclado/gamepad tem EXATAMENTE o mesmo visual do hover e fica sempre visível;
##  - passar o mouse move o foco para o botão, então só um botão fica destacado por vez.
## As cores e bordas de cada estado vêm do tema (PixelTheme). Scripts de botões específicos
## devem estender esta classe e chamar `super()` no `_ready`.

## Quanto o botão sobe (px) com hover/foco.
@export_range(0.0, 8.0, 0.5) var lift_px: float = 2.0
## Quanto o botão afunda (px) ao ser apertado.
@export_range(0.0, 8.0, 0.5) var sink_px: float = 2.0
## Escala com hover/foco.
@export_range(1.0, 1.2, 0.01) var hover_scale: float = 1.04

## Deslocamento vertical que ESTE script aplicou (negativo = sobe).
var _lift_applied: float = 0.0
var _last_y: float = 0.0
var _applying: bool = false
var _tween: Tween = null


func _ready() -> void:
	# O destaque de foco é feito por este script; o estilo "focus" do tema ficaria por cima do "pressed".
	add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	_update_pivot()
	_last_y = position.y
	CombatUtils.connect_once(resized, _update_pivot)
	CombatUtils.connect_once(item_rect_changed, _on_item_rect_changed)
	CombatUtils.connect_once(mouse_entered, _on_mouse_entered)
	CombatUtils.connect_once(mouse_exited, _refresh)
	CombatUtils.connect_once(focus_entered, _refresh)
	CombatUtils.connect_once(focus_exited, _refresh)
	CombatUtils.connect_once(button_down, _refresh)
	CombatUtils.connect_once(button_up, _refresh)
	# Depois do clique o botão pode ter sido desabilitado (ex.: Start): reavalia no quadro seguinte.
	CombatUtils.connect_once(pressed, _refresh_deferred)
	_refresh(true)


func _exit_tree() -> void:
	_kill_tween()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree():
		_refresh(true)


func _update_pivot() -> void:
	pivot_offset = size * 0.5


func _on_mouse_entered() -> void:
	if not disabled and focus_mode != Control.FOCUS_NONE and not has_focus():
		grab_focus()
	_refresh()


func _refresh_deferred() -> void:
	_refresh.call_deferred()


## Aplica o visual do estado atual. `instant` pula a animação (abertura da tela, botão escondido).
func _refresh(instant: bool = false) -> void:
	_update_focus_look()
	var target_lift: float = 0.0
	var target_scale: float = 1.0
	var mode: DrawMode = get_draw_mode()
	if not disabled and is_visible_in_tree():
		if mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED:
			target_lift = sink_px
		elif has_focus() or is_hovered():
			target_lift = -lift_px
			target_scale = hover_scale
	_animate_to(target_lift, target_scale, instant)


## Foco sem mouse por cima: o estado "normal" passa a usar o visual de hover.
func _update_focus_look() -> void:
	if has_focus() and not disabled:
		add_theme_stylebox_override(&"normal", get_theme_stylebox(&"hover"))
		add_theme_color_override(&"font_color", get_theme_color(&"font_hover_color"))
	else:
		remove_theme_stylebox_override(&"normal")
		remove_theme_color_override(&"font_color")


func _animate_to(target_lift: float, target_scale: float, instant: bool) -> void:
	_kill_tween()
	if instant or not is_inside_tree():
		_set_lift(target_lift)
		scale = Vector2.ONE * target_scale
		return
	var pressing: bool = target_lift > 0.0
	var time: float = Palette.PRESS_TIME if pressing else Palette.HOVER_TIME
	_tween = UiTween.create(self)  # roda com o jogo pausado (pause) e ignora a câmera lenta
	_tween.set_parallel(true)
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_lift, _lift_applied, target_lift, time)
	_tween.tween_property(self, ^"scale", Vector2.ONE * target_scale, time)


## Move o botão na vertical sem mexer no layout: guarda quanto já foi aplicado.
func _set_lift(value: float) -> void:
	_applying = true
	position.y += value - _lift_applied
	_lift_applied = value
	_last_y = position.y
	_applying = false


## Se um Container reposicionou o botão (reordenou), o deslocamento aplicado deixou de valer.
func _on_item_rect_changed() -> void:
	if _applying:
		return
	if absf(position.y - _last_y) > 0.01:
		_lift_applied = 0.0
		_last_y = position.y


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
