class_name ResultScreen
extends CanvasLayer
## Tela final no estilo arcade: soma os pontos, mostra o decréscimo do dano tomado, o total e o rank.
## Tudo é montado por código (Label, _draw e Tween); sem shader nem áudio novo.

## Fim da animação (ou do "pular"): os botões já estão ativos.
signal animacao_terminou

const SCENE_PATH: String = "res://ui/result/result_screen.tscn"

enum Estado { ANIMANDO, RAPIDO, FIM }

# --- Textos ---
const TEXTO_TITULO: String = "RUN COMPLETA"
const TEXTO_PONTOS: String = "PONTOS"
const TEXTO_INIMIGOS: String = "INIMIGOS ABATIDOS"
const TEXTO_OUTROS: String = "OUTROS"
const TEXTO_SUBTOTAL: String = "SUBTOTAL"
const TEXTO_DANO_TOMADO: String = "DANO TOMADO"
const TEXTO_TOTAL: String = "TOTAL FINAL"
const TEXTO_RANK: String = "RANK"
const TEXTO_NOVO_RECORDE: String = "NOVO RECORDE!"
const TEXTO_PRESSIONE: String = "PRESSIONE ENTER"
const TEXTO_JOGAR_DE_NOVO: String = "JOGAR DE NOVO"
const TEXTO_MENU: String = "MENU PRINCIPAL"

# --- Animação (constantes que não são tempo) ---
## Deslocamento horizontal inicial (px) de uma linha que entra deslizando.
const DESLOCAMENTO_ENTRADA_PX: float = 48.0
const ESCALA_INICIAL_RANK: float = 3.0
const AMPLITUDE_TREMOR_DANO_PX: float = 4.0
const AMPLITUDE_TREMOR_RANK_PX: float = 7.0
const ALPHA_FLASH_DANO: float = 0.35
const ALPHA_FLASH_RANK: float = 0.85
## Multiplicador de brilho (modulate) do pulso do total; volta a Color.WHITE (neutro).
const COR_PULSO_DOURADO: Color = Color(1.5, 1.3, 0.9, 1.0)
const DURACAO_PULSO_DOURADO_S: float = 0.35
const PERIODO_PISCA_S: float = 0.5
const ALPHA_PISCA_MIN: float = 0.25

# --- Visual ---
const PASSO_VARREDURA_PX: int = 2
## Cores vêm da Palette (DANGER é só para ações destrutivas, então a penalidade usa TEXT_DIM).
const COR_SEPARADOR: Color = Palette.BORDER
const COR_ODOMETRO_APAGADO: Color = Palette.BORDER
const COR_PENALIDADE: Color = Palette.TEXT_DIM
## Tamanhos: múltiplos de 16 (VT323 e Pixelify Sans ficam nítidas assim).
const FONTE_TITULO: int = Palette.FONT_BODY
const FONTE_CORPO: int = Palette.FONT_SMALL
const FONTE_PEQUENA: int = Palette.FONT_SMALL
const FONTE_ODOMETRO: int = Palette.FONT_BODY
const FONTE_TOTAL: int = Palette.FONT_BODY
const FONTE_RANK: int = Palette.FONT_TITLE
const LARGURA_COLUNA: float = 720.0
const MARGEM_TELA: float = 16.0
const ESPACO_LINHAS: int = 3
const LARGURA_DETALHE: float = 160.0
const LARGURA_VALOR: float = 130.0
const RECUO_TIPO: float = 18.0
const TAMANHO_ICONE: float = 12.0
const DIGITOS_ODOMETRO: int = 8
const MAX_TIPOS: int = 6

@export_group("Animação (s)")
@export var animar: bool = true
@export var tempo_fade_tela: float = 0.5
@export var tempo_fade_titulo: float = 0.6
@export var tempo_entrada_linha: float = 0.25
@export var tempo_contagem: float = 0.7
@export var tempo_odometro: float = 0.5
@export var pausa_apos_linha: float = 0.25
@export var intervalo_entre_inimigos: float = 0.2
@export var tempo_contagem_inimigo: float = 0.4
@export var tempo_rolagem_inimigos: float = 0.5
@export var tempo_subtotal: float = 0.6
@export var tempo_dano_tomado: float = 0.9
@export var tempo_flash_dano: float = 0.15
@export var tempo_tremor_dano: float = 0.2
@export var tempo_total_final: float = 1.2
@export var pausa_antes_do_rank: float = 0.8
@export var tempo_escala_rank: float = 0.35
@export var tempo_flash_rank: float = 0.1
@export var tempo_tremor_rank: float = 0.25
@export var tempo_por_letra: float = 0.04
## Multiplicador do primeiro "pular" (aperta uma vez: acelera).
@export var velocidade_rapida: float = 4.0
## Entradas nos primeiros segundos não contam como "pular" (cliques de ataque ainda no dedo).
@export var entrada_ignorada_s: float = 0.5

