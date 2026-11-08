extends CanvasLayer
## Autoload MobileControls: controles de toque (Android/iPhone). Só ficam ativos no celular, ou no PC
## com o argumento de usuário `--mobile` (o mouse simula o toque).
##
## Layout (igual ao do APK anterior):
##   esquerda  -> analógico de movimento (flutuante: nasce onde o dedo toca)
##   direita   -> analógico de mira/ataque (fixo)
##   botões    -> trocar arma, dash, interagir (E) e pausa
##
## Ataque (igual para tiro e espada): segure o analógico da direita para mirar (aparece a mira no
## chão) e solte para atacar na direção apontada. Com o tiro, segurar também carrega.
## Um toque rápido mira sozinho no inimigo mais próximo.

const SIM_ARG: String = "--mobile"
const TUTORIAL_SCENE: String = "res://Scenes/Tutorial/tutorial.tscn"

const ACT_LEFT: StringName = &"move_left"
const ACT_RIGHT: StringName = &"move_right"
const ACT_UP: StringName = &"move_up"
const ACT_DOWN: StringName = &"move_down"
const ACT_DASH: StringName = &"dash"
const ACT_MELEE: StringName = &"attack_sword"
const ACT_SHOOT: StringName = &"charge_shoot"
const ACT_INTERACT: StringName = &"interagir"
const ACT_PAUSE: StringName = &"Pause"

const ROLE_WEAPON: StringName = &"weapon"
const ROLE_DASH: StringName = &"dash"
const ROLE_PAUSE: StringName = &"pause"
const ROLE_INTERACT: StringName = &"interact"
const ROLE_MOVE: StringName = &"move"
const ROLE_AIM: StringName = &"aim"

const FILL: Color = Color(0.62, 0.62, 0.62, 0.5)
const FILL_PRESSED: Color = Color(0.62, 0.62, 0.62, 0.72)
const RING: Color = Color(0.85, 0.85, 0.85, 0.5)
const ICON: Color = Color(1.0, 1.0, 1.0, 0.85)

const STICK_RADIUS: float = 80.0
const THUMB_RADIUS: float = 34.0
const BUTTON_RADIUS: float = 46.0
const SMALL_BUTTON_RADIUS: float = 28.0
const MARGIN: float = 20.0
## Faixa no topo da tela que não inicia analógicos (barras de vida e botão de pausa).
const TOP_DEAD_ZONE: float = 84.0
## O analógico de mira só aceita o toque até este múltiplo do raio, a partir do centro dele.
const AIM_ZONE: float = 1.9
## Folga na área de toque dos botões.
const HIT_SLACK: float = 1.25
const MOVE_DEADZONE: float = 0.12
const AIM_DEADZONE: float = 0.22
const DASH_HOLD_FRAMES: int = 3
## Alcance (px) da mira automática do toque rápido.
const AUTO_AIM_RANGE: float = 420.0
## Quadros (física) que um toque rápido espera o player poder atacar antes de desistir (~0.33 s).
const TAP_TIMEOUT_FRAMES: int = 20
## Quadros seguidos com o player já atacando para considerar o toque entregue.
const TAP_DELIVERED_FRAMES: int = 2
## Quadros sem o player reagir ao botão pressionado até soltar e apertar de novo.
const REPRESS_FRAMES: int = 2
## Dedo "virtual" do mouse (simulação no PC).
const SIM_FINGER: int = 99
## Espada: true = mira enquanto segura e golpeia ao soltar (como o tiro); false = golpeia sem parar
## enquanto o dedo estiver no analógico.
const MELEE_ON_RELEASE: bool = true

## True quando os controles de toque estão valendo (celular ou `--mobile`).
var ativo: bool = false
## True = o botão de arma está no tiro carregado; false = espada.
var weapon_ranged: bool = false

var _shown: bool = false
var _blocked: bool = false
var _player: Player = null
var _canvas: Control = null
var _terminals: Array[Node] = []

