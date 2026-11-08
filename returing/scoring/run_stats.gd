class_name RunStats
extends RefCounted
## Números brutos da run (tempo, abates, dano). Sobrevive à troca de fase sem autoload.
## Não calcula pontos e não emite sinais: a pontuação só existe no fim (ScoreCalculator).

## Tempo de jogo acumulado (s). Só conta com o jogador de fato jogando uma fase.
static var tempo_s: float = 0.0
## Tempo gasto em cada fase concluída (s), na ordem em que foram concluídas.
static var tempos_por_fase: Array[float] = []
## Abates por tipo de inimigo (`StringName` -> `int`).
static var abates_por_tipo: Dictionary = {}
## Dano efetivo causado aos inimigos (já sem o excedente de um golpe que mata).
static var dano_causado: float = 0.0
## Dano efetivamente aplicado ao jogador (depois de i-frames e escudo).
static var dano_tomado: float = 0.0
## Maior sequência de abates seguidos dentro da janela de combo.
static var maior_sequencia_abates: int = 0
## Acertos de primeira no quiz.
static var acertos_quiz: int = 0
## True depois que a última fase terminou: o relógio e os contadores param.
static var finalizada: bool = false
## Vida máxima do jogador no início da run (0 = ainda não lida).
static var vida_max_inicial_jogador: float = 0.0

## Estado interno da sequência de abates atual.
static var _sequencia_atual: int = 0
static var _tempo_ultimo_abate_s: float = 0.0
## `tempo_s` no momento em que a última fase terminou (base do tempo da fase seguinte).
static var _tempo_fim_ultima_fase_s: float = 0.0


## Zera tudo (run nova). Nunca é chamado na troca de fase.
static func reset() -> void:
	tempo_s = 0.0
	tempos_por_fase.clear()
	abates_por_tipo.clear()
	dano_causado = 0.0
	dano_tomado = 0.0
	maior_sequencia_abates = 0
	acertos_quiz = 0
	finalizada = false
	vida_max_inicial_jogador = 0.0
	_sequencia_atual = 0
	_tempo_ultimo_abate_s = 0.0
	_tempo_fim_ultima_fase_s = 0.0


## Encerra a run: a partir daqui nada mais é contado.
static func finalizar() -> void:
	finalizada = true


## Cópia dos números brutos para o ScoreCalculator.
static func capturar() -> RunSnapshot:
	var s := RunSnapshot.new()
	s.tempo_s = tempo_s
	s.tempos_por_fase = tempos_por_fase.duplicate()
	s.abates_por_tipo = abates_por_tipo.duplicate()
	s.dano_causado = dano_causado
	s.dano_tomado = dano_tomado
	s.maior_sequencia_abates = maior_sequencia_abates
	s.acertos_quiz = acertos_quiz
	s.vida_max_inicial_jogador = vida_max_inicial_jogador
	return s


## Soma tempo de jogo.
static func somar_tempo(segundos: float) -> void:
	if finalizada:
		return
	tempo_s += maxf(segundos, 0.0)


## Registra um abate. A sequência continua se o abate anterior foi há no máximo `janela_s`
## segundos de tempo de jogo (nunca relógio real); senão recomeça em 1.
static func registrar_abate(tipo: StringName, janela_s: float) -> void:
	if finalizada:
		return
	abates_por_tipo[tipo] = int(abates_por_tipo.get(tipo, 0)) + 1
	if _sequencia_atual > 0 and tempo_s - _tempo_ultimo_abate_s <= janela_s:
		_sequencia_atual += 1
	else:
		_sequencia_atual = 1
	_tempo_ultimo_abate_s = tempo_s
	maior_sequencia_abates = maxi(maior_sequencia_abates, _sequencia_atual)


## Soma dano causado a um inimigo (valor já efetivo).
static func registrar_dano_causado(quantidade: float) -> void:
	if not finalizada and quantidade > 0.0:
		dano_causado += quantidade


## Soma dano aplicado ao jogador.
static func registrar_dano_tomado(quantidade: float) -> void:
	if not finalizada and quantidade > 0.0:
		dano_tomado += quantidade


## Registra um acerto de primeira no quiz.
static func registrar_acerto_quiz() -> void:
	if not finalizada:
		acertos_quiz += 1


## Fase concluída: empilha o tempo gasto desde a fase anterior (inclui tentativas perdidas).
static func registrar_fim_de_fase() -> void:
	if finalizada:
		return
	tempos_por_fase.append(tempo_s - _tempo_fim_ultima_fase_s)
	_tempo_fim_ultima_fase_s = tempo_s