## Resultado a mostrar e recorde (`HighScoreStore.registrar`). Defina antes de entrar na árvore.
var resultado: ScoreResult = null
var recorde: Dictionary = {}

var _raiz: Control = null
var _coluna: VBoxContainer = null
var _odometro: RichTextLabel = null
var _titulo_caixa: Control = null
var _parciais_wrap: Control = null
var _cabecalho_inimigos: Label = null
var _linha_tempo_ui: LinhaUi = null
var _linhas_inimigos_ui: Array[LinhaUi] = []
var _linhas_extras_ui: Array[LinhaUi] = []
var _linha_subtotal: LinhaUi = null
var _linha_penalidade: LinhaUi = null
var _linha_total: LinhaUi = null
var _caixa_rank: Control = null
var _letra_rank: Label = null
var _nome_rank: Label = null
var _linha_recorde: Label = null
var _pressione: Label = null
var _botoes: HBoxContainer = null
var _botao_jogar: Button = null
var _botao_menu: Button = null
var _pausou_a_arvore: bool = false
var _flash: ColorRect = null
var _tween: Tween = null
var _tween_tremor: Tween = null
var _tweens_pisca: Array[Tween] = []
var _estado: Estado = Estado.ANIMANDO
## Velocidade atual da sequência (1.0 normal; `velocidade_rapida` depois do 1º pular).
var _velocidade: float = 1.0
var _aberta_em_ms: int = 0
var _posicao_base: Vector2 = Vector2.ZERO


## Uma linha de pontos: rótulo, detalhe (ex.: "x30") e valor.
class LinhaUi extends RefCounted:
	## MarginContainer: a margem esquerda faz a linha "deslizar" ao entrar.
	var raiz: MarginContainer
	var rotulo: Label
	var detalhe: Label
	var valor: Label
	## Pontos finais da linha (o sinal é aplicado na hora de exibir).
	var pontos: int = 0
	var sinal: String = "+"


	func texto_valor(v: int) -> String:
		return "0" if v == 0 else "%s%d" % [sinal, v]


## Linhas de varredura desenhadas por código.
class Varredura extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)


	func _draw() -> void:
		var pontos := PackedVector2Array()
		var y: float = 0.0
		while y < size.y:
			pontos.append(Vector2(0.0, y))
			pontos.append(Vector2(size.x, y))
			y += float(PASSO_VARREDURA_PX)
		draw_multiline(pontos, Palette.with_alpha(Palette.TEXT, Palette.SCANLINE_ALPHA), 1.0)


## Ícone simples gerado por código: quadrado com a cor derivada do tipo (estável).
class Icone extends Control:
	var cor: Color = Color.WHITE


	func _init(tipo: StringName, tamanho: float) -> void:
		custom_minimum_size = Vector2(tamanho, tamanho)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		cor = Color.from_hsv(float(String(tipo).hash() % 360) / 360.0, 0.55, 0.9)


	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), cor)
		draw_rect(Rect2(Vector2.ZERO, size), Palette.with_alpha(Palette.BG, 0.8), false, 1.0)


## Instancia a tela na cena atual, já com o resultado.
static func abrir(contexto: Node, p_resultado: ScoreResult, p_recorde: Dictionary, p_animar: bool = true) -> ResultScreen:
	var cena := load(SCENE_PATH) as PackedScene
	var tela := cena.instantiate() as ResultScreen
	tela.resultado = p_resultado
	tela.recorde = p_recorde
	tela.animar = p_animar
	var pai: Node = CombatUtils.get_spawn_parent(contexto)
	if pai == null:
		tela.free()
		return null
	pai.add_child(tela)
	return tela


