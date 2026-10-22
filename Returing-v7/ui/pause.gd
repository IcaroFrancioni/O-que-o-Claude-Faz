extends CanvasLayer
## Menu de pausa: congela a árvore, mostra os botões e delega a navegação ao EventBus
## (a troca de cena em si é feita pelo autoload Global, com fade).

const ACTION_PAUSE: StringName = &"Pause"

@onready var _continue_button: Button = $Continue_button
@onready var _reset_button: Button = $Reset_button
@onready var _bye_button: Button = $Bye_button

var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS  # continua ouvindo a tecla com o jogo pausado
	visible = false
	_continue_button.pressed.connect(resume)
	_reset_button.pressed.connect(_on_reset_pressed)
	_bye_button.pressed.connect(_on_menu_pressed)


## Alterna a pausa pela tecla (evento tratado uma única vez, sem polling por frame).
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(ACTION_PAUSE):
		return
	get_viewport().set_input_as_handled()
	if get_tree().paused:
		resume()
	else:
		pause()


func pause() -> void:
	get_tree().paused = true
	visible = true
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_continue_button.grab_focus()


func resume() -> void:
	get_tree().paused = false
	visible = false
	Input.mouse_mode = _previous_mouse_mode


func _on_reset_pressed() -> void:
	resume()
	EventBus.level_restart_requested.emit()


func _on_menu_pressed() -> void:
	resume()
	EventBus.main_menu_requested.emit()
