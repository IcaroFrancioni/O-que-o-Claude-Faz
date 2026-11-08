class_name UiTween
extends RefCounted
## Tween de interface: roda com o jogo pausado e, se a versão do Godot permitir, ignora a câmera lenta.

static func create(node: Node) -> Tween:
	var tween: Tween = node.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if tween.has_method(&"set_ignore_time_scale"):
		tween.call(&"set_ignore_time_scale", true)
	return tween


## Tween que PARA com o jogo pausado (animações da HUD de cooldown: o tempo das habilidades congela
## junto com tudo enquanto um menu está aberto). Também ignora a câmera lenta, se a versão permitir.
static func create_pausable(node: Node) -> Tween:
	var tween: Tween = node.create_tween()
	if tween.has_method(&"set_ignore_time_scale"):
		tween.call(&"set_ignore_time_scale", true)
	return tween