## Segundos como `mm:ss.cc` (centésimos).
static func formatar_tempo(segundos: float) -> String:
	var centesimos: int = maxi(roundi(segundos * 100.0), 0)
	return "%02d:%02d.%02d" % [floori(centesimos / 6000.0), floori(centesimos / 100.0) % 60, centesimos % 100]


## Segundos como `mm:ss` (parciais por fase).
static func formatar_parcial(segundos: float) -> String:
	var total: int = maxi(roundi(segundos), 0)
	return "%02d:%02d" % [floori(total / 60.0), total % 60]


## Número com vírgula decimal (padrão brasileiro).
static func formatar_decimal(valor: float) -> String:
	return ("%.1f" % valor).replace(".", ",")


func _ready() -> void:
	if resultado == null:
		push_warning("ResultScreen: sem resultado; nada a mostrar.")
		return
	Engine.time_scale = 1.0
	if not get_tree().paused:
		get_tree().paused = true
		_pausou_a_arvore = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_aberta_em_ms = Time.get_ticks_msec()
	_construir()
	_reposicionar()
	if animar:
		_iniciar_animacao()
	else:
		_aplicar_estado_final()
	_reposicionar.call_deferred()


func _exit_tree() -> void:
	_parar_tweens()
	if _pausou_a_arvore and is_inside_tree():
		get_tree().paused = false


## Pular: 1º toque acelera (×velocidade_rapida), 2º vai direto ao estado final.
## Toque na tela chega como clique (o projeto emula mouse a partir do toque).
func _input(event: InputEvent) -> void:
	if _raiz == null or _estado == Estado.FIM:
		return
	if float(Time.get_ticks_msec() - _aberta_em_ms) / 1000.0 < entrada_ignorada_s:
		return
	var teclado: bool = event.is_action_pressed(&"ui_accept") and not event.is_echo()
	var mouse := event as InputEventMouseButton
	var clique: bool = mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	if not (teclado or clique):
		return
	get_viewport().set_input_as_handled()
	if _estado == Estado.ANIMANDO:
		_estado = Estado.RAPIDO
		_velocidade = velocidade_rapida
		if _tween != null and _tween.is_valid():
			_tween.set_speed_scale(_velocidade)
	else:
		_aplicar_estado_final()


# --- Construção ---

func _construir() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	_raiz.theme = Palette.load_theme()
	add_child(_raiz)
	_raiz.resized.connect(_reposicionar)

	var fundo := ColorRect.new()
	fundo.color = Palette.BG
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(fundo)

	var varredura := Varredura.new()
	varredura.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(varredura)

	_coluna = VBoxContainer.new()
	_coluna.add_theme_constant_override(&"separation", ESPACO_LINHAS)
	_coluna.custom_minimum_size.x = LARGURA_COLUNA
	_raiz.add_child(_coluna)

	_titulo_caixa = _montar_titulo()
	_coluna.add_child(_titulo_caixa)
	_coluna.add_child(_montar_odometro())
	_coluna.add_child(_novo_separador())
	_montar_corpo()
	_montar_rodape()

	_flash = ColorRect.new()
	_flash.color = Palette.with_alpha(Palette.TEXT, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_flash)


func _montar_titulo() -> Control:
	var caixa := HBoxContainer.new()
	caixa.alignment = BoxContainer.ALIGNMENT_CENTER
	caixa.add_theme_constant_override(&"separation", Palette.UNIT * 2)
	var titulo: Label = _novo_rotulo(TEXTO_TITULO, FONTE_TITULO, Palette.TEXT)
	titulo.theme_type_variation = &"PanelTitleLabel"
	caixa.add_child(titulo)
	return caixa


func _montar_odometro() -> Control:
	var caixa := HBoxContainer.new()
	var rotulo := _novo_rotulo(TEXTO_PONTOS, FONTE_CORPO + 2, Palette.TEXT)
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotulo.size_flags_vertical = Control.SIZE_SHRINK_END
	caixa.add_child(rotulo)
	_odometro = RichTextLabel.new()
	_odometro.bbcode_enabled = true
	_odometro.fit_content = true
	_odometro.scroll_active = false
	_odometro.autowrap_mode = TextServer.AUTOWRAP_OFF
	_odometro.custom_minimum_size = Vector2(300.0, 0.0)
	_odometro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_odometro.add_theme_font_size_override(&"normal_font_size", FONTE_ODOMETRO)
	caixa.add_child(_odometro)
	definir_odometro(0)
	return caixa


