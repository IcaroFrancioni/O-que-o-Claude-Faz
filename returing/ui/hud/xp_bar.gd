class_name XpBar
extends Control
## Barra de nível e XP no estilo da barra de vida (moldura dourada, preenchimento azul-ciano, emblema
## hexagonal com o nível). Na HUD ela é VERTICAL: fica à direita do bloco das barras de vida e de carga,
## com o topo na altura da primeira e a base na base da última (o comprimento acompanha o bloco).
## A versão HORIZONTAL (`orientation`) serve para cabeçalhos, como o do menu de build.
##
## Uso: `set_xp(atual, maximo, nivel, nivel_maximo)`; `atual` e `maximo` são o XP DENTRO do nível
## (ex.: 40 de 150). Com `auto_bind` ligado ela se conecta ao `ExperienceComponent` do Player.

enum BarLayout { VERTICAL, HORIZONTAL }

const FRAME_V: Texture2D = preload("res://ui/hud/xp_frame_v.png")
const FILL_V: Texture2D = preload("res://ui/hud/xp_fill_v.png")
const SHINE_V: Texture2D = preload("res://ui/hud/xp_shine_v.png")
const FRAME_H: Texture2D = preload("res://ui/hud/xp_frame.png")
const FILL_H: Texture2D = preload("res://ui/hud/xp_fill.png")
const SHINE_H: Texture2D = preload("res://ui/hud/xp_shine.png")

const COLOR_TEXT: Color = UiPalette.TEXT
const COLOR_TEXT_OUTLINE: Color = UiPalette.OUTLINE
const OUTLINE_SIZE: int = 4
const FONT_VALUE_HORIZONTAL: int = 14
const FONT_VALUE_VERTICAL: int = 12
const FONT_LEVEL: int = 30
const SHINE_ALPHA: float = 0.9
const GLOW_MAX_ALPHA: float = 0.95
const GLOW_MIN_ALPHA: float = 0.45
const EMBLEM_POP_SCALE: float = 1.18

## Medidas em pixels de tela (a escala de pixel da HUD é 4x, a mesma da barra de vida).
const THICKNESS: float = 64.0
const EMBLEM_SIZE: float = 80.0
const GLOW_SIZE: float = 112.0
const FRAME_MARGIN: int = 32
const FILL_STRETCH_MARGIN: int = 16
## Vertical: o emblema fica centrado na borda de cima, sobreposto à moldura.
const V_EMBLEM_POS: Vector2 = Vector2(-8.0, -40.0)
const V_FILL_INSET_X: float = 16.0
const V_FILL_TOP: float = 44.0
const V_FILL_BOTTOM_INSET: float = 20.0
## Horizontal: o emblema fica à esquerda e a moldura começa debaixo dele.
const H_EMBLEM_POS: Vector2 = Vector2(0.0, -8.0)
const H_BODY_X: float = 56.0
const H_FILL_X: float = 76.0
const H_FILL_RIGHT_INSET: float = 24.0
const H_FILL_Y: float = 16.0
const FILL_THICKNESS: float = 32.0
## Espaço (px) entre o bloco de barras de vida e a barra de XP.
const GAP: float = 16.0

@export var orientation: BarLayout = BarLayout.VERTICAL

@export_group("Animação")
## Tempo (s) do preenchimento suave.
@export_range(0.05, 1.5, 0.05) var fill_time: float = 0.35
## Tempo (s) do brilho que percorre a barra ao subir de nível.
@export_range(0.1, 2.0, 0.05) var shine_time: float = 0.7
## Tempo (s) do pulso do emblema.
@export_range(0.1, 1.0, 0.05) var pulse_time: float = 0.4

@export_group("Ligação")
## Liga sozinha ao `ExperienceComponent` do Player (desligue na galeria de testes).
@export var auto_bind: bool = true
## Na versão vertical da HUD: acompanha o bloco de barras de vida (posição e comprimento).
@export var follow_health_block: bool = true

