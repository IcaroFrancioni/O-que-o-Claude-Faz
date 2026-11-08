class_name ScoreCalculator
extends RefCounted
## Cálculo da pontuação. Funções estáticas e puras: só leem o RunSnapshot e o ScoreConfig, sem
## aleatoriedade, hora do sistema, UI nem cena. Cada componente é arredondado (roundi) e depois somado.

## Rótulos das linhas (a tela final usa os mesmos).
const ROTULO_TEMPO: String = "TEMPO DE JOGO"
const ROTULO_VARIEDADE: String = "VARIEDADE"
const ROTULO_COMBO: String = "MAIOR COMBO"
const ROTULO_DANO: String = "DANO CAUSADO"
const ROTULO_QUIZ: String = "QUIZ"
## Evita divisão por zero quando nada informa a vida.
const VIDA_MINIMA: float = 1.0


## Calcula tudo a partir dos números brutos da run.
static func calcular(run: RunSnapshot, config: ScoreConfig) -> ScoreResult:
	var r := ScoreResult.new()
	var fraco: float = vida_do_mais_fraco(config)

	r.pontos_tempo = pontos_de_tempo(run.tempo_s, config)
	r.linha_tempo = ScoreResult.Linha.new(&"tempo", ROTULO_TEMPO, run.tempo_s, r.pontos_tempo)

	var tipos_distintos: int = 0
	for tipo: StringName in run.abates_por_tipo:
		var qtd: int = int(run.abates_por_tipo[tipo])
		if qtd <= 0:
			continue
		tipos_distintos += 1
		var pontos: int = qtd * peso_do_tipo(tipo, config)
		r.pontos_abates += pontos
		r.linhas_inimigos.append(ScoreResult.Linha.new(&"abates", nome_do_tipo(tipo, config), float(qtd), pontos, tipo))
	r.linhas_inimigos.sort_custom(_por_pontos_decrescente)

	r.pontos_variedade = config.pontos_por_tipo_distinto * tipos_distintos
	r.linha_variedade = ScoreResult.Linha.new(&"variedade", ROTULO_VARIEDADE, float(tipos_distintos), r.pontos_variedade)

	r.pontos_combo = pontos_de_combo(run.maior_sequencia_abates, config)
	r.linha_combo = ScoreResult.Linha.new(&"combo", ROTULO_COMBO, float(run.maior_sequencia_abates), r.pontos_combo)

	r.pontos_dano = roundi(float(config.pontos_por_vida_base_causada) * run.dano_causado / fraco)
	r.linha_dano = ScoreResult.Linha.new(&"dano", ROTULO_DANO, run.dano_causado, r.pontos_dano)

	if config.quiz_ativo:
		r.pontos_quiz = config.pontos_por_acerto * run.acertos_quiz
		r.linha_quiz = ScoreResult.Linha.new(&"quiz", ROTULO_QUIZ, float(run.acertos_quiz), r.pontos_quiz)

	r.bruto = r.pontos_tempo + r.pontos_abates + r.pontos_variedade + r.pontos_combo + r.pontos_dano + r.pontos_quiz
	r.barras_perdidas = run.dano_tomado / maxf(run.vida_max_inicial_jogador, VIDA_MINIMA)
	r.penalidade = roundi(minf(config.teto_penalidade_pct * float(r.bruto),
			float(config.penalidade_por_barra) * r.barras_perdidas))
	r.total = maxi(0, r.bruto - r.penalidade)
	r.rank = rank_do_total(r.total, config)
	r.tempos_por_fase = run.tempos_por_fase.duplicate()
	return r


## Tempo par da run inteira (s).
static func tempo_par_s(config: ScoreConfig) -> float:
	return config.tempo_par_por_fase_s * float(config.numero_de_fases)


## Tempo a partir do qual os pontos de tempo valem 0 (s).
static func tempo_limite_s(config: ScoreConfig) -> float:
	return config.multiplicador_limite * tempo_par_s(config)


## Pontos de tempo: máximo até o tempo par, 0 a partir do limite, linear no meio.
static func pontos_de_tempo(tempo_s: float, config: ScoreConfig) -> int:
	var par: float = tempo_par_s(config)
	var limite: float = tempo_limite_s(config)
	var faixa: float = limite - par
	if faixa <= 0.0:  # configuração inválida: sem rampa
		return config.pontos_tempo_max if tempo_s <= par else 0
	return roundi(float(config.pontos_tempo_max) * clampf((limite - tempo_s) / faixa, 0.0, 1.0))


## Bônus da maior sequência de abates.
static func pontos_de_combo(maior_sequencia: int, config: ScoreConfig) -> int:
	if maior_sequencia < config.combo_minimo:
		return 0
	return mini(config.pontos_por_abate_acima_de_2 * (maior_sequencia - config.abates_sem_bonus_combo), config.teto_combo)


## Vida do tipo comum mais fraco (chefes não entram).
static func vida_do_mais_fraco(config: ScoreConfig) -> float:
	var menor: float = INF
	for tipo: StringName in config.vida_max_por_tipo:
		if config.tipos_chefe.has(tipo):
			continue
		menor = minf(menor, float(config.vida_max_por_tipo[tipo]))
	return VIDA_MINIMA if is_inf(menor) else maxf(menor, VIDA_MINIMA)


## Peso de um abate: `peso_por_tipo`, depois chefe, depois a faixa pela razão de vida.
static func peso_do_tipo(tipo: StringName, config: ScoreConfig) -> int:
	if config.peso_por_tipo.has(tipo):
		return config.peso_por_tipo[tipo]
	if config.tipos_chefe.has(tipo):
		return config.peso_chefe
	if not config.vida_max_por_tipo.has(tipo):
		return config.peso_faixa_1  # tipo desconhecido: faixa mais baixa
	var razao: float = float(config.vida_max_por_tipo[tipo]) / vida_do_mais_fraco(config)
	var pesos: Array[int] = [config.peso_faixa_1, config.peso_faixa_2, config.peso_faixa_3, config.peso_faixa_4]
	var faixa: int = 0
	for limite: float in config.limites_razao_vida:  # cada limite alcançado sobe uma faixa
		if razao >= limite:
			faixa += 1
	return pesos[mini(faixa, pesos.size() - 1)]


## Nome exibido do tipo.
static func nome_do_tipo(tipo: StringName, config: ScoreConfig) -> String:
	return config.nomes_por_tipo.get(tipo, String(tipo).to_upper())


## Rank de um total.
static func rank_do_total(total: int, config: ScoreConfig) -> StringName:
	if total >= config.limite_s:
		return ScoreResult.RANK_S
	if total >= config.limite_a:
		return ScoreResult.RANK_A
	if total >= config.limite_b:
		return ScoreResult.RANK_B
	if total >= config.limite_c:
		return ScoreResult.RANK_C
	return ScoreResult.RANK_D


static func _por_pontos_decrescente(a: ScoreResult.Linha, b: ScoreResult.Linha) -> bool:
	if a.pontos != b.pontos:
		return a.pontos > b.pontos
	return String(a.tipo) < String(b.tipo)  # desempate estável
