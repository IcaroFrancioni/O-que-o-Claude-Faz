class_name RunState
extends RefCounted
## Estado da run (nível, XP e habilidades). Sobrevive à troca de fase sem precisar de autoload.
## Zera ao entrar na primeira fase e, ao reiniciar uma fase, volta ao estado do início dela.

## Entrar nesta cena começa uma run nova.
const FIRST_LEVEL_SCENE: String = "res://Scenes/Fase1/fase_1.tscn"

## Nível atual (0 a 3).
static var level: int = 0
## XP acumulado (para de crescer no nível máximo).
static var xp: int = 0
## Maior nível cujo menu de escolha já foi resolvido (níveis acima disso estão pendentes).
static var resolved_level: int = 0
## Ids das habilidades que o jogador possui.
static var owned_ids: Array[StringName] = []
## Ids das habilidades rejeitadas (nunca mais aparecem nesta run).
static var rejected_ids: Array[StringName] = []
## True depois que o jogador abriu o modo comando pela primeira vez (a dica na tela some).
static var command_hint_seen: bool = false
## True depois que o jogador usou o único reroll da run no menu de escolha de habilidade.
static var reroll_used: bool = false

static var _checkpoint: Dictionary = {}
static var _restart_pending: bool = false
static var _last_begin_frame: int = -1


## Zera tudo (run nova).
static func reset() -> void:
	level = 0
	xp = 0
	resolved_level = 0
	owned_ids.clear()
	rejected_ids.clear()
	command_hint_seen = false
	reroll_used = false
	RunStats.reset()


## Chamado pelos componentes do Player ao nascer numa fase (só o primeiro chamado no frame age).
static func begin_scene(scene_path: String) -> void:
	var frame: int = Engine.get_process_frames()
	if frame == _last_begin_frame:
		return
	_last_begin_frame = frame
	if _restart_pending and not _checkpoint.is_empty():
		_restore_checkpoint()
	elif scene_path == FIRST_LEVEL_SCENE or _checkpoint.is_empty():
		reset()
	_restart_pending = false
	_save_checkpoint()


## A fase vai ser reiniciada (game over, "Tentar de novo" ou Reset da pausa): na próxima fase
## o estado volta ao do início da fase que acabou de ser jogada.
static func mark_restart() -> void:
	_restart_pending = true


## Marca um nível como resolvido (o menu dele já foi respondido).
static func resolve_level(novo_nivel: int) -> void:
	resolved_level = maxi(resolved_level, novo_nivel)


## Marca habilidades como rejeitadas.
static func reject(ids: Array[StringName]) -> void:
	for ability_id: StringName in ids:
		if not rejected_ids.has(ability_id):
			rejected_ids.append(ability_id)


## Ids que não podem mais ser sorteados (possuídas + rejeitadas).
static func excluded_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.append_array(owned_ids)
	result.append_array(rejected_ids)
	return result


static func _save_checkpoint() -> void:
	_checkpoint = {
		"level": level,
		"xp": xp,
		"resolved": resolved_level,
		"owned": owned_ids.duplicate(),
		"rejected": rejected_ids.duplicate(),
		"reroll_used": reroll_used,
	}


static func _restore_checkpoint() -> void:
	level = int(_checkpoint["level"])
	xp = int(_checkpoint["xp"])
	resolved_level = int(_checkpoint["resolved"])
	owned_ids.assign(_checkpoint["owned"])
	rejected_ids.assign(_checkpoint["rejected"])
	reroll_used = bool(_checkpoint.get("reroll_used", false))