@onready var _glow: TextureRect = $Glow
@onready var _body: NinePatchRect = $Body
@onready var _fill_clip: Control = $FillClip
@onready var _fill: TextureProgressBar = $FillClip/Fill
@onready var _shine: TextureRect = $FillClip/Shine
@onready var _value_label: Label = $ValueLabel
@onready var _emblem: TextureRect = $Emblem
@onready var _emblem_max: TextureRect = $EmblemMax
@onready var _level_label: Label = $LevelLabel

var _experience: ExperienceComponent = null
var _level: int = -1
var _is_max: bool = false
var _shown_ratio: float = 0.0
var _fill_tween: Tween = null
var _shine_tween: Tween = null
var _pulse_tween: Tween = null
var _glow_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for label: Label in [_value_label, _level_label]:
		label.add_theme_color_override(&"font_color", COLOR_TEXT)
		label.add_theme_color_override(&"font_outline_color", COLOR_TEXT_OUTLINE)
		label.add_theme_constant_override(&"outline_size", OUTLINE_SIZE)
	_level_label.add_theme_font_size_override(&"font_size", FONT_LEVEL)
	_value_label.add_theme_font_size_override(&"font_size",
			FONT_VALUE_VERTICAL if orientation == BarLayout.VERTICAL else FONT_VALUE_HORIZONTAL)
	_fill.max_value = 1.0
	_fill.step = 0.0
	_fill.nine_patch_stretch = true
	_shine.modulate.a = 0.0
	resized.connect(_apply_layout)
	_apply_layout()
	set_xp(0, 1, 0, false)
	if orientation == BarLayout.VERTICAL and follow_health_block:
		_align_to_health_block.call_deferred()
	if auto_bind:
		_bind.call_deferred()


func _exit_tree() -> void:
	_unbind()
	for tween: Tween in [_fill_tween, _shine_tween, _pulse_tween, _glow_tween]:
		if tween != null and tween.is_valid():
			tween.kill()


## Posiciona cada parte conforme a orientação e o tamanho atual.
func _apply_layout() -> void:
	var vertical: bool = orientation == BarLayout.VERTICAL
	var emblem_pos: Vector2 = V_EMBLEM_POS if vertical else H_EMBLEM_POS
	for emblem: TextureRect in [_emblem, _emblem_max]:
		emblem.position = emblem_pos
		emblem.size = Vector2.ONE * EMBLEM_SIZE
	_level_label.position = emblem_pos
	_level_label.size = Vector2.ONE * EMBLEM_SIZE
	_glow.position = emblem_pos + Vector2.ONE * (EMBLEM_SIZE - GLOW_SIZE) * 0.5
	_glow.size = Vector2.ONE * GLOW_SIZE
	for pivoted: Control in [_emblem, _emblem_max, _level_label]:
		pivoted.pivot_offset = pivoted.size * 0.5
	var margin: int = FRAME_MARGIN
	if vertical:
		_body.texture = FRAME_V
		_body.position = Vector2.ZERO
		_body.size = Vector2(THICKNESS, maxf(size.y, 96.0))
		_fill_clip.position = Vector2(V_FILL_INSET_X, V_FILL_TOP)
		_fill_clip.size = Vector2(FILL_THICKNESS, maxf(_body.size.y - V_FILL_TOP - V_FILL_BOTTOM_INSET, 8.0))
		_fill.texture_progress = FILL_V
		_fill.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
		_fill.set_stretch_margin(SIDE_TOP, FILL_STRETCH_MARGIN)
		_fill.set_stretch_margin(SIDE_BOTTOM, FILL_STRETCH_MARGIN)
		_fill.set_stretch_margin(SIDE_LEFT, 0)
		_fill.set_stretch_margin(SIDE_RIGHT, 0)
		_shine.texture = SHINE_V
		_value_label.position = Vector2(0.0, _fill_clip.position.y)
		_value_label.size = Vector2(THICKNESS, _fill_clip.size.y)
	else:
		_body.texture = FRAME_H
		_body.position = Vector2(H_BODY_X, 0.0)
		_body.size = Vector2(maxf(size.x - H_BODY_X, 128.0), THICKNESS)
		_fill_clip.position = Vector2(H_FILL_X, H_FILL_Y)
		_fill_clip.size = Vector2(maxf(size.x - H_FILL_X - H_FILL_RIGHT_INSET, 8.0), FILL_THICKNESS)
		_fill.texture_progress = FILL_H
		_fill.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
		_fill.set_stretch_margin(SIDE_LEFT, FILL_STRETCH_MARGIN)
		_fill.set_stretch_margin(SIDE_RIGHT, FILL_STRETCH_MARGIN)
		_fill.set_stretch_margin(SIDE_TOP, 0)
		_fill.set_stretch_margin(SIDE_BOTTOM, 0)
		_shine.texture = SHINE_H
		_value_label.position = _fill_clip.position
		_value_label.size = _fill_clip.size
	_body.patch_margin_left = margin
	_body.patch_margin_right = margin
	_body.patch_margin_top = margin
	_body.patch_margin_bottom = margin
	_fill.position = Vector2.ZERO
	_fill.size = _fill_clip.size
	_shine.size = _shine.texture.get_size()
	_shine.position = Vector2(-_shine.size.x, 0.0) if not vertical else Vector2(0.0, _fill_clip.size.y)