## Odômetro de 8 dígitos: zeros à esquerda apagados, o número em dourado.
func definir_odometro(valor: int) -> void:
	var texto: String = "%0*d" % [DIGITOS_ODOMETRO, clampi(valor, 0, 99999999)]
	var apagados: int = 0
	while apagados < DIGITOS_ODOMETRO - 1 and texto[apagados] == "0":
		apagados += 1
	_odometro.text = "[right][color=#%s]%s[/color][color=#%s]%s[/color][/right]" % [
		COR_ODOMETRO_APAGADO.to_html(true), texto.substr(0, apagados),
		Palette.ACCENT.to_html(false), texto.substr(apagados)]


func _montar_corpo() -> void:
	var tempo: ScoreResult.Linha = resultado.linha_tempo
	_linha_tempo_ui = _nova_linha(tempo.rotulo, formatar_tempo(tempo.valor), tempo.pontos)
	_adicionar(_linha_tempo_ui)
	var parciais := _novo_rotulo(_texto_parciais(), FONTE_PEQUENA, Palette.TEXT_DIM)
	parciais.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var recuo := MarginContainer.new()
	recuo.add_theme_constant_override(&"margin_left", int(RECUO_TIPO))
	recuo.add_child(parciais)
	_parciais_wrap = recuo
	_coluna.add_child(recuo)

	_cabecalho_inimigos = _novo_rotulo(TEXTO_INIMIGOS, FONTE_CORPO, Palette.TEXT_DIM)
	_cabecalho_inimigos.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_coluna.add_child(_cabecalho_inimigos)
	for d: Dictionary in _linhas_de_inimigos():
		var linha_inimigo: LinhaUi = _nova_linha(d["rotulo"], "x%d" % d["qtd"], d["pontos"], d["tipo"])
		_linhas_inimigos_ui.append(linha_inimigo)
		_adicionar(linha_inimigo)

	var variedade: ScoreResult.Linha = resultado.linha_variedade
	var n_tipos: int = roundi(variedade.valor)
	_extra(_nova_linha(variedade.rotulo, "%d %s" % [n_tipos, "TIPO" if n_tipos == 1 else "TIPOS"], variedade.pontos))
	var combo: ScoreResult.Linha = resultado.linha_combo
	_extra(_nova_linha(combo.rotulo, "x%d" % roundi(combo.valor), combo.pontos))
	var dano: ScoreResult.Linha = resultado.linha_dano
	_extra(_nova_linha(dano.rotulo, str(roundi(dano.valor)), dano.pontos))
	if resultado.linha_quiz != null:
		var quiz: ScoreResult.Linha = resultado.linha_quiz
		var acertos: int = roundi(quiz.valor)
		_extra(_nova_linha(quiz.rotulo, "%d %s" % [acertos, "ACERTO" if acertos == 1 else "ACERTOS"], quiz.pontos))

	_coluna.add_child(_novo_separador())
	_linha_subtotal = _nova_linha(TEXTO_SUBTOTAL, "", resultado.bruto, &"", "")
	_adicionar(_linha_subtotal)
	var barras: String = "%s %s" % [formatar_decimal(resultado.barras_perdidas),
			"BARRA" if is_equal_approx(resultado.barras_perdidas, 1.0) else "BARRAS"]
	_linha_penalidade = _nova_linha(TEXTO_DANO_TOMADO, barras, resultado.penalidade, &"", "-")
	for l: Label in [_linha_penalidade.rotulo, _linha_penalidade.detalhe, _linha_penalidade.valor]:
		l.add_theme_color_override(&"font_color", COR_PENALIDADE)
	_adicionar(_linha_penalidade)
	_coluna.add_child(_novo_separador())
	_linha_total = _nova_linha(TEXTO_TOTAL, "", resultado.total, &"", "")
	for l: Label in [_linha_total.rotulo, _linha_total.valor]:
		l.add_theme_font_size_override(&"font_size", FONTE_TOTAL)
		l.add_theme_color_override(&"font_color", Palette.TEXT)
	_adicionar(_linha_total)


