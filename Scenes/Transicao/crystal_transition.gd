class_name CrystalTransition
extends Node
## Transição do cristal (fim da sala nova -> fase de defesa). Roda em cima da cena atual:
##   1. glitch curto (tremida + aberração de cor, como nas cutscenes)
##   2. tela de chiado (ruído procedural)
##   3. voz do tutorial: "Você conseguiu!" (mesmo visual da voz do tutorial)
##   4. novo chiado
##   5. o ser misterioso, na caixa de diálogo das cutscenes sobre a ilustração do laboratório
## Segurar ESC pula tudo. No fim emite `finished` e pede a próxima cena ao EventBus (o Global faz o fade).

signal finished  # A sequência acabou (a troca de cena já foi pedida).

# ===== BALANCEAMENTO =====
const GLITCH_TIME: float = 0.9  # Duração do glitch inicial (s).
const STATIC_TIME_1: float = 1.2  # Primeiro chiado (s).
const STATIC_TIME_2: float = 0.9  # Segundo chiado (s).
const STATIC_FADE: float = 0.3  # Tempo do chiado sumindo (s).
const STRANGER_NAME: String = "???"
const LAB_IMAGE: Texture2D = preload("res://sprites/Cutscenes/Lab-Turing.png")  # Ilustração das cutscenes.

@export_file("*.tscn") var next_scene: String = "res://Scenes/Defesa/Defesa.tscn"
@export var voice_lines: PackedStringArray = ["Você conseguiu!"]
@export var trap_lines: PackedStringArray = [
	"Na verdade não... isso era uma armadilha.",
	"Descobri uma rota de fuga. Defenda-a até ela ligar.",
]

var _fx: ScreenGlitch = null  # Efeitos de tela.
var _running: bool = false  # True depois de start() (não roda duas vezes).
var _skipped: bool = false  # O jogador segurou ESC.


## Dispara a sequência. Devolve na hora; use `await transition.finished` para esperar.
func start() -> void:
	if _running:
		return
	_running = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fx = ScreenGlitch.new()
	add_child(_fx)
	_run()


## Sequência completa (corrotina).
func _run() -> void:
	await _fx.glitch(GLITCH_TIME)
	await _fx.play_static(STATIC_TIME_1, true)  # O chiado fica ligado enquanto o fundo preto aparece por baixo.
	await _fx.fade_black(1.0, 0.01)
	_fx.stop_static(STATIC_FADE)
	await _say(voice_lines, Dialogue.Style.VOICE, "", null)
	if not _skipped:
		await _fx.play_static(STATIC_TIME_2, true)
		await _fx.fade_black(0.0, 0.01)  # Por baixo do chiado: a ilustração aparece quando ele some.
		_fx.stop_static(STATIC_FADE)
		await _say(trap_lines, Dialogue.Style.BOX, STRANGER_NAME, LAB_IMAGE)
	finished.emit()
	if not next_scene.is_empty():
		EventBus.scene_change_requested.emit(next_scene)


## Mostra as falas e espera terminar (se o jogador pulou, marca para encerrar a sequência).
func _say(lines: PackedStringArray, style: Dialogue.Style, speaker: String, backdrop: Texture2D) -> void:
	var dialogue: Dialogue = Dialogue.show_lines(self, lines, style, speaker, backdrop)
	dialogue.skipped.connect(func() -> void: _skipped = true)
	await dialogue.finished