## Atualiza a barra. `atual`/`maximo`: XP dentro do nível; `nivel_maximo`: mostra "MÁX" e barra cheia.
func set_xp(atual: int, maximo: int, nivel: int, nivel_maximo: bool) -> void:
	var first: bool = _level < 0
	var leveled_up: bool = not first and nivel > _level
	var target: float = 1.0 if nivel_maximo else clampf(float(atual) / float(maxi(maximo, 1)), 0.0, 1.0)
	_level = nivel
	_is_max = nivel_maximo
	_level_label.text = str(nivel)
	_value_label.text = "MÁX" if nivel_maximo else "%d/%d" % [atual, maximo]
	_emblem.visible = not nivel_maximo
	_emblem_max.visible = nivel_maximo
	_update_glow()
	if first:
		_set_ratio(target)
		return
	_kill(_fill_tween)
	if leveled_up:
		# enche até o fim, zera e recomeça do que sobrou: a barra "estoura" ao subir de nível
		_fill_tween = UiTween.create(self)
		_fill_tween.tween_method(_set_ratio, _shown_ratio, 1.0, fill_time * 0.6)
		_fill_tween.tween_callback(_set_ratio.bind(0.0))
		_fill_tween.tween_method(_set_ratio, 0.0, target, fill_time)
		_play_level_up()
	else:
		_fill_tween = UiTween.create(self)
		_fill_tween.tween_method(_set_ratio, _shown_ratio, target, fill_time)


## Como `set_xp`, mas sem animar (para telas que abrem já no valor certo).
func set_xp_instant(atual: int, maximo: int, nivel: int, nivel_maximo: bool) -> void:
	_kill(_fill_tween)
	_level = -1
	set_xp(atual, maximo, nivel, nivel_maximo)


func _set_ratio(value: float) -> void:
	_shown_ratio = value
	_fill.value = value