func _montar_rodape() -> void:
	var caixa := HBoxContainer.new()
	caixa.alignment = BoxContainer.ALIGNMENT_CENTER
	caixa.add_theme_constant_override(&"separation", Palette.UNIT * 2)
	caixa.add_child(_novo_rotulo(TEXTO_RANK, FONTE_CORPO + 2, Palette.TEXT))
	_caixa_rank = caixa
	var moldura := PanelContainer.new()
	_letra_rank = _novo_rotulo(String(resultado.rank), FONTE_RANK, resultado.cor_do_rank())
	_letra_rank.custom_minimum_size.x = float(FONTE_RANK)
	moldura.add_child(_letra_rank)
	caixa.add_child(moldura)
	_nome_rank = _novo_rotulo(resultado.nome_do_rank(), FONTE_TOTAL, resultado.cor_do_rank())
	_nome_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_nome_rank.custom_minimum_size.x = 150.0
	caixa.add_child(_nome_rank)
	_coluna.add_child(caixa)

	_linha_recorde = _novo_rotulo(_texto_recorde(), FONTE_CORPO, Palette.ACCENT)
	_coluna.add_child(_linha_recorde)

	_pressione = _novo_rotulo(TEXTO_PRESSIONE, FONTE_CORPO, Palette.TEXT_DIM)
	_coluna.add_child(_pressione)

	_botoes = HBoxContainer.new()
	_botoes.alignment = BoxContainer.ALIGNMENT_CENTER
	_botoes.add_theme_constant_override(&"separation", Palette.UNIT * 2)
	_botao_jogar = PixelButton.new()
	_botao_jogar.text = TEXTO_JOGAR_DE_NOVO
	_botao_menu = PixelButton.new()
	_botao_menu.text = TEXTO_MENU
	_botoes.add_child(_botao_jogar)
	_botoes.add_child(_botao_menu)
	_coluna.add_child(_botoes)
	_botao_jogar.pressed.connect(_on_jogar_de_novo)
	_botao_menu.pressed.connect(_on_menu)


# --- Dados exibidos ---

## Até MAX_TIPOS linhas (ordem decrescente de pontos); o restante vira "OUTROS".
func _linhas_de_inimigos() -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var outros_qtd: int = 0
	var outros_pontos: int = 0
	for i: int in resultado.linhas_inimigos.size():
		var l: ScoreResult.Linha = resultado.linhas_inimigos[i]
		if i < MAX_TIPOS:
			saida.append({"rotulo": l.rotulo, "qtd": roundi(l.valor), "pontos": l.pontos, "tipo": l.tipo})
		else:
			outros_qtd += roundi(l.valor)
			outros_pontos += l.pontos
	if outros_qtd > 0:
		saida.append({"rotulo": TEXTO_OUTROS, "qtd": outros_qtd, "pontos": outros_pontos, "tipo": &"outros"})
	return saida


func _texto_parciais() -> String:
	var partes: PackedStringArray = []
	for i: int in resultado.tempos_por_fase.size():
		partes.append("F%d %s" % [i + 1, formatar_parcial(resultado.tempos_por_fase[i])])
	return "   ".join(partes)


func _texto_recorde() -> String:
	var anterior: Dictionary = recorde.get("anterior", {})
	var atual: Dictionary = recorde.get("atual", {})
	if recorde.get("novo_recorde", false):
		if anterior.is_empty():
			return TEXTO_NOVO_RECORDE
		return "%s    ANTERIOR %d (%s)" % [TEXTO_NOVO_RECORDE, anterior["total"], anterior["rank"]]
	if atual.is_empty():
		return ""
	return "MELHOR %d (%s)" % [atual["total"], atual["rank"]]


# --- Estado final (sem animação) ---

## Mostra tudo já concluído (também é o destino do segundo "pular").
func _aplicar_estado_final() -> void:
	_parar_tweens()
	_raiz.modulate.a = 1.0
	_flash.color.a = 0.0
	_coluna.position = _posicao_base
	_titulo_caixa.modulate.a = 1.0
	for l: LinhaUi in _todas_as_linhas():
		l.raiz.modulate.a = 1.0
		_definir_recuo(0.0, l)
		l.valor.text = l.texto_valor(l.pontos)
	for c: Control in [_parciais_wrap, _cabecalho_inimigos, _caixa_rank]:
		c.modulate.a = 1.0
	_letra_rank.scale = Vector2.ONE
	_nome_rank.visible_ratio = 1.0
	definir_odometro(resultado.total)
	_mostrar_final()


