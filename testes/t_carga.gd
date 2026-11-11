extends TesteBase
## Carrega TODOS os scripts e cenas do projeto (menos addons): pega erro de parse, caminho quebrado e
## maiúsculas/minúsculas erradas nos recursos.

const IGNORE: Array[String] = ["res://addons/", "res://.godot/", "res://build/"]


func rodar() -> void:
	var files: Array[String] = []
	_collect("res://", files)
	var bad: int = 0
	for path: String in files:
		var res: Resource = ResourceLoader.load(path)
		if res == null:
			bad += 1
			print("  não carregou: ", path)
	check(bad == 0, "todos os %d scripts/cenas carregam" % files.size())
	# Cenas novas do modo celular.
	for path: String in ["res://testes/executor.tscn", "res://abilities/ui/abilities_ui.tscn", "res://ui/pause.tscn"]:
		var packed: PackedScene = load(path) as PackedScene
		check(packed != null and packed.instantiate() != null, "instancia " + path)
	# Assets gerados existem e são importados (carregam como textura).
	for name: String in ["btn_base.png", "ic_sword.png", "ic_swap.png", "ic_command.png", "ic_pause.png", "ic_dash.png",
			"stick_base.png", "stick_thumb.png", "board_frame.png", "arrow_up.png", "tilt_ring.png", "phone_neutral.png",
			"dpad_base.png", "glow_0.png", "joy_demo_0.png"]:
		check(MobileDraw.tex(name) != null, "asset gerado " + name)
	check(ResourceLoader.exists("res://referencias/mobile_layout.png"), "referencia mobile_layout.png")
	check(ResourceLoader.exists("res://referencias/mobile_layout_zonas.png"), "referencia mobile_layout_zonas.png")


func _collect(dir: String, out: Array[String]) -> void:
	for prefix: String in IGNORE:
		if dir.begins_with(prefix):
			return
	for sub: String in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(sub), out)
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".gd") or file.ends_with(".tscn"):
			out.append(dir.path_join(file))
