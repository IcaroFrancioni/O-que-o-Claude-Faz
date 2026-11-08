extends Node
## Autoload Platform: decide se o jogo roda em modo celular (Android/iPhone) ou PC e concentra
## todos os ajustes que dependem disso. No PC tudo fica com os valores originais do jogo.
##
## Para testar o modo celular no PC: abra o jogo com o argumento de usuário `--mobile`
## (ex.: godot --path . -- --mobile). O mouse passa a simular o toque.

const SIM_ARG: String = "--mobile"

# --- Ajustes do modo celular (mexa aqui para calibrar) ---

## Tamanho dos sprites no celular: 1.5 = 150% do tamanho original (personagens, inimigos e tiros).
const MOBILE_SPRITE_SCALE: float = 1.5
## Zoom da câmera no celular: 2.0 = enxerga metade da área (câmera mais próxima, seguindo o player).
const MOBILE_CAMERA_ZOOM: float = 2.0
## Carga mínima de um tiro dado só com um toque rápido (0.0 a 1.0).
const MOBILE_MIN_SHOT_CHARGE: float = 0.2

## True no Android, no iPhone (ou navegador com tela de toque) e com `--mobile`.
var is_mobile: bool = false
## True só com `--mobile` no PC: o mouse faz o papel do dedo.
var simulated: bool = false
## True quando o mouse deve funcionar como um dedo nos controles de toque (`--mobile` no PC e navegador).
var mouse_as_finger: bool = false
## Multiplicador de tamanho dos sprites (1.0 no PC).
var sprite_scale: float = 1.0
## Zoom da câmera de seguimento (1.0 no PC).
var camera_zoom: float = 1.0
## Mira assistida (o tiro curva um pouco para o inimigo). Só no celular.
var aim_assist: bool = false
## Carga mínima do tiro (0.0 no PC).
var min_shot_charge: float = 0.0


func _ready() -> void:
	if is_mobile and OS.has_feature("mobile"):
		DisplayServer.screen_set_keep_on(true)  # a tela não apaga no meio da partida


## Navegador de celular/tablet (inclui iPad, que o Safari anuncia como Mac com tela de toque).
func _web_is_touch_device() -> bool:
	if not OS.has_feature("web"):
		return false
	var script: String = "(/Android|iPhone|iPad|iPod/i.test(navigator.userAgent)) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)"
	return JavaScriptBridge.eval(script, true) == true


func _init() -> void:
	simulated = OS.get_cmdline_user_args().has(SIM_ARG)
	is_mobile = OS.has_feature("mobile") or simulated
	if not is_mobile and OS.has_feature("web"):
		is_mobile = DisplayServer.is_touchscreen_available() or _web_is_touch_device()
	mouse_as_finger = simulated or (is_mobile and OS.has_feature("web"))
	if is_mobile:
		sprite_scale = MOBILE_SPRITE_SCALE
		camera_zoom = MOBILE_CAMERA_ZOOM
		aim_assist = true
		min_shot_charge = MOBILE_MIN_SHOT_CHARGE