## Rodapé final: recorde, "PRESSIONE ENTER", botões e foco.
func _mostrar_final() -> void:
	_estado = Estado.FIM
	for c: Control in [_linha_recorde, _pressione, _botoes]:
		c.modulate.a = 1.0
	for b: Button in [_botao_jogar, _botao_menu]:
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_filter = Control.MOUSE_FILTER_STOP
	_iniciar_pisca(_pressione)
	if recorde.get("novo_recorde", false):
		_iniciar_pisca(_linha_recorde)
	_botao_jogar.grab_focus()
	animacao_terminou.emit()


func _todas_as_linhas() -> Array[LinhaUi]:
	var todas: Array[LinhaUi] = [_linha_tempo_ui]
	todas.append_array(_linhas_inimigos_ui)
	todas.append_array(_linhas_extras_ui)
	todas.append_array([_linha_subtotal, _linha_penalidade, _linha_total])
	return todas


# --- Animação ---

## Esconde tudo e zera os valores: a sequência revela cada parte na hora dela.
func _preparar_animacao() -> void:
	_estado = Estado.ANIMANDO
	_raiz.modulate.a = 0.0
	_titulo_caixa.modulate.a = 0.0
	for l: LinhaUi in _todas_as_linhas():
		l.raiz.modulate.a = 0.0
		_definir_recuo(DESLOCAMENTO_ENTRADA_PX, l)
		l.valor.text = l.texto_valor(0)
	for c: Control in [_parciais_wrap, _cabecalho_inimigos, _caixa_rank, _linha_recorde, _pressione, _botoes]:
		c.modulate.a = 0.0
	for b: Button in [_botao_jogar, _botao_menu]:
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nome_rank.visible_ratio = 0.0
	definir_odometro(0)


func _iniciar_animacao() -> void:
	_preparar_animacao()
	var t: Tween = UiTween.create(self)  # roda pausado e ignora a câmera lenta
	_tween = t
	var acumulado: int = 0

	t.tween_property(_raiz, ^"modulate:a", 1.0, tempo_fade_tela)
	t.tween_property(_titulo_caixa, ^"modulate:a", 1.0, tempo_fade_titulo)

	var extras_tempo: Array = [_parciais_wrap]
	if _linhas_inimigos_ui.is_empty():
		extras_tempo.append(_cabecalho_inimigos)  # sem linhas de inimigo ninguém mais o revelaria
	acumulado = _passo_pontos(t, _linha_tempo_ui, acumulado, extras_tempo)

	# Inimigos: cada linha conta sozinha; o odômetro rola uma vez só no fim do grupo.
	var soma_inimigos: int = 0
	for i: int in _linhas_inimigos_ui.size():
		var l: LinhaUi = _linhas_inimigos_ui[i]
		t.tween_interval(intervalo_entre_inimigos)
		_entrar(t, l, [_cabecalho_inimigos] if i == 0 else [])
		_contar(t, l, tempo_contagem_inimigo, true)
		soma_inimigos += l.pontos
	if not _linhas_inimigos_ui.is_empty():
		_rolar(t, acumulado, acumulado + soma_inimigos, tempo_rolagem_inimigos, false)
		t.tween_interval(pausa_apos_linha)
		acumulado += soma_inimigos

	for l: LinhaUi in _linhas_extras_ui:
		acumulado = _passo_pontos(t, l, acumulado, [])

	_entrar(t, _linha_subtotal, [])
	_contar(t, _linha_subtotal, tempo_subtotal, true)

	# Dano tomado: o valor conta, o odômetro rola para baixo, com flash vermelho e tremor.
	var tempo_contagem_dano: float = maxf(tempo_dano_tomado - tempo_entrada_linha, 0.01)
	_entrar(t, _linha_penalidade, [])
	t.tween_callback(_impacto_dano)
	_contar(t, _linha_penalidade, tempo_contagem_dano, false)
	_rolar(t, resultado.bruto, resultado.total, tempo_contagem_dano, true)

	_entrar(t, _linha_total, [])
	_contar(t, _linha_total, tempo_total_final, true)
	t.tween_callback(_pulso_dourado)

	t.tween_interval(pausa_antes_do_rank)
	t.tween_callback(_preparar_rank)
	t.tween_property(_letra_rank, ^"scale", Vector2.ONE, tempo_escala_rank) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(_impacto_rank)
	t.tween_interval(maxf(tempo_tremor_rank, tempo_flash_rank))
	t.tween_property(_nome_rank, ^"visible_ratio", 1.0, tempo_por_letra * float(_nome_rank.text.length()))
	t.tween_callback(_mostrar_final)