var _fingers: Dictionary[int, StringName] = { }
var _move_finger: int = -1
var _aim_finger: int = -1
var _move_center: Vector2 = Vector2.ZERO
var _move_vec: Vector2 = Vector2.ZERO
var _aim_center: Vector2 = Vector2.ZERO
var _aim_vec: Vector2 = Vector2.ZERO
## Última direção de mira. Persiste depois de soltar o dedo: é ela que o tiro usa ao sair.
var _aim_dir: Vector2 = Vector2.ZERO
var _aim_down: bool = false
## Toque rápido que ainda não virou ataque (o player estava ocupado: dash, golpe...).
var _tap_pending: bool = false
var _tap_frames_left: int = 0
var _tap_delivered_frames: int = 0
var _repress_counter: int = 0
var _dash_frames: int = 0
var _pressed_roles: Dictionary[StringName, bool] = { }
var _act_state: Dictionary[StringName, bool] = { }
var _view: Vector2 = Vector2(1152.0, 648.0)
var _margins: Vector4 = Vector4.ZERO


func _ready() -> void:
	ativo = Platform.is_mobile
	if not ativo:
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		visible = false
		return
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -100  # antes do player: o toque vira ação no mesmo quadro
	get_tree().set_quit_on_go_back(false)
	# O toque vira clique de mouse (necessário para os menus): sem isso o clique também atacaria.
	InputMap.action_erase_events(ACT_MELEE)
	InputMap.action_erase_events(ACT_SHOOT)
	_canvas = Control.new()
	_canvas.name = "TouchCanvas"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_controls)
	_canvas.visible = false
	add_child(_canvas)
	EventBus.player_registered.connect(_on_player_registered)
	EventBus.player_died.connect(_on_blocked)
	EventBus.game_over.connect(_on_blocked)
	EventBus.level_completed.connect(_on_level_completed)
	EventBus.level_started.connect(_on_unblocked)
	get_tree().node_added.connect(_on_node_added)
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()
	_scan_existing_nodes.call_deferred()


func _notification(what: int) -> void:
	if not ativo:
		return
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			_release_all()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_back_pressed()


# --- API usada pelo Player ---

## Direção de mira do analógico. Fica valendo depois de soltar o dedo (o tiro sai nela).
func direcao_mira(_desde: Vector2, fallback: Vector2) -> Vector2:
	return _aim_dir if _aim_dir != Vector2.ZERO else fallback


## True enquanto o dedo está no analógico de mira.
func is_aiming() -> bool:
	return _aim_down


func _on_player_registered(player: Node2D) -> void:
	_player = player as Player
	_blocked = false
	_aim_dir = Vector2.ZERO
	_tap_pending = false
	_release_all()


func _on_blocked(_arg: Variant = null) -> void:
	_blocked = true


func _on_unblocked() -> void:
	_blocked = false


func _on_level_completed(_next_scene: String) -> void:
	_blocked = true


func _scan_existing_nodes() -> void:
	for node: Node in get_tree().root.find_children("*", "", true, false):
		_on_node_added(node)


func _on_node_added(node: Node) -> void:
	if node is QuizTerminal:
		_terminals.append(node)
	elif node is GameHUD:
		_adapt_hud.call_deferred(node)
	elif node is Control and node.scene_file_path == TUTORIAL_SCENE:
		_build_mobile_tutorial.call_deferred(node)


func _wants_to_show() -> bool:
	if _blocked or get_tree().paused:
		return false
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		return false
	if _player.esta_morto():
		return false
	return true


func _set_shown(value: bool) -> void:
	if value == _shown:
		return
	_shown = value
	if not value:
		_release_all()
	_canvas.visible = value
	_canvas.queue_redraw()


# --- Layout ---

func _update_layout() -> void:
	_view = get_viewport().get_visible_rect().size
	_margins = _safe_margins()
	if _move_finger == -1:
		_move_center = _rest_move()
	if _aim_finger == -1:
		_aim_center = _rest_aim()
	if _canvas != null:
		_canvas.queue_redraw()