## Brilho que percorre a barra (de baixo para cima na vertical) e pulso do emblema.
func _play_level_up() -> void:
	_kill(_shine_tween)
	var vertical: bool = orientation == BarLayout.VERTICAL
	var travel_from: float = _fill_clip.size.y if vertical else -_shine.size.x
	var travel_to: float = -_shine.size.y if vertical else _fill_clip.size.x
	var axis: NodePath = ^"position:y" if vertical else ^"position:x"
	_shine.position = Vector2(0.0, travel_from) if vertical else Vector2(travel_from, 0.0)
	_shine.modulate.a = SHINE_ALPHA
	_shine_tween = UiTween.create(self)
	_shine_tween.tween_property(_shine, axis, travel_to, shine_time)
	_shine_tween.tween_property(_shine, ^"modulate:a", 0.0, 0.05)
	_kill(_pulse_tween)
	var target: Control = _emblem_max if _is_max else _emblem
	target.scale = Vector2.ONE
	_level_label.scale = Vector2.ONE
	_pulse_tween = UiTween.create(self)
	_pulse_tween.set_parallel(true)
	_pulse_tween.tween_property(target, ^"scale", Vector2.ONE * EMBLEM_POP_SCALE, pulse_time * 0.5)
	_pulse_tween.tween_property(_level_label, ^"scale", Vector2.ONE * EMBLEM_POP_SCALE, pulse_time * 0.5)
	_pulse_tween.chain().set_parallel(true)
	_pulse_tween.tween_property(target, ^"scale", Vector2.ONE, pulse_time * 0.5)
	_pulse_tween.tween_property(_level_label, ^"scale", Vector2.ONE, pulse_time * 0.5)


## No nível máximo o brilho dourado fica ligado e pulsando devagar; fora dele, apagado.
func _update_glow() -> void:
	_kill(_glow_tween)
	if not _is_max:
		_glow.modulate.a = 0.0
		return
	_glow.modulate.a = GLOW_MAX_ALPHA
	_glow_tween = UiTween.create(self)
	_glow_tween.set_loops()
	_glow_tween.tween_property(_glow, ^"modulate:a", GLOW_MIN_ALPHA, 0.9)
	_glow_tween.tween_property(_glow, ^"modulate:a", GLOW_MAX_ALPHA, 0.9)


func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


## Fica logo à direita do bloco das barras de vida e de carga, com o topo na primeira e a base na
## última (o comprimento é o do bloco, espaço entre elas incluído), onde quer que elas estejam.
func _align_to_health_block() -> void:
	await get_tree().process_frame  # deixa o SpriteBar e o MobileControls acertarem as barras antes
	await get_tree().process_frame
	var parent: Node = get_parent()
	if parent == null:
		return
	var health: Control = parent.get_node_or_null(^"PlayerHealthBar") as Control
	if health == null:
		return
	var last_bar: Control = parent.get_node_or_null(^"ChargeBar") as Control
	if last_bar == null:
		last_bar = health  # HUD de uma barra só: iguala a altura dela
	anchor_left = health.anchor_left
	anchor_right = health.anchor_right
	anchor_top = minf(health.anchor_top, last_bar.anchor_top)
	anchor_bottom = maxf(health.anchor_bottom, last_bar.anchor_bottom)
	grow_vertical = health.grow_vertical
	offset_left = maxf(health.offset_right, last_bar.offset_right) + GAP
	offset_right = offset_left + THICKNESS
	offset_top = minf(health.offset_top, last_bar.offset_top)
	offset_bottom = maxf(health.offset_bottom, last_bar.offset_bottom)


# --- Ligação ao sistema de XP ---

func _bind() -> void:
	CombatUtils.connect_once(EventBus.player_registered, _on_player_registered)
	var player: Node2D = get_tree().get_first_node_in_group(CombatUtils.GROUP_PLAYER) as Node2D
	if player != null:
		_on_player_registered(player)


func _on_player_registered(player: Node2D) -> void:
	var component: ExperienceComponent = player.get_node_or_null(^"ExperienceComponent") as ExperienceComponent
	if component == null or component == _experience:
		return
	_unbind()
	_experience = component
	CombatUtils.connect_once(_experience.xp_changed, _on_xp_changed)
	_experience.refresh.call_deferred()


func _unbind() -> void:
	CombatUtils.disconnect_if_connected(EventBus.player_registered, _on_player_registered)
	if is_instance_valid(_experience):
		CombatUtils.disconnect_if_connected(_experience.xp_changed, _on_xp_changed)
	_experience = null


func _on_xp_changed(xp: int, _xp_next: int, level: int) -> void:
	var floor_xp: int = _experience.get_level_floor()
	var next_xp: int = _experience.get_next_threshold()
	set_xp(xp - floor_xp, next_xp - floor_xp, level, _experience.is_max_level())