## Uma linha de pontos completa: entra, conta, o odômetro sobe e há uma pausa.
func _passo_pontos(t: Tween, l: LinhaUi, acumulado: int, extras: Array) -> int:
	_entrar(t, l, extras)
	_contar(t, l, tempo_contagem, false)
	_rolar(t, acumulado, acumulado + l.pontos, tempo_odometro, false)
	t.tween_interval(pausa_apos_linha)
	return acumulado + l.pontos


## A linha (e os extras) entra deslizando e aparecendo.
func _entrar(t: Tween, l: LinhaUi, extras: Array) -> void:
	t.tween_property(l.raiz, ^"modulate:a", 1.0, tempo_entrada_linha)
	t.parallel().tween_method(_definir_recuo.bind(l), DESLOCAMENTO_ENTRADA_PX, 0.0, tempo_entrada_linha) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for extra: Control in extras:
		t.parallel().tween_property(extra, ^"modulate:a", 1.0, tempo_entrada_linha)


## O valor conta de 0 até o número (ease out). `junto` = roda junto com a entrada da linha.
func _contar(t: Tween, l: LinhaUi, duracao: float, junto: bool) -> void:
	if junto:
		t.parallel()
	t.tween_method(_definir_valor.bind(l), 0.0, float(l.pontos), duracao) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## O odômetro vai de `de` a `para` (sobe ou desce). `junto` = roda junto com o passo anterior.
func _rolar(t: Tween, de: int, para: int, duracao: float, junto: bool) -> void:
	if junto:
		t.parallel()
	t.tween_method(_definir_odometro_f, float(de), float(para), duracao) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _definir_valor(v: float, l: LinhaUi) -> void:
	l.valor.text = l.texto_valor(roundi(v))


func _definir_odometro_f(v: float) -> void:
	definir_odometro(roundi(v))


func _definir_recuo(px: float, l: LinhaUi) -> void:
	l.raiz.add_theme_constant_override(&"margin_left", roundi(px))


func _impacto_dano() -> void:
	_flash_tela(COR_PENALIDADE, ALPHA_FLASH_DANO, tempo_flash_dano)
	_tremor(tempo_tremor_dano, AMPLITUDE_TREMOR_DANO_PX)


func _pulso_dourado() -> void:
	_linha_total.valor.modulate = COR_PULSO_DOURADO
	var tw: Tween = UiTween.create(self)
	tw.tween_property(_linha_total.valor, ^"modulate", Color.WHITE, DURACAO_PULSO_DOURADO_S)


## Rank entra grande (escala 3 -> 1) e a letra aparece.
func _preparar_rank() -> void:
	_letra_rank.pivot_offset = _letra_rank.size * 0.5
	_letra_rank.scale = Vector2.ONE * ESCALA_INICIAL_RANK
	_caixa_rank.modulate.a = 1.0


func _impacto_rank() -> void:
	_flash_tela(Palette.TEXT, ALPHA_FLASH_RANK, tempo_flash_rank)
	_tremor(tempo_tremor_rank, AMPLITUDE_TREMOR_RANK_PX)


func _flash_tela(cor: Color, alpha: float, duracao: float) -> void:
	_flash.color = Color(cor.r, cor.g, cor.b, alpha)
	var tw: Tween = UiTween.create(self)
	tw.tween_property(_flash, ^"color:a", 0.0, duracao)


## Tremor da coluna: a força cai de 1 a 0 em `duracao`.
func _tremor(duracao: float, amplitude: float) -> void:
	if _tween_tremor != null and _tween_tremor.is_valid():
		_tween_tremor.kill()
	_tween_tremor = UiTween.create(self)
	_tween_tremor.tween_method(_aplicar_tremor.bind(amplitude), 1.0, 0.0, duracao)


