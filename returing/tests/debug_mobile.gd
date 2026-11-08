extends Node
func _ready() -> void:
	var level: Node = load("res://Scenes/Fase2/Fase2.tscn").instantiate()
	get_tree().root.add_child.call_deferred(level)
	for i in 40: await get_tree().physics_frame
	var mc = MobileControls
	print("shown=", mc._shown, " blocked=", mc._blocked, " player=", mc._player, " paused=", get_tree().paused, " view=", mc._view, " ativo=", mc.ativo)
	var wb: Vector2 = mc._button_center(&"weapon")
	print("conns=", EventBus.player_registered.get_connections().size(), " player node=", level.get_node_or_null("Player"))
	var e := InputEventScreenTouch.new(); e.index = 1; e.position = wb; e.pressed = true
	Input.parse_input_event(e)
	for i in 3: await get_tree().physics_frame
	print("fingers=", mc._fingers, " ranged=", mc.weapon_ranged)
	var e2 := InputEventScreenTouch.new(); e2.index = 1; e2.position = wb; e2.pressed = false
	Input.parse_input_event(e2)
	for i in 3: await get_tree().physics_frame
	print("after release fingers=", mc._fingers, " ranged=", mc.weapon_ranged)
	get_tree().quit()
