extends Node
## Captura (com janela) dos efeitos das habilidades novas e dos ajustes numa fase real, para conferir o visual.
##   godot --path . res://tests/habilidades_shot.tscn -- <acao> <png> [largura altura]
## acao: emp | halo | escudo | drone | mina | leque | gelido | enigma | overclock | comando | levelup
## As ações de efeito recortam e ampliam (x2) a região em volta do jogador; `comando` e `levelup` capturam a tela cheia.

const FASE: String = "res://Scenes/Fase2/Fase2.tscn"
const RECORTE: Vector2i = Vector2i(400, 300)
const AMPLIAR: int = 2

var _player: Player = null
var _hab: AbilityComponent = null


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _ready() -> void:
	_run.call_deferred()


func _dados(id: StringName) -> AbilityData:
	return load("res://abilities/data/%s.tres" % id) as AbilityData


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var acao: String = args[0]
	var png: String = args[1]
	var largura: int = int(args[2]) if args.size() > 3 else 1152
	var altura: int = int(args[3]) if args.size() > 3 else 648
	var janela: Window = get_tree().root
	janela.mode = Window.MODE_WINDOWED
	janela.size = Vector2i(largura, altura)
	await _frames(2)
	if acao == "levelup":
		await _levelup()
	else:
		await _efeito(acao)
	await RenderingServer.frame_post_draw
	var imagem: Image = get_tree().root.get_texture().get_image()
	if acao != "levelup" and acao != "comando":
		var centro: Vector2 = get_viewport().get_canvas_transform() * _player.global_position
		var origem: Vector2i = Vector2i(int(centro.x) - RECORTE.x / 2, int(centro.y) - RECORTE.y / 2)
		origem = origem.clamp(Vector2i.ZERO, Vector2i(imagem.get_width() - RECORTE.x, imagem.get_height() - RECORTE.y))
		imagem = imagem.get_region(Rect2i(origem, RECORTE))
		imagem.resize(RECORTE.x * AMPLIAR, RECORTE.y * AMPLIAR, Image.INTERPOLATE_NEAREST)
	imagem.save_png(png)
	print("salvo ", png)
	get_tree().quit()


func _efeito(acao: String) -> void:
	var fase: Node = (load(FASE) as PackedScene).instantiate()
	get_tree().root.add_child(fase)
	get_tree().current_scene = fase
	await _frames(30)
	_player = fase.find_child("Player", true, false) as Player
	_hab = _player.get_node("AbilityComponent") as AbilityComponent
	_hab.command_time_scale = 1.0
	for inimigo: Node in get_tree().get_nodes_in_group(CombatUtils.GROUP_ENEMY):
		inimigo.queue_free()  # só o jogador e o efeito
	match acao:
		"emp":
			_hab.learn(_dados(&"pulso_emp"))
			await _frames(3)
			_hab._open_command_mode()
			_hab._on_arrow(AbilityData.Dir.DOWN)
			await _frames(8)
		"halo":
			_hab._activate(_dados(&"rastro_de_fogo"))
			await _frames(25)
		"escudo":
			_hab._activate(_dados(&"escudo"))
			await _frames(20)
		"drone":
			_hab._activate(_dados(&"drone_aliado"))
			await _frames(40)
		"mina":
			_hab.learn(_dados(&"mina_binaria"))  # a mina some se o jogador não tiver a habilidade
			_hab._activate(_dados(&"mina_binaria"))
			await _frames(70)
		"leque":
			_hab._activate(_dados(&"tiro_em_leque"))
			await _frames(14)
		"gelido":
			_hab._activate(_dados(&"pulso_gelido"))
			await _frames(12)
		"enigma":
			_hab._activate(_dados(&"maquina_enigma"))
			await _frames(25)
		"overclock":
			_hab._activate(_dados(&"overclock"))
			await _frames(25)
		"comando":  # painel do modo comando e faixa de slots com 3 habilidades novas
			for id: StringName in [&"reflexos", &"mina_binaria", &"overclock"]:
				_hab.learn(_dados(id))
			await _frames(5)
			_hab._activate(_dados(&"reflexos"))
			await _frames(20)
			_hab._open_command_mode()
			await _frames(10)


## Menu de escolha real, com o botão de reroll (3 lendárias: o pior caso de altura).
func _levelup() -> void:
	var menu: LevelUpMenu = LevelUpMenu.new()
	menu.input_delay = 0.0
	get_tree().root.add_child(menu)
	var oferta: Array[AbilityData] = [_dados(&"maquina_enigma"), _dados(&"overclock"), _dados(&"modo_sanguinario")]
	menu.open(3, oferta, [_dados(&"reflexos")])
	await _frames(45)