## Margens (px de tela lógica) das áreas que o celular reserva: notch do iPhone, cantos
## arredondados, barra de gestos.
func _safe_margins() -> Vector4:
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var window: Vector2 = Vector2(DisplayServer.window_get_size())
	var screen: Vector2 = Vector2(DisplayServer.screen_get_size())
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if window.x <= 0.0 or screen.x <= 0.0 or safe.size.x <= 0:
		return Vector4.ZERO
	var k: float = _view.x / window.x
	return Vector4(
		float(safe.position.x) * k,
		float(safe.position.y) * k,
		maxf(screen.x - float(safe.end.x), 0.0) * k,
		maxf(screen.y - float(safe.end.y), 0.0) * k)


func _rest_move() -> Vector2:
	return Vector2(_margins.x + MARGIN + STICK_RADIUS + 36.0, _view.y - _margins.w - MARGIN - STICK_RADIUS - 24.0)


func _rest_aim() -> Vector2:
	return Vector2(_view.x - _margins.z - MARGIN - STICK_RADIUS - 36.0, _view.y - _margins.w - MARGIN - STICK_RADIUS - 24.0)


func _button_center(role: StringName) -> Vector2:
	var aim: Vector2 = _rest_aim()
	match role:
		ROLE_WEAPON:
			return aim + Vector2(-152.0, -92.0)
		ROLE_DASH:
			return aim + Vector2(-196.0, 30.0)
		ROLE_INTERACT:
			return aim + Vector2(0.0, -188.0)
		ROLE_PAUSE:
			return Vector2(_view.x - _margins.z - 44.0, _margins.y + 44.0)
	return Vector2.ZERO


func _button_radius(role: StringName) -> float:
	return SMALL_BUTTON_RADIUS if role == ROLE_PAUSE else BUTTON_RADIUS


func _button_enabled(role: StringName) -> bool:
	return role != ROLE_INTERACT or _interact_available()


func _interact_available() -> bool:
	for terminal: Node in _terminals:
		if not is_instance_valid(terminal) or not terminal.is_inside_tree():
			continue
		var prompt: Variant = terminal.get("prompt")
		if prompt is Control and (prompt as Control).is_visible_in_tree():
			return true
	return false


## As barras de vida/carga saem do canto inferior (onde fica o analógico) para o topo esquerdo.
func _adapt_hud(hud: GameHUD) -> void:
	if not is_instance_valid(hud):
		return
	var y: float = _margins.y + 10.0
	for bar: Control in [hud.player_health_bar, hud.charge_bar]:
		if bar == null:
			continue
		var width: float = bar.offset_right - bar.offset_left
		var height: float = bar.offset_bottom - bar.offset_top
		var left: float = _margins.x + 16.0
		bar.set_anchor_and_offset(SIDE_LEFT, 0.0, left)
		bar.set_anchor_and_offset(SIDE_RIGHT, 0.0, left + width)
		bar.set_anchor_and_offset(SIDE_TOP, 0.0, y)
		bar.set_anchor_and_offset(SIDE_BOTTOM, 0.0, y + height)
		bar.grow_vertical = Control.GROW_DIRECTION_END
		y += height + 4.0


# --- Entrada ---

func _input(event: InputEvent) -> void:
	if not _shown:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var used: bool = _press(touch.index, touch.position) if touch.pressed else _release(touch.index)
		if used:
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _drag(drag.index, drag.position):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		# O toque também gera um clique de mouse "emulado". Durante o jogo ele não pode vazar para o
		# mundo (ex.: tocar num botão por cima do terminal abriria o quiz sem querer).
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			get_viewport().set_input_as_handled()
		elif Platform.mouse_as_finger:
			_simulate_with_mouse(event)
			get_viewport().set_input_as_handled()


