class_name HighScoreStore
extends RefCounted
## Recordes locais (só neste computador): melhor total, o rank dele e o melhor tempo.
## Arquivo ausente ou corrompido vale "sem recorde", sem erro.

const ARQUIVO: String = "user://returing_recordes.cfg"
const SECAO: String = "recorde"
const CHAVE_TOTAL: String = "melhor_total"
const CHAVE_RANK: String = "rank"
const CHAVE_TEMPO: String = "melhor_tempo_s"

## Caminho em uso (os testes trocam por um arquivo temporário).
static var caminho: String = ARQUIVO


## Recorde salvo: `{total: int, rank: StringName, tempo_s: float}`, ou `{}` se não houver/estiver inválido.
static func carregar() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(caminho) != OK:
		return {}
	for chave: String in [CHAVE_TOTAL, CHAVE_RANK, CHAVE_TEMPO]:
		if not cfg.has_section_key(SECAO, chave):
			return {}
	var total: Variant = cfg.get_value(SECAO, CHAVE_TOTAL)
	var rank: Variant = cfg.get_value(SECAO, CHAVE_RANK)
	var tempo: Variant = cfg.get_value(SECAO, CHAVE_TEMPO)
	if typeof(total) != TYPE_INT or typeof(rank) != TYPE_STRING or not (typeof(tempo) == TYPE_FLOAT or typeof(tempo) == TYPE_INT):
		return {}
	if not ScoreResult.RANK_NOMES.has(StringName(rank)) or int(total) < 0 or float(tempo) < 0.0:
		return {}
	return {"total": int(total), "rank": StringName(rank), "tempo_s": float(tempo)}


## Compara a run com o recorde, salva o que melhorou e devolve
## `{novo_recorde: bool, anterior: Dictionary, atual: Dictionary}`.
## O melhor total e o melhor tempo são independentes; sem recorde anterior, a run cria um.
static func registrar(total: int, rank: StringName, tempo_s: float) -> Dictionary:
	var anterior: Dictionary = carregar()
	var novo_recorde: bool = anterior.is_empty() or total > int(anterior["total"])
	var atual: Dictionary = anterior.duplicate()
	if novo_recorde:
		atual["total"] = total
		atual["rank"] = rank
	if anterior.is_empty() or tempo_s < float(anterior["tempo_s"]):
		atual["tempo_s"] = tempo_s
	if atual != anterior:
		_salvar(atual)
	return {"novo_recorde": novo_recorde, "anterior": anterior, "atual": atual}


static func _salvar(dados: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECAO, CHAVE_TOTAL, int(dados["total"]))
	cfg.set_value(SECAO, CHAVE_RANK, String(dados["rank"]))
	cfg.set_value(SECAO, CHAVE_TEMPO, float(dados["tempo_s"]))
	var erro: Error = cfg.save(caminho)
	if erro != OK:
		push_warning("HighScoreStore: não foi possível salvar '%s' (erro %d)." % [caminho, erro])
