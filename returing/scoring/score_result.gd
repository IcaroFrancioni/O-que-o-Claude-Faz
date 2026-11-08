class_name ScoreResult
extends RefCounted
## Resultado do cálculo: cada linha da tela final, o total e o rank.

const RANK_S: StringName = &"S"
const RANK_A: StringName = &"A"
const RANK_B: StringName = &"B"
const RANK_C: StringName = &"C"
const RANK_D: StringName = &"D"

## Nome de cada rank (único lugar).
const RANK_NOMES: Dictionary = {
	&"S": "LENDÁRIA",
	&"A": "EXCELENTE",
	&"B": "BOA",
	&"C": "REGULAR",
	&"D": "FRACA",
}
## Cor de cada rank (único lugar).
const RANK_CORES: Dictionary = {
	&"S": Color("#e8c15a"),
	&"A": Color("#7fd36b"),
	&"B": Color("#6fb1d6"),
	&"C": Color("#b9b9b9"),
	&"D": Color("#c0584f"),
}


## Uma linha da tela final: rótulo, valor bruto e pontos.
class Linha extends RefCounted:
	var id: StringName = &""
	var rotulo: String = ""
	## Valor bruto (segundos, quantidade, dano, nº de tipos...).
	var valor: float = 0.0
	var pontos: int = 0
	## Só nas linhas de inimigo: o tipo.
	var tipo: StringName = &""


	func _init(p_id: StringName, p_rotulo: String, p_valor: float, p_pontos: int, p_tipo: StringName = &"") -> void:
		id = p_id
		rotulo = p_rotulo
		valor = p_valor
		pontos = p_pontos
		tipo = p_tipo


var pontos_tempo: int = 0
var pontos_abates: int = 0
var pontos_variedade: int = 0
var pontos_combo: int = 0
var pontos_dano: int = 0
var pontos_quiz: int = 0
var bruto: int = 0
var penalidade: int = 0
var barras_perdidas: float = 0.0
var total: int = 0
var rank: StringName = RANK_D

var linha_tempo: Linha = null
## Uma linha por tipo abatido (ordem decrescente de pontos).
var linhas_inimigos: Array[Linha] = []
var linha_variedade: Linha = null
var linha_combo: Linha = null
var linha_dano: Linha = null
## Null quando o quiz está desligado no ScoreConfig.
var linha_quiz: Linha = null

## Tempos por fase (cópia, para as parciais).
var tempos_por_fase: Array[float] = []


func nome_do_rank() -> String:
	return RANK_NOMES[rank]


func cor_do_rank() -> Color:
	return RANK_CORES[rank]
