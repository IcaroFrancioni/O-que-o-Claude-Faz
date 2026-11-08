class_name FollowCamera
extends Camera2D
## Câmera que segue o player com zoom (modo celular). Se a fase já tem uma Camera2D no player
## (Fase 1), ela é reaproveitada e só ganha zoom e suavização; nas outras fases uma nova é criada.

## Área de jogo padrão das fases (todas são telas de 1152 x 648).
const DEFAULT_LIMITS: Rect2i = Rect2i(0, 0, 1152, 648)
## Suavização do seguimento (maior = mais colada no player).
const FOLLOW_SPEED: float = 9.0

var _target: Node2D = null


## Liga uma câmera de seguimento ao `player`.
static func attach_to(player: Node2D, zoom_factor: float) -> void:
	var cam: Camera2D = null
	for child: Node in player.get_children():
		if child is Camera2D:
			cam = child as Camera2D
			break
	var limits: Rect2i = DEFAULT_LIMITS
	if cam != null:
		limits = Rect2i(cam.limit_left, cam.limit_top, cam.limit_right - cam.limit_left,
				cam.limit_bottom - cam.limit_top)
		cam.queue_free()  # troca pela FollowCamera, com os mesmos limites da cena
	var follow := FollowCamera.new()
	follow.name = "FollowCamera"
	follow._target = player
	follow.zoom = Vector2.ONE * zoom_factor
	follow.set_limits(limits)
	player.add_child(follow)


func set_limits(rect: Rect2i) -> void:
	limit_left = rect.position.x
	limit_top = rect.position.y
	limit_right = rect.end.x
	limit_bottom = rect.end.y


func _ready() -> void:
	# Fora da hierarquia de transformação do player (que no celular é escalado).
	top_level = true
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	position_smoothing_enabled = true
	position_smoothing_speed = FOLLOW_SPEED
	limit_smoothed = true
	if is_instance_valid(_target):
		global_position = _target.global_position
	make_current()
	reset_smoothing()


func _physics_process(_delta: float) -> void:
	if is_instance_valid(_target):
		global_position = _target.global_position
