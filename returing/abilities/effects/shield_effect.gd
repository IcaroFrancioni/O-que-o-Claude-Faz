class_name ShieldEffect
extends AbilityEffect
## Escudo: invulnerabilidade pela duração da habilidade, com um círculo ao redor do personagem.
## No FIM NATURAL (o tempo acabou) toca um som curto e o círculo "estala" num anel que se abre.
## Cancelar (morte, lendária apagando as outras, troca de cena) não toca o som.

const DEFAULT_TIME: float = 3.0
## Nos últimos segundos o círculo pisca para avisar que vai acabar.
const BLINK_TIME: float = 0.6
## Duração (s) do estalo visual no fim.
const BURST_TIME: float = 0.25
## Quanto (px) o anel do estalo se abre além do raio do escudo.
const BURST_GROWTH: float = 16.0

## Som do fim: tom curto e descendente, gerado por código (sem arquivo de áudio).
const END_SOUND_RATE: int = 22050
const END_SOUND_TIME: float = 0.2
const END_SOUND_FROM: float = 880.0
const END_SOUND_TO: float = 440.0
const END_SOUND_VOLUME: float = 0.45

@export var radius: float = 26.0
@export var shield_color: Color = Color(0.45, 0.8, 1.0, 1.0)

## True depois que o escudo acabou sozinho (o som e o estalo só acontecem aqui).
var ended_naturally: bool = false

static var _end_stream: AudioStreamWAV = null

var _time_left: float = DEFAULT_TIME
var _age: float = 0.0
var _burst_left: float = 0.0


func _on_activate() -> void:
	_time_left = data.duration if data != null and data.duration > 0.0 else DEFAULT_TIME
	caster.conceder_invulnerabilidade(_time_left)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if ended_naturally:  # estalo final: só espera a animação acabar
		_burst_left -= delta
		queue_redraw()
		if _burst_left <= 0.0:
			_finish()
		return
	_age += delta
	_time_left -= delta
	queue_redraw()
	if _time_left <= 0.0:
		_end_naturally()


## O tempo acabou: som curto e estalo. A invulnerabilidade já terminou junto com o tempo.
func _end_naturally() -> void:
	ended_naturally = true
	_burst_left = BURST_TIME
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = &"EndSound"
	player.stream = _get_end_stream()
	player.bus = &"SFX"
	add_child(player)
	player.play()


## Cancelado antes do fim (ex.: lendária apagando as outras): a invulnerabilidade também termina.
func _on_cleanup() -> void:
	if _time_left > 0.0 and is_instance_valid(caster):
		caster.remover_invulnerabilidade()


func _draw() -> void:
	if ended_naturally:
		var t: float = clampf(1.0 - _burst_left / BURST_TIME, 0.0, 1.0)
		var anel: Color = shield_color
		anel.a = 1.0 - t
		draw_arc(Vector2.ZERO, radius + BURST_GROWTH * t, 0.0, TAU, 48, anel, 3.0)
		return
	var pulso: float = 0.5 + 0.5 * sin(_age * 8.0)
	var alpha: float = 1.0
	if _time_left < BLINK_TIME:
		alpha = 0.35 + 0.65 * pulso
	var fill: Color = shield_color
	fill.a = 0.10 * alpha
	draw_circle(Vector2.ZERO, radius, fill)
	var borda: Color = shield_color
	borda.a = (0.55 + 0.35 * pulso) * alpha
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, borda, 2.0)
	var interna: Color = shield_color
	interna.a = 0.3 * alpha
	draw_arc(Vector2.ZERO, radius - 4.0, 0.0, TAU, 48, interna, 1.0)


## Tom descendente de 16 bits (criado uma vez e reaproveitado).
static func _get_end_stream() -> AudioStreamWAV:
	if _end_stream != null:
		return _end_stream
	var count: int = int(float(END_SOUND_RATE) * END_SOUND_TIME)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(count * 2)
	var phase: float = 0.0
	for i: int in count:
		var t: float = float(i) / float(count)
		phase += TAU * lerpf(END_SOUND_FROM, END_SOUND_TO, t) / float(END_SOUND_RATE)
		var envelope: float = pow(1.0 - t, 1.5)  # some suavemente, sem estalo no corte
		bytes.encode_s16(i * 2, int(sin(phase) * envelope * END_SOUND_VOLUME * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = END_SOUND_RATE
	stream.stereo = false
	stream.data = bytes
	_end_stream = stream
	return stream