func _aplicar_tremor(forca: float, amplitude: float) -> void:
	_coluna.position = _posicao_base + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amplitude * forca


## Pisca (cursor): alpha vai e volta sem parar.
func _iniciar_pisca(c: Control) -> void:
	var tw: Tween = UiTween.create(self)
	tw.set_loops()
	tw.tween_property(c, ^"modulate:a", ALPHA_PISCA_MIN, PERIODO_PISCA_S)
	tw.tween_property(c, ^"modulate:a", 1.0, PERIODO_PISCA_S)
	_tweens_pisca.append(tw)


func _parar_tweens() -> void:
	for tw: Tween in [_tween, _tween_tremor]:
		if tw != null and tw.is_valid():
			tw.kill()
	for tw: Tween in _tweens_pisca:
		if tw != null and tw.is_valid():
			tw.kill()
	_tweens_pisca.clear()
	for c: Control in [_pressione, _linha_recorde]:
		if is_instance_valid(c):
			c.modulate.a = 1.0


# --- Ações ---

## Fluxo já existente: a Fase 1 reinicia a run sozinha (RunState.begin_scene -> reset).
func _on_jogar_de_novo() -> void:
	EventBus.scene_change_requested.emit(RunState.FIRST_LEVEL_SCENE)


func _on_menu() -> void:
	EventBus.main_menu_requested.emit()


# --- Ajuda de layout ---

func _adicionar(l: LinhaUi) -> void:
	_coluna.add_child(l.raiz)


## Linha de bônus (variedade, combo, dano causado, quiz).
func _extra(l: LinhaUi) -> void:
	_linhas_extras_ui.append(l)
	_adicionar(l)


func _novo_rotulo(texto: String, tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override(&"font_size", tamanho)
	l.add_theme_color_override(&"font_color", cor)
	return l


func _novo_separador() -> Control:
	var s := ColorRect.new()
	s.color = COR_SEPARADOR
	s.custom_minimum_size.y = 1.0
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


## Linha: [ícone] RÓTULO ....... detalhe ....... valor.
func _nova_linha(rotulo: String, detalhe: String, pontos: int, tipo: StringName = &"", sinal: String = "+") -> LinhaUi:
	var l := LinhaUi.new()
	l.pontos = pontos
	l.sinal = sinal
	var caixa := HBoxContainer.new()
	caixa.add_theme_constant_override(&"separation", Palette.UNIT)
	l.raiz = MarginContainer.new()
	l.raiz.add_child(caixa)
	if tipo != &"":
		var recuo := Control.new()
		recuo.custom_minimum_size.x = RECUO_TIPO
		caixa.add_child(recuo)
		caixa.add_child(Icone.new(tipo, TAMANHO_ICONE))
	l.rotulo = _novo_rotulo(rotulo, FONTE_CORPO, Palette.TEXT)
	l.rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caixa.add_child(l.rotulo)
	l.detalhe = _novo_rotulo(detalhe, FONTE_CORPO, Palette.TEXT_DIM)
	l.detalhe.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.detalhe.custom_minimum_size.x = LARGURA_DETALHE
	caixa.add_child(l.detalhe)
	l.valor = _novo_rotulo(l.texto_valor(pontos), FONTE_CORPO, Palette.TEXT)
	l.valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.valor.custom_minimum_size.x = LARGURA_VALOR
	caixa.add_child(l.valor)
	return l


## Centraliza a coluna e a reduz o quanto precisar para caber (16:9, 4:3 e ultra-wide).
func _reposicionar() -> void:
	if _raiz == null or _coluna == null:
		return
	var area: Vector2 = _raiz.size
	var tamanho: Vector2 = _coluna.get_combined_minimum_size()
	tamanho.x = maxf(tamanho.x, LARGURA_COLUNA)
	_coluna.size = tamanho
	var escala: float = minf(1.0, minf((area.x - 2.0 * MARGEM_TELA) / tamanho.x, (area.y - 2.0 * MARGEM_TELA) / tamanho.y))
	escala = maxf(escala, 0.1)
	_coluna.pivot_offset = Vector2.ZERO
	_coluna.scale = Vector2.ONE * escala
	_posicao_base = (area - tamanho * escala) * 0.5
	_coluna.position = _posicao_base
