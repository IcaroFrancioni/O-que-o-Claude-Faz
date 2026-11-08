class_name ScanlineOverlay
extends ColorRect
## Scanlines sutis (opacidade <= 8%) para o fundo dos menus. Adicione como filho cobrindo a tela
## (anchors em tela cheia) acima do fundo e abaixo do conteúdo. Não recebe mouse.

const SHADER: Shader = preload("res://themes/scanlines.gdshader")

var _material: ShaderMaterial = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter(&"line_color", Palette.TEXT)
	_material.set_shader_parameter(&"line_alpha", Palette.SCANLINE_ALPHA)
	material = _material
	CombatUtils.connect_once(resized, _update_height)
	_update_height()


func _update_height() -> void:
	if _material != null:
		_material.set_shader_parameter(&"rect_height", maxf(size.y, 1.0))