## No PC (com `--mobile`) o botão esquerdo do mouse faz o papel de um dedo.
func _simulate_with_mouse(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var click := event as InputEventMouseButton
		if click.pressed:
			_press(SIM_FINGER, click.position)
		else:
			_release(SIM_FINGER)
	elif event is InputEventMouseMotion and _fingers.has(SIM_FINGER):
		_drag(SIM_FINGER, (event as InputEventMouseMotion).position)


func _press(index: int, pos: Vector2) -> bool:
	if _fingers.has(index):
		return false
	for role: StringName in [ROLE_PAUSE, ROLE_INTERACT, ROLE_WEAPON, ROLE_DASH]:
		if not _button_enabled(role):
			continue
		if pos.distance_to(_button_center(role)) <= _button_radius(role) * HIT_SLACK:
			_fingers[index] = role
			_pressed_roles[role] = true
			_button_down(role)
			_canvas.queue_redraw()
			return true
	if pos.y < TOP_DEAD_ZONE:
		return false
	if pos.x < _view.x * 0.5:
		if _move_finger != -1:
			return false
		_move_finger = index
		_fingers[index] = ROLE_MOVE
		_move_center = _clamp_stick_center(pos)
		_move_vec = Vector2.ZERO
		_drag(index, pos)
	else:
		if _aim_finger != -1 or pos.distance_to(_rest_aim()) > STICK_RADIUS * AIM_ZONE:
			return false
		_start_aim(index, pos)
	_canvas.queue_redraw()
	return true


func _start_aim(index: int, pos: Vector2) -> void:
	_aim_finger = index
	_fingers[index] = ROLE_AIM
	_aim_center = _rest_aim()
	_aim_vec = Vector2.ZERO
	_aim_down = true
	_tap_pending = false
	_tap_delivered_frames = 0
	_repress_counter = 0
	# Sem arrastar, o toque mira no inimigo mais próximo (ou segue na última direção).
	var auto: Vector2 = _nearest_enemy_direction(_player_position())
	if auto != Vector2.ZERO:
		_aim_dir = auto
	elif _aim_dir == Vector2.ZERO and is_instance_valid(_player):
		_aim_dir = _player.facing_direction
	_drag(index, pos)


func _drag(index: int, pos: Vector2) -> bool:
	var role: StringName = _fingers.get(index, &"")
	if role == ROLE_MOVE:
		var delta: Vector2 = pos - _move_center
		if delta.length() > STICK_RADIUS:
			_move_center += delta.normalized() * (delta.length() - STICK_RADIUS)
			delta = pos - _move_center
		_move_vec = delta / STICK_RADIUS
	elif role == ROLE_AIM:
		var delta: Vector2 = (pos - _aim_center).limit_length(STICK_RADIUS)
		_aim_vec = delta / STICK_RADIUS
		if _aim_vec.length() >= AIM_DEADZONE:
			_aim_dir = _aim_vec.normalized()
	else:
		return false
	_canvas.queue_redraw()
	return true


func _release(index: int) -> bool:
	if not _fingers.has(index):
		return false
	var role: StringName = _fingers[index]
	_fingers.erase(index)
	match role:
		ROLE_MOVE:
			_move_finger = -1
			_move_vec = Vector2.ZERO
			_move_center = _rest_move()
		ROLE_AIM:
			_aim_finger = -1
			_aim_down = false
			_aim_vec = Vector2.ZERO
			_aim_center = _rest_aim()
			# Toque rápido: se o ataque ainda não saiu, garante um (a direção em `_aim_dir` fica).
			if _tap_delivered_frames < TAP_DELIVERED_FRAMES:
				_tap_pending = true
				_tap_frames_left = TAP_TIMEOUT_FRAMES
		_:
			_pressed_roles[role] = false
	_canvas.queue_redraw()
	return true


func _button_down(role: StringName) -> void:
	match role:
		ROLE_WEAPON:
			weapon_ranged = not weapon_ranged
		ROLE_DASH:
			_set_action(ACT_DASH, true)
			_dash_frames = DASH_HOLD_FRAMES
		ROLE_PAUSE:
			_tap_action(ACT_PAUSE)
		ROLE_INTERACT:
			_tap_action(ACT_INTERACT)


func _clamp_stick_center(pos: Vector2) -> Vector2:
	var min_x: float = _margins.x + STICK_RADIUS + 8.0
	var max_x: float = _view.x - _margins.z - STICK_RADIUS - 8.0
	var min_y: float = TOP_DEAD_ZONE + STICK_RADIUS * 0.5
	var max_y: float = _view.y - _margins.w - STICK_RADIUS - 8.0
	return Vector2(clampf(pos.x, min_x, max_x), clampf(pos.y, min_y, max_y))


# --- Ações ---

func _physics_process(_delta: float) -> void:
	var want: bool = _wants_to_show()
	_set_shown(want)
	if not _shown:
		return
	_apply_move()
	_apply_dash()
	_apply_attack()


func _process(_delta: float) -> void:
	if _shown:
		_canvas.queue_redraw()


func _apply_move() -> void:
	var length: float = _move_vec.length()
	var out: Vector2 = Vector2.ZERO
	if length > MOVE_DEADZONE:
		out = _move_vec.normalized() * clampf((length - MOVE_DEADZONE) / (1.0 - MOVE_DEADZONE), 0.0, 1.0)
	_set_action(ACT_LEFT, out.x < 0.0, -out.x)
	_set_action(ACT_RIGHT, out.x > 0.0, out.x)
	_set_action(ACT_UP, out.y < 0.0, -out.y)
	_set_action(ACT_DOWN, out.y > 0.0, out.y)


func _apply_dash() -> void:
	if _dash_frames > 0:
		_dash_frames -= 1
		if _dash_frames == 0:
			_set_action(ACT_DASH, false)


## Converte o dedo no analógico de mira em ataque.
## - Tiro: mantém `charge_shoot` apertado enquanto o dedo está lá (carrega) e solta ao levantar (atira).
## - Espada: mira enquanto o dedo está lá e golpeia ao soltar (MELEE_ON_RELEASE).
## - Toque rápido: se o player estava ocupado, o ataque fica pendente até ele conseguir começar.
func _apply_attack() -> void:
	var attacking: bool = _player_is_attacking()
	if _tap_pending:
		_tap_frames_left -= 1
		if attacking:
			_tap_delivered_frames += 1
			if _tap_delivered_frames >= TAP_DELIVERED_FRAMES:
				_tap_pending = false
		elif _tap_frames_left <= 0:
			_tap_pending = false
	elif _aim_down and attacking:
		_tap_delivered_frames += 1
	var holding: bool = _aim_down or _tap_pending
	if weapon_ranged:
		_set_action(ACT_MELEE, false)
		if not holding:
			_set_action(ACT_SHOOT, false)
			_repress_counter = 0
		elif attacking:
			_set_action(ACT_SHOOT, true)
			_repress_counter = 0
		elif _act_state.get(ACT_SHOOT, false):
			# O player não reagiu (estava no dash/golpe): solta um quadro para gerar novo "apertou".
			_repress_counter += 1
			if _repress_counter >= REPRESS_FRAMES:
				_set_action(ACT_SHOOT, false)
				_repress_counter = 0
		else:
			_set_action(ACT_SHOOT, true)
	else:
		_set_action(ACT_SHOOT, false)
		# Alterna apertar/soltar: cada "apertou" é um golpe (a espada só bate quando está livre).
		var swing: bool = _tap_pending if MELEE_ON_RELEASE else holding
		_set_action(ACT_MELEE, swing and not _act_state.get(ACT_MELEE, false))


## O player já está carregando o tiro (modo tiro) ou golpeando (modo espada).
func _player_is_attacking() -> bool:
	if not is_instance_valid(_player):
		return false
	if weapon_ranged:
		return _player.state == Player.State.ATTACK_RANGED
	return _player.state == Player.State.ATTACK_MELEE


func _set_action(action: StringName, pressed: bool, strength: float = 1.0) -> void:
	if pressed:
		if not _act_state.get(action, false) or absf(Input.get_action_strength(action) - strength) > 0.01:
			Input.action_press(action, clampf(strength, 0.0, 1.0))
		_act_state[action] = true
	elif _act_state.get(action, false):
		Input.action_release(action)
		_act_state[action] = false


## Aperta e solta uma ação (pausa, interagir) como um toque.
func _tap_action(action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event.call_deferred(release)


func _release_all() -> void:
	for action: StringName in [ACT_LEFT, ACT_RIGHT, ACT_UP, ACT_DOWN, ACT_DASH, ACT_MELEE, ACT_SHOOT]:
		if _act_state.get(action, false) or Input.is_action_pressed(action):
			Input.action_release(action)
		_act_state[action] = false
	_fingers.clear()
	_pressed_roles.clear()
	_move_finger = -1
	_aim_finger = -1
	_move_vec = Vector2.ZERO
	_aim_vec = Vector2.ZERO
	_aim_down = false
	_tap_pending = false
	_dash_frames = 0
	_move_center = _rest_move()
	_aim_center = _rest_aim()


func _player_position() -> Vector2:
	return _player.global_position if is_instance_valid(_player) else Vector2.ZERO


## Direção até o inimigo vivo mais próximo (dentro de AUTO_AIM_RANGE), ou ZERO.
func _nearest_enemy_direction(from: Vector2) -> Vector2:
	var best: float = AUTO_AIM_RANGE
	var direction: Vector2 = Vector2.ZERO
	for node: Node in get_tree().get_nodes_in_group(CombatUtils.GROUP_ENEMY):
		var enemy := node as Node2D
		if enemy == null or not CombatUtils.is_targetable(enemy):
			continue
		var to_enemy: Vector2 = enemy.global_position - from
		var distance: float = to_enemy.length()
		if distance < best and distance > 1.0:
			best = distance
			direction = to_enemy / distance
	return direction


func _on_back_pressed() -> void:
	if _shown:
		_tap_action(ACT_PAUSE)
		return
	if get_tree().paused:
		_tap_action(ACT_PAUSE)
		return
	var current: Node = get_tree().current_scene
	if current != null and current.scene_file_path == Global.MENU_SCENE:
		EventBus.quit_requested.emit()
	else:
		EventBus.main_menu_requested.emit()


# --- Desenho ---

func _draw_controls() -> void:
	_draw_stick(_canvas, _move_center, _move_center + _move_vec.limit_length(1.0) * STICK_RADIUS, _move_finger != -1)
	_draw_stick(_canvas, _aim_center, _aim_center + _aim_vec.limit_length(1.0) * STICK_RADIUS, _aim_finger != -1)
	for role: StringName in [ROLE_WEAPON, ROLE_DASH, ROLE_PAUSE, ROLE_INTERACT]:
		if _button_enabled(role):
			_draw_button(_canvas, role, _button_center(role), _pressed_roles.get(role, false))


func _draw_stick(ci: CanvasItem, center: Vector2, thumb: Vector2, active: bool) -> void:
	ci.draw_circle(center, STICK_RADIUS, Color(FILL.r, FILL.g, FILL.b, 0.28))
	ci.draw_arc(center, STICK_RADIUS, 0.0, TAU, 48, RING, 3.0, true)
	ci.draw_circle(thumb, THUMB_RADIUS, FILL_PRESSED if active else FILL)
	ci.draw_arc(thumb, THUMB_RADIUS, 0.0, TAU, 32, RING, 2.0, true)


func _draw_button(ci: CanvasItem, role: StringName, center: Vector2, pressed: bool) -> void:
	var radius: float = _button_radius(role)
	ci.draw_circle(center, radius, FILL_PRESSED if pressed else FILL)
	ci.draw_arc(center, radius, 0.0, TAU, 40, RING, 3.0, true)
	var s: float = radius / 46.0
	match role:
		ROLE_WEAPON:
			if weapon_ranged:
				_draw_shot_icon(ci, center, s)
			else:
				_draw_sword_icon(ci, center, s)
		ROLE_DASH:
			ci.draw_polyline(PackedVector2Array([
				center + Vector2(-17.0, -14.0) * s, center + Vector2(-3.0, 0.0) * s, center + Vector2(-17.0, 14.0) * s]), ICON, 5.0 * s, true)
			ci.draw_polyline(PackedVector2Array([
				center + Vector2(3.0, -14.0) * s, center + Vector2(17.0, 0.0) * s, center + Vector2(3.0, 14.0) * s]), ICON, 5.0 * s, true)
		ROLE_PAUSE:
			ci.draw_rect(Rect2(center + Vector2(-9.0, -10.0), Vector2(6.0, 20.0)), ICON)
			ci.draw_rect(Rect2(center + Vector2(3.0, -10.0), Vector2(6.0, 20.0)), ICON)
		ROLE_INTERACT:
			var font: Font = ThemeDB.fallback_font
			ci.draw_string(font, center + Vector2(-radius, 11.0), "E", HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 32, ICON)


func _draw_sword_icon(ci: CanvasItem, center: Vector2, s: float) -> void:
	ci.draw_line(center + Vector2(-14.0, 14.0) * s, center + Vector2(17.0, -17.0) * s, ICON, 6.0 * s, true)
	ci.draw_line(center + Vector2(-17.0, 3.0) * s, center + Vector2(-3.0, 17.0) * s, ICON, 5.0 * s, true)
	ci.draw_circle(center + Vector2(-19.0, 19.0) * s, 4.0 * s, ICON)


func _draw_shot_icon(ci: CanvasItem, center: Vector2, s: float) -> void:
	ci.draw_circle(center, 7.0 * s, ICON)
	ci.draw_arc(center, 16.0 * s, 0.0, TAU, 28, ICON, 3.0 * s, true)
	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		ci.draw_line(center + direction * 16.0 * s, center + direction * 24.0 * s, ICON, 3.0 * s, true)


# --- Tutorial de controles (substitui a imagem de teclado/mouse no celular) ---

func _build_mobile_tutorial(tutorial: Control) -> void:
	if not is_instance_valid(tutorial) or tutorial.has_node("MobileTutorial"):
		return
	var tutorial_layer := CanvasLayer.new()
	tutorial_layer.name = "MobileTutorial"
	tutorial_layer.layer = 20
	tutorial.add_child(tutorial_layer)
	var background := ColorRect.new()
	background.color = Color(0.03, 0.06, 0.11)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	tutorial_layer.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	tutorial_layer.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "CONTROLES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.1))
	column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	column.add_child(grid)
	var rows: Array[Array] = [
		[ROLE_MOVE, "MOVER", "Analógico esquerdo."],
		[ROLE_AIM, "MIRAR E ATACAR", "Analógico direito: arraste para mirar (uma área colorida mostra o alcance) e solte para atacar. Com o tiro, segurar carrega. Um toque rápido mira no inimigo mais próximo."],
		[ROLE_WEAPON, "TROCAR DE ARMA", "Alterna entre a espada (área laranja) e o tiro carregado (barra azul)."],
		[ROLE_DASH, "ESQUIVAR", "Dash: desvia dos ataques por um instante."],
		[ROLE_INTERACT, "INTERAGIR", "O botão E aparece perto do terminal."],
		[ROLE_PAUSE, "PAUSA", "Botão no canto superior direito (ou o botão voltar do celular)."],
	]
	for row: Array in rows:
		grid.add_child(_tutorial_cell(row[0], row[1], row[2]))
	var button := Button.new()
	button.text = "Continuar"
	button.custom_minimum_size = Vector2(320.0, 64.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 28)
	button.pressed.connect(func() -> void:
		if is_instance_valid(tutorial) and tutorial.has_method("_on_continue_pressed"):
			tutorial.call("_on_continue_pressed"))
	column.add_child(button)


func _tutorial_cell(role: StringName, heading: String, body: String) -> Control:
	var cell := HBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_constant_override("separation", 14)
	var icon := TutorialIcon.new()
	icon.role = role
	icon.owner_controls = self
	icon.custom_minimum_size = Vector2(112.0, 112.0)
	cell.add_child(icon)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	var head := Label.new()
	head.text = heading
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	texts.add_child(head)
	var text := Label.new()
	text.text = body
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 19)
	texts.add_child(text)
	cell.add_child(texts)
	return cell


## Ícone de controle do tutorial (reaproveita o desenho dos botões).
class TutorialIcon extends Control:
	var role: StringName = &""
	var owner_controls: Node = null

	func _draw() -> void:
		if owner_controls == null:
			return
		var center: Vector2 = size * 0.5
		if role == &"move" or role == &"aim":
			draw_set_transform(center, 0.0, Vector2(0.62, 0.62))
			owner_controls.call("_draw_stick", self, Vector2.ZERO, Vector2(26.0, -16.0), false)
		else:
			owner_controls.call("_draw_button", self, role, center, false)
