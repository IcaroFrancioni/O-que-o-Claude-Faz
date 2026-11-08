class_name UiFx
extends RefCounted
## Efeitos visuais reutilizáveis das HUDs e menus.

const ORNAMENT: Texture2D = preload("res://ui/theme/title_ornament.png")
## Ações do jogo que um clique de interface não pode deixar "vazar" para o Player.
const ATTACK_ACTIONS: Array[StringName] = [&"attack_sword", &"charge_shoot"]
## Quadros de física em que o ataque fica bloqueado depois de um clique de menu (cobre o quadro do clique).
const ATTACK_BLOCK_FRAMES: int = 3
const VIGNETTE_EDGE_ALPHA: float = 0.78
const VIGNETTE_CLEAR_RADIUS: float = 0.45
const VIGNETTE_TEXTURE_SIZE: int = 256

static var _attack_blocked_until: int = 0


## Vinheta: centro transparente escurecendo até as bordas (textura radial; estique na tela toda).
static func vignette() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, VIGNETTE_CLEAR_RADIUS, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.0, 0.0, 0.0, 0.0),
		Color(0.0, 0.0, 0.0, 0.0),
		Color(0.0, 0.0, 0.0, VIGNETTE_EDGE_ALPHA),
	])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = VIGNETTE_TEXTURE_SIZE
	texture.height = VIGNETTE_TEXTURE_SIZE
	return texture


## Ornamento dourado do título (use `flipped = true` no lado esquerdo).
static func make_ornament(flipped: bool) -> TextureRect:
	var ornament: TextureRect = TextureRect.new()
	ornament.texture = ORNAMENT
	ornament.flip_h = flipped
	ornament.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ornament


## Solta as ações de ataque e bloqueia golpes por alguns quadros de física. O Player lê
## `Input.is_action_just_pressed` (polling) e, mesmo depois de `action_release`, o "acabou de apertar"
## do quadro continua verdadeiro: sem o bloqueio, o clique que abre ou fecha um menu viraria um golpe
## assim que o jogo despausa.
static func swallow_attack_input() -> void:
	for action: StringName in ATTACK_ACTIONS:
		if InputMap.has_action(action):
			Input.action_release(action)
	_attack_blocked_until = Engine.get_physics_frames() + ATTACK_BLOCK_FRAMES


## True nos primeiros quadros de física depois de `swallow_attack_input` (o Player não ataca nem atira).
static func is_attack_input_blocked() -> bool:
	return Engine.get_physics_frames() < _attack_blocked_until
