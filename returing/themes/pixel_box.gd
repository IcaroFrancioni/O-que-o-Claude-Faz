@tool
class_name PixelBox
extends StyleBox
## Caixa pixelada: sombra dura (sem blur) + contorno escuro + borda + preenchimento, com cantos
## "chanfrados" de alguns pixels. Cada camada é um retângulo opaco alinhado ao pixel, então a
## moldura é dupla (contorno escuro por fora, linha de borda mais clara por dentro) e nunca borra.
## Configure as propriedades ANTES de usar; as margens de conteúdo são as do StyleBox (content_margin_*).

## Preenchimento.
@export var fill_color: Color = Palette.PANEL
## Linha de borda (a camada de dentro da moldura).
@export var border_color: Color = Palette.BORDER
## Contorno escuro (a camada de fora da moldura).
@export var outline_color: Color = Palette.BG
## Cor da sombra dura.
@export var shadow_color: Color = Palette.BG
@export_range(0, 8) var border_width: int = Palette.BORDER_THIN
@export_range(0, 8) var outline_width: int = Palette.BORDER_THIN
## Tamanho (px) do canto cortado. 0 = canto reto.
@export_range(0, 8) var corner_cut: int = 2
## Deslocamento da sombra. (0, 0) = sem sombra.
@export var shadow_offset: Vector2i = Vector2i.ZERO
## Encolhe a caixa dentro do retângulo (ex.: preenchimento de slider dentro do trilho).
@export_range(0, 16) var inset: int = 0


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var base: Rect2i = Rect2i(Vector2i(rect.position.round()), Vector2i(rect.size.round())).grow(-inset)
	if base.size.x <= 0 or base.size.y <= 0:
		return
	if shadow_offset != Vector2i.ZERO:
		_draw_layer(to_canvas_item, Rect2i(base.position + shadow_offset, base.size), shadow_color)
	var layer: Rect2i = base
	if outline_width > 0:
		_draw_layer(to_canvas_item, layer, outline_color)
		layer = layer.grow(-outline_width)
	if border_width > 0:
		_draw_layer(to_canvas_item, layer, border_color)
		layer = layer.grow(-border_width)
	_draw_layer(to_canvas_item, layer, fill_color)


## A sombra também é desenhada, então a área de desenho a inclui.
func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect.merge(Rect2(rect.position + Vector2(shadow_offset), rect.size))


## Um retângulo com os 4 cantos cortados (dois retângulos que se cruzam).
func _draw_layer(canvas_item: RID, area: Rect2i, color: Color) -> void:
	if area.size.x <= 0 or area.size.y <= 0:
		return
	var cut: int = mini(corner_cut, mini(area.size.x, area.size.y) >> 1)
	if cut <= 0:
		RenderingServer.canvas_item_add_rect(canvas_item, Rect2(area), color)
		return
	var x: float = area.position.x
	var y: float = area.position.y
	var w: float = area.size.x
	var h: float = area.size.y
	RenderingServer.canvas_item_add_rect(canvas_item, Rect2(x + cut, y, w - 2.0 * cut, h), color)
	RenderingServer.canvas_item_add_rect(canvas_item, Rect2(x, y + cut, w, h - 2.0 * cut), color)
