extends Control
## Pré-visualização do HUD das 9 habilidades novas (e de algumas antigas, para comparar), com dados de teste.
## Abas: slots de cooldown (pronta, ativa, em recarga, penalidade e sem habilidade), cartas do menu de
## escolha e cartas do menu de build (somente leitura).
##   godot --path . res://tests/hud_habilidades_novas.tscn                       (abre a janela)
##   godot --path . res://tests/hud_habilidades_novas.tscn -- <aba> <png> [l a]  (salva uma captura)
## `aba` é o índice da aba (0 = slots). Os tempos dos slots são estáticos: é só uma amostra visual.

const DATA_DIR: String = "res://abilities/data/"
const NOVAS: Array[StringName] = [
	&"reflexos", &"carga_rapida", &"pele_de_ferro", &"pulso_gelido", &"mina_binaria",
	&"drone_aliado", &"tiro_em_leque", &"maquina_enigma", &"overclock",
]
## Algumas antigas, só para comparar o estilo.
const ANTIGAS: Array[StringName] = [&"tiro_rapido", &"escudo", &"cavaleiro_imbativel"]
const ESTADOS: Array[String] = ["Pronta", "Ativa", "Em recarga", "Penalidade", "Sem habil."]
const NAME_WIDTH: float = 150.0
## Cartas por aba nas telas de escolha e de build.
const OFERTAS: Array[Array] = [
	[&"reflexos", &"carga_rapida", &"pele_de_ferro"],
	[&"pulso_gelido", &"mina_binaria", &"drone_aliado"],
	[&"tiro_em_leque", &"maquina_enigma", &"overclock"],
]

var _tabs: TabContainer = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Palette.load_theme()
	var fundo: ColorRect = ColorRect.new()
	fundo.color = Palette.BG
	add_child(fundo)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tabs = TabContainer.new()
	add_child(_tabs)
	_tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add_slots_tab()
	for i: int in OFERTAS.size():
		_add_cards_tab("Escolha %s" % "ABC"[i], OFERTAS[i], false)
	for i: int in OFERTAS.size():
		_add_cards_tab("Build %s" % "ABC"[i], OFERTAS[i], true)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() >= 2:
		_capturar.call_deferred(int(args[0]), args[1], int(args[2]) if args.size() > 3 else 1280,
				int(args[3]) if args.size() > 3 else 720)


func _dados(id: StringName) -> AbilityData:
	return load(DATA_DIR + String(id) + ".tres") as AbilityData


# --- Slots de cooldown ---

func _add_slots_tab() -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Slots"
	_tabs.add_child(scroll)
	var colunas: HBoxContainer = HBoxContainer.new()
	colunas.add_theme_constant_override(&"separation", Palette.UNIT * 4)
	scroll.add_child(colunas)
	var todas: Array[StringName] = NOVAS + ANTIGAS
	for metade: int in 2:
		var grade: GridContainer = GridContainer.new()
		grade.columns = ESTADOS.size() + 1
		grade.add_theme_constant_override(&"h_separation", Palette.UNIT)
		grade.add_theme_constant_override(&"v_separation", Palette.UNIT)
		colunas.add_child(grade)
		grade.add_child(_rotulo("Habilidade", NAME_WIDTH))
		for estado: String in ESTADOS:
			grade.add_child(_rotulo(estado, CooldownSlot.SLOT_SIZE + 8.0))
		for i: int in range(metade * 6, mini(metade * 6 + 6, todas.size())):
			_add_linha(grade, _dados(todas[i]))


func _rotulo(texto: String, largura: float) -> Label:
	var rotulo: Label = Label.new()
	rotulo.text = texto
	rotulo.theme_type_variation = &"HintLabel"
	rotulo.custom_minimum_size.x = largura
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return rotulo


func _add_linha(grade: GridContainer, dados: AbilityData) -> void:
	var nome: Label = _rotulo(dados.display_name, NAME_WIDTH)
	nome.theme_type_variation = &""
	grade.add_child(nome)
	var recarga: float = dados.cooldown
	var dur: float = dados.duration
	# Pronta
	grade.add_child(_slot(dados, 0.0))
	# Ativa (só quem tem duração)
	grade.add_child(_slot(dados, recarga - dur * 0.4) if dur > 0.0 else _rotulo("—", CooldownSlot.SLOT_SIZE))
	# Em recarga
	grade.add_child(_slot(dados, (recarga - dur) * 0.5))
	# Penalidade (só o Overclock)
	if dados.penalty_duration > 0.0:
		grade.add_child(_slot(dados, recarga - (dur - dados.penalty_duration * 0.5)))
	else:
		grade.add_child(_rotulo("—", CooldownSlot.SLOT_SIZE))
	# Sem habilidade
	var vazio: CooldownSlot = CooldownSlot.new()
	grade.add_child(_centrado(vazio))


func _slot(dados: AbilityData, restante: float) -> Control:
	var slot: CooldownSlot = CooldownSlot.new()
	slot.ability = dados
	var caixa: Control = _centrado(slot)
	slot.update_cooldown.call_deferred(restante, dados.cooldown, false)
	return caixa


func _centrado(slot: CooldownSlot) -> Control:
	var caixa: CenterContainer = CenterContainer.new()
	caixa.custom_minimum_size = Vector2(CooldownSlot.SLOT_SIZE + 8.0, CooldownSlot.SLOT_SIZE + 8.0)
	caixa.add_child(slot)
	return caixa


# --- Cartas ---

func _add_cards_tab(titulo: String, ids: Array, somente_leitura: bool) -> void:
	var raiz: VBoxContainer = VBoxContainer.new()
	raiz.name = titulo
	raiz.alignment = BoxContainer.ALIGNMENT_CENTER
	raiz.add_theme_constant_override(&"separation", Palette.UNIT)
	_tabs.add_child(raiz)
	var cabecalho: Label = Label.new()
	cabecalho.text = "SUA BUILD" if somente_leitura else "NÍVEL 3 — ESCOLHA UMA HABILIDADE"
	cabecalho.theme_type_variation = &"PanelTitleLabel"
	cabecalho.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	raiz.add_child(cabecalho)
	var linha: HBoxContainer = HBoxContainer.new()
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_theme_constant_override(&"separation", Palette.UNIT * 3)
	raiz.add_child(linha)
	var tem_lendaria: bool = false
	for id: StringName in ids:
		tem_lendaria = tem_lendaria or _dados(id).rarity == AbilityData.Rarity.LENDARIA
	for id: StringName in ids:
		var carta: LevelUpCard = LevelUpCard.new()
		linha.add_child(carta)
		carta.setup(_dados(id), tem_lendaria and not somente_leitura, somente_leitura)


# --- Captura ---

func _capturar(aba: int, png: String, largura: int, altura: int) -> void:
	var janela: Window = get_tree().root
	janela.mode = Window.MODE_WINDOWED
	janela.size = Vector2i(largura, altura)
	_tabs.current_tab = clampi(aba, 0, _tabs.get_tab_count() - 1)
	for i: int in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(png)
	print("salvo ", png)
	get_tree().quit()
