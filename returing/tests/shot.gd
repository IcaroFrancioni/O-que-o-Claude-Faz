extends SceneTree
## Uso: godot --path . --script tests/shot.gd -- <cena> <png> [frames]

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scene: PackedScene = load(args[0])
	var node: Node = scene.instantiate()
	root.add_child(node)
	var frames: int = int(args[2]) if args.size() > 2 else 40
	_run(args[1], frames)

func _run(out: String, frames: int) -> void:
	for i in frames:
		await process_frame
	var img: Image = root.get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()
