class_name RunSnapshot
extends RefCounted
## Cópia imutável dos números brutos da run. O ScoreCalculator só lê isto (e o ScoreConfig),
## o que o mantém puro e testável com qualquer combinação de valores.

var tempo_s: float = 0.0
var tempos_por_fase: Array[float] = []
var abates_por_tipo: Dictionary = {}
var dano_causado: float = 0.0
var dano_tomado: float = 0.0
var maior_sequencia_abates: int = 0
var acertos_quiz: int = 0
var vida_max_inicial_jogador: float = 0.0
