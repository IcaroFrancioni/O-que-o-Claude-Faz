extends Node
## Testes das 9 habilidades novas e dos ajustes nas habilidades existentes.
##   godot --headless --path . res://tests/habilidades_test.tscn
## A cena precisa dos autoloads. O Player é o `Turing.tscn` solto, sem fase.

const CATALOG_PATH: String = "res://abilities/data/ability_catalog.tres"
const DATA_DIR: String = "res://abilities/data/"
const FX_DIR: String = "res://abilities/effects/"
## Habilidades novas: id -> [sequência, raridade].
const NOVAS: Dictionary = {
	&"reflexos": [[0, 2, 0], AbilityData.Rarity.COMUM],
	&"carga_rapida": [[1, 0, 1], AbilityData.Rarity.COMUM],
	&"pele_de_ferro": [[3, 1, 3], AbilityData.Rarity.COMUM],
	&"pulso_gelido": [[2, 2, 0, 3], AbilityData.Rarity.AVANCADA],
	&"mina_binaria": [[3, 1, 1, 2], AbilityData.Rarity.AVANCADA],
	&"drone_aliado": [[0, 0, 3, 2], AbilityData.Rarity.AVANCADA],
	&"tiro_em_leque": [[3, 3, 1, 2], AbilityData.Rarity.AVANCADA],
	&"maquina_enigma": [[2, 0, 2, 0, 1, 1], AbilityData.Rarity.LENDARIA],
	&"overclock": [[0, 3, 0, 3, 1, 2], AbilityData.Rarity.LENDARIA],
}

var _falhas: int = 0
var _total: int = 0
var _player: Player = null
var _ab: AbilityComponent = null
## Pode conter inimigos já liberados: sempre checar `is_instance_valid`.
var _inimigos: Array = []
## Cada seção liga isto na última linha; se um erro de script abortar a seção, fica falso.
var _fim_secao: bool = false


func _ready() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	_secao("Catálogo e dados")
	await _executar("catalogo", _testar_catalogo)
	await _nova_cena()
	_secao("Buffs de atributo")
	await _executar("buffs", _testar_buffs)
	await _executar("consumo_no_player", _testar_consumo_no_player)
	_secao("Lentidão (Pulso Gélido e Máquina Enigma)")
	await _executar("pulso_gelido", _testar_pulso_gelido)
	await _executar("enigma", _testar_enigma)
	await _executar("lentidao_combinada", _testar_lentidao_combinada)
	_secao("Mina Binária")
	await _executar("mina", _testar_mina)
	_secao("Drone Aliado")
	await _executar("drone", _testar_drone)
	_secao("Tiro em Leque")
	await _executar("leque", _testar_leque)
	_secao("Pausa")
	await _executar("pausa", _testar_pausa)
	_secao("Saídas do efeito (morte e saída da cena)")
	await _executar("saidas", _testar_saidas)
	_secao("Ajustes nas habilidades existentes")
	await _executar("escudo", _testar_escudo)
	await _executar("emp_preview", _testar_emp_preview)
	await _executar("rastro_de_fogo", _testar_rastro_de_fogo)
	await _executar("perfurante", _testar_perfurante)
	await _executar("cura", _testar_cura)
	_secao("Reroll das lendárias")
	await _executar("reroll", _testar_reroll)
	_secao("HUD das habilidades novas")
	await _executar("hud_slots", _testar_hud_slots)
	await _executar("hud_cartas", _testar_hud_cartas)
	await _executar("demo", _testar_demo)
	await _limpar()
	print("habilidades_test: %d verificações, %d falhas" % [_total, _falhas])
	get_tree().quit(1 if _falhas > 0 else 0)


# --- Utilidades ---

## Roda uma seção e confere que ela chegou ao fim (um erro de script a aborta no meio).
func _executar(nome: String, secao: Callable) -> void:
	_fim_secao = false
	await secao.call()
	_confere(_fim_secao, "a seção '%s' rodou até o fim, sem erro de script" % nome)


func _secao(titulo: String) -> void:
	print("-- ", titulo)


func _confere(condicao: bool, nome: String) -> void:
	_total += 1
	if not condicao:
		_falhas += 1
		printerr("FALHOU: ", nome)


func _perto(a: float, b: float, margem: float = 0.001) -> bool:
	return absf(a - b) <= margem


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _dados(id: StringName) -> AbilityData:
	return load(DATA_DIR + String(id) + ".tres") as AbilityData


## Cópia dos dados com a duração trocada (para o teste não esperar os 10 s reais).
func _dados_curtos(id: StringName, duracao: float, penalidade: float = -1.0) -> AbilityData:
	var copia: AbilityData = _dados(id).duplicate() as AbilityData
	copia.duration = duracao
	if penalidade >= 0.0:
		copia.penalty_duration = penalidade
	return copia


## Limpa a cena de teste e cria um Player novo (sem habilidades) no centro.
func _nova_cena() -> void:
	await _limpar()
	RunState.reset()
	_player = (load("res://characters/turing/Turing.tscn") as PackedScene).instantiate() as Player
	add_child(_player)
	_player.global_position = Vector2.ZERO
	await _frames(4)
	_ab = _player.abilities
	_ab.abilities.clear()


func _limpar() -> void:
	for inimigo: Variant in _inimigos:
		if is_instance_valid(inimigo):
			(inimigo as EnemyBase).queue_free()
	_inimigos.clear()
	if is_instance_valid(_player):
		_player.queue_free()
	_player = null
	_ab = null
	get_tree().paused = false
	Engine.time_scale = 1.0
	await _frames(3)


## Inimigo parado (IA desligada) na posição pedida. `tipo` &"guide" faz o efeito tratá-lo como chefão.
func _novo_inimigo(pos: Vector2, tipo: StringName = &"tank") -> EnemyBase:
	var inimigo: EnemyBase = (load("res://enemies/tank/TankEnemy.tscn") as PackedScene).instantiate() as EnemyBase
	inimigo.enemy_kind = tipo
	add_child(inimigo)
	inimigo.global_position = pos
	inimigo.set_physics_process(false)
	inimigo.state_machine.process_mode = Node.PROCESS_MODE_DISABLED
	_inimigos.append(inimigo)
	return inimigo


## Instancia um efeito como o AbilityComponent faz, mas deixando ajustar propriedades antes de ligar.
func _efeito(cena: String, dados: AbilityData, props: Dictionary = {}) -> AbilityEffect:
	var efeito: AbilityEffect = (load(FX_DIR + cena) as PackedScene).instantiate() as AbilityEffect
	for chave: Variant in props:
		efeito.set(StringName(chave), props[chave])
	efeito.data = dados
	_ab._effects.append(efeito)
	_player.add_child(efeito)
	efeito.activate(_player)
	return efeito


func _mult(atributo: StringName) -> float:
	return _ab.stats.get_mult(atributo)


# --- Catálogo ---

func _testar_catalogo() -> void:
	var catalogo: AbilityCatalog = load(CATALOG_PATH) as AbilityCatalog
	_confere(catalogo != null, "o catálogo carrega")
	var lista: Array[AbilityData] = catalogo.abilities
	_confere(lista.size() == 21, "o catálogo tem 21 habilidades (12 antigas + 9 novas): %d" % lista.size())
	_confere(AbilityData.validate(lista), "AbilityData.validate aceita o catálogo (sem sequência repetida nem prefixo)")

	# Conferência independente do validador: nenhuma sequência é igual ou prefixo de outra.
	var colisoes: int = 0
	for i: int in lista.size():
		for j: int in lista.size():
			if i == j:
				continue
			var a: Array[int] = lista[i].sequence
			var b: Array[int] = lista[j].sequence
			if a.size() <= b.size() and b.slice(0, a.size()) == a:
				colisoes += 1
				printerr("  colisão: ", lista[i].id, " é início de ", lista[j].id)
	_confere(colisoes == 0, "nenhuma sequência é prefixo de outra (nem repetida): %d colisões" % colisoes)

	var ids: Dictionary = {}
	for dado: AbilityData in lista:
		ids[dado.id] = true
		var tamanho: int = dado.sequence.size()
		_confere(not dado.display_name.is_empty(), "%s tem nome" % dado.id)
		_confere(not dado.description.is_empty(), "%s tem descrição" % dado.id)
		_confere(tamanho >= 3 and tamanho <= 6, "%s tem de 3 a 6 setas" % dado.id)
		_confere(dado.icon != null or dado.glyph != AbilityData.Glyph.NONE, "%s tem ícone (PNG ou glifo)" % dado.id)
		_confere(dado.effect_scene != null, "%s tem cena de efeito" % dado.id)
		_confere(dado.cooldown > dado.duration, "%s: recarga maior que a duração" % dado.id)
		if dado.icon != null:
			_confere(ResourceLoader.exists(dado.icon.resource_path), "o ícone de %s existe no disco" % dado.id)

	for id: StringName in NOVAS:
		var dado: AbilityData = _dados(id)
		_confere(dado != null and ids.has(id), "%s está no catálogo" % id)
		if dado == null:
			continue
		var esperado: Array = NOVAS[id]
		_confere(dado.sequence == Array(esperado[0], TYPE_INT, &"", null), "%s: sequência da tabela" % id)
		_confere(dado.rarity == esperado[1], "%s: raridade da tabela" % id)
		var tamanho_esperado: int = 3 if dado.rarity == AbilityData.Rarity.COMUM \
				else (4 if dado.rarity == AbilityData.Rarity.AVANCADA else 6)
		_confere(dado.sequence.size() == tamanho_esperado, "%s: %d setas para a raridade" % [id, tamanho_esperado])
		_confere(dado.icon != null, "%s tem ícone PNG" % id)
		if dado.icon != null:
			var textura: Texture2D = dado.icon
			_confere(textura.get_width() == textura.get_height() and textura.get_width() >= 32, "%s: ícone quadrado de pelo menos 32 px" % id)
	_fim_secao = true


# --- Buffs ---

func _testar_buffs() -> void:
	# Reflexos, Carga Rápida e Pele de Ferro: StatBuffEffect.
	var casos: Array[Array] = [
		[&"reflexos", StatModifiers.DASH_COOLDOWN, 0.6],
		[&"carga_rapida", StatModifiers.CHARGE_TIME, 0.7],
		[&"pele_de_ferro", StatModifiers.DAMAGE_TAKEN, 0.8],
	]
	for caso: Array in casos:
		var id: StringName = caso[0]
		var atributo: StringName = caso[1]
		_confere(_mult(atributo) == 1.0, "%s: atributo começa em 1.0" % id)
		_ab._activate(_dados_curtos(id, 0.5))
		_confere(_perto(_mult(atributo), float(caso[2])), "%s: bônus aplicado (%.2f)" % [id, float(caso[2])])
		await _frames(45)
		_confere(_mult(atributo) == 1.0, "%s: atributo volta EXATAMENTE a 1.0 ao fim do tempo" % id)

	# Reativar renova a duração e não acumula.
	var reflexos: AbilityData = _dados_curtos(&"reflexos", 1.0)
	_ab._activate(reflexos)
	await _frames(40)
	_ab._activate(reflexos)
	_confere(_perto(_mult(StatModifiers.DASH_COOLDOWN), 0.6), "reativar Reflexos não acumula (0.6 e não 0.36)")
	await _frames(40)  # 0,67 s depois da 2ª ativação: um efeito sem renovação já teria acabado aos 1,0 s
	_confere(_perto(_mult(StatModifiers.DASH_COOLDOWN), 0.6), "reativar Reflexos renova a duração (ainda ativo)")
	await _frames(40)
	_confere(_mult(StatModifiers.DASH_COOLDOWN) == 1.0, "Reflexos renovado termina e devolve 1.0")

	# Buffs diferentes multiplicam entre si (e com os que já existem).
	_ab._activate(_dados_curtos(&"pele_de_ferro", 0.5))
	_ab._activate(_dados_curtos(&"passo_agil", 0.5))
	_confere(_perto(_mult(StatModifiers.DAMAGE_TAKEN), 0.8) and _perto(_mult(StatModifiers.MOVE_SPEED), 1.1),
			"buffs diferentes convivem")
	await _frames(45)

	# Overclock: dois estágios.
	var overclock: AbilityData = _dados_curtos(&"overclock", 1.0, 0.5)
	_ab._activate(overclock)
	_confere(_perto(_mult(StatModifiers.DAMAGE), 1.5) and _perto(_mult(StatModifiers.MOVE_SPEED), 1.3),
			"Overclock: +50% de dano e +30% de velocidade")
	await _frames(15)  # 0,25 s: ainda no bônus
	_confere(_perto(_mult(StatModifiers.DAMAGE), 1.5), "Overclock: continua no bônus antes da penalidade")
	await _frames(35)  # 0,83 s: na penalidade
	_confere(_perto(_mult(StatModifiers.DAMAGE), 0.8) and _perto(_mult(StatModifiers.MOVE_SPEED), 0.8),
			"Overclock: depois vira -20% de dano e de velocidade")
	_confere(_player.weapon.damage == roundi(float(_player.sword_damage) * 0.8), "Overclock: o dano da espada acompanha")
	await _frames(30)
	_confere(_mult(StatModifiers.DAMAGE) == 1.0 and _mult(StatModifiers.MOVE_SPEED) == 1.0,
			"Overclock: devolve EXATAMENTE 1.0 ao terminar")
	_confere(_player.weapon.damage == _player.sword_damage, "Overclock: o dano da espada volta ao normal")
	var real: AbilityData = _dados(&"overclock")
	_confere(real.duration == 15.0 and real.penalty_duration == 5.0, "Overclock real: 10 s de bônus + 5 s de penalidade")
	_confere(real.is_penalty_at(10.0) and not real.is_penalty_at(9.9) and not real.is_penalty_at(15.0),
			"AbilityData.is_penalty_at marca só os 5 s finais")


	_fim_secao = true
## Os atributos novos chegam ao Player.
func _testar_consumo_no_player() -> void:
	_ab._activate(_dados_curtos(&"reflexos", 5.0))
	_player.change_state(Player.State.DASH)
	_player.change_state(Player.State.IDLE)
	_confere(_perto(_player._dash_cooldown_left, _player.dash_cooldown * 0.6),
			"Reflexos: a recarga do dash fica 40%% menor (%.2f s)" % _player._dash_cooldown_left)
	_ab._cancel_all_effects()
	_confere(_perto(_player._tempo_de_carga(), _player.charge_time), "sem Carga Rápida: tempo de carga normal")
	_ab._activate(_dados_curtos(&"carga_rapida", 5.0))
	_confere(_perto(_player._tempo_de_carga(), _player.charge_time * 0.7), "Carga Rápida: tempo de carga -30%")
	_ab._cancel_all_effects()
	var vida: int = _player.hp
	_player._iframes_left = 0.0  # o dash acima deu invulnerabilidade
	_ab._activate(_dados_curtos(&"pele_de_ferro", 5.0))
	_player.tomar_dano(10)
	_confere(vida - _player.hp == 8, "Pele de Ferro: 10 de dano viram 8 (perdeu %d)" % (vida - _player.hp))
	_ab._cancel_all_effects()
	_player._iframes_left = 0.0
	vida = _player.hp
	_player.tomar_dano(10)
	_confere(vida - _player.hp == 10, "sem Pele de Ferro: dano normal")
	_player.hp = _player.hp_maximo
	_fim_secao = true


# --- Lentidão ---

func _testar_pulso_gelido() -> void:
	var perto: EnemyBase = _novo_inimigo(Vector2(80, 0))
	var longe: EnemyBase = _novo_inimigo(Vector2(400, 0))
	var chefe: EnemyBase = _novo_inimigo(Vector2(60, 60), &"guide")
	var base_perto: float = perto.move_speed
	var base_chefe: float = chefe.move_speed
	await _frames(2)
	_ab._activate(_dados_curtos(&"pulso_gelido", 0.6))
	_confere(_perto(perto.move_speed, base_perto * 0.5), "Pulso Gélido: inimigo no raio fica 50%% mais lento (%.1f -> %.1f)" % [base_perto, perto.move_speed])
	_confere(longe.move_speed == base_perto, "Pulso Gélido: inimigo fora do raio não muda")
	_confere(chefe.move_speed == base_chefe, "Pulso Gélido: chefão é imune (regra do Pulso EMP)")
	await _frames(50)
	_confere(perto.move_speed == base_perto, "Pulso Gélido: a velocidade volta EXATAMENTE ao valor original")
	_confere(not EnemySlow.is_slowed(perto), "Pulso Gélido: sem lentidão depois do fim")
	for inimigo: EnemyBase in [perto, longe, chefe]:
		inimigo.queue_free()
	_inimigos.clear()
	await _frames(2)

	# Inimigo que morre (é liberado) durante o efeito não quebra o fim do efeito.
	var morre: EnemyBase = _novo_inimigo(Vector2(50, 0))
	await _frames(2)
	_ab._activate(_dados_curtos(&"pulso_gelido", 0.4))
	morre.free()
	_inimigos.clear()
	await _frames(40)
	_confere(true, "Pulso Gélido: inimigo liberado no meio do efeito não gera erro")
	_fim_secao = true


func _testar_enigma() -> void:
	var comum: EnemyBase = _novo_inimigo(Vector2(600, 0))
	var chefe: EnemyBase = _novo_inimigo(Vector2(-600, 0), &"guide")
	var base_comum: float = comum.move_speed
	var base_chefe: float = chefe.move_speed
	await _frames(2)
	_ab._activate(_dados_curtos(&"maquina_enigma", 1.5))
	_confere(_perto(comum.move_speed, base_comum * 0.3), "Enigma: comum fica 70%% mais lento (%.1f -> %.1f)" % [base_comum, comum.move_speed])
	_confere(_perto(chefe.move_speed, base_chefe * 0.7), "Enigma: chefão fica 30%% mais lento (%.1f -> %.1f)" % [base_chefe, chefe.move_speed])
	var recem_nascido: EnemyBase = _novo_inimigo(Vector2(0, 700))
	var base_novo: float = recem_nascido.move_speed
	await _frames(40)  # a varredura (0,5 s) pega quem nasceu durante o efeito
	_confere(_perto(recem_nascido.move_speed, base_novo * 0.3), "Enigma: inimigo que nasce durante o efeito também fica lento")
	await _frames(70)
	_confere(comum.move_speed == base_comum and chefe.move_speed == base_chefe and recem_nascido.move_speed == base_novo,
			"Enigma: todas as velocidades voltam EXATAMENTE ao original")
	_confere(not EnemySlow.is_slowed(comum) and not EnemySlow.is_slowed(chefe), "Enigma: sem lentidão sobrando")
	for inimigo: EnemyBase in [comum, chefe, recem_nascido]:
		inimigo.queue_free()
	_inimigos.clear()
	await _frames(2)
	_fim_secao = true


func _testar_lentidao_combinada() -> void:
	var alvo: EnemyBase = _novo_inimigo(Vector2(70, 0))
	var base: float = alvo.move_speed
	await _frames(2)
	# Gélido (0,5) acaba antes da Enigma (0,3): vale a mais forte e, ao acabar, a outra continua.
	_ab._activate(_dados_curtos(&"maquina_enigma", 1.5))
	_ab._activate(_dados_curtos(&"pulso_gelido", 0.5))
	_confere(_perto(alvo.move_speed, base * 0.3), "lentidões combinadas: vale a mais forte (Enigma 0.3)")
	await _frames(45)
	_confere(_perto(alvo.move_speed, base * 0.3), "o Gélido acabou, a Enigma continua valendo")
	await _frames(60)
	_confere(alvo.move_speed == base, "as duas acabaram: velocidade original exata")
	# Enigma (0,3) acaba antes do Gélido (0,5): o Gélido continua.
	_ab._activate(_dados_curtos(&"pulso_gelido", 1.5))
	_ab._activate(_dados_curtos(&"maquina_enigma", 0.5))
	_confere(_perto(alvo.move_speed, base * 0.3), "ordem invertida: vale a mais forte")
	await _frames(45)
	_confere(_perto(alvo.move_speed, base * 0.5), "a Enigma acabou, o Gélido continua valendo (0.5)")
	await _frames(60)
	_confere(alvo.move_speed == base, "ordem invertida: velocidade original exata no fim")
	alvo.queue_free()
	_inimigos.clear()
	await _frames(2)
	_fim_secao = true


# --- Mina Binária ---

func _minas_ativas() -> Array[BinaryMine]:
	var lista: Array[BinaryMine] = []
	for no: Node in get_tree().get_nodes_in_group(BinaryMine.GROUP_MINES):
		if (no as BinaryMine).is_in_use():
			lista.append(no as BinaryMine)
	return lista


func _testar_mina() -> void:
	_ab.learn(_dados(&"mina_binaria"))
	var dados: AbilityData = _dados(&"mina_binaria")
	var longe: EnemyBase = _novo_inimigo(Vector2(300, 300))
	await _frames(2)
	_ab._activate(dados)
	await _frames(15)
	var minas: Array[BinaryMine] = _minas_ativas()
	_confere(minas.size() == 1, "Mina: uma mina plantada (%d)" % minas.size())
	if minas.size() != 1:
		return
	var mina: BinaryMine = minas[0]
	_confere(mina.global_position.distance_to(_player.global_position) < 30.0, "Mina: plantada nos pés do jogador")
	await _frames(60)
	_confere(mina.is_armed() and not mina.is_exploded(), "Mina: armada e esperando")
	_confere(longe.health.current_health == longe.health.max_health, "Mina: não explode sem inimigo por perto")

	# Primeiro inimigo que chega perto: explode e machuca todos do raio.
	var alvo: EnemyBase = _novo_inimigo(mina.global_position + Vector2(20, 0))
	var vizinho: EnemyBase = _novo_inimigo(mina.global_position + Vector2(-60, 0))
	await _frames(3)
	_confere(alvo.health.current_health == alvo.health.max_health - 70, "Mina: causou 70 de dano ao inimigo que chegou perto (%d)" % alvo.health.current_health)
	_confere(vizinho.health.current_health == vizinho.health.max_health - 70, "Mina: a explosão atinge o raio todo")
	_confere(longe.health.current_health == longe.health.max_health, "Mina: quem está fora do raio não leva dano")
	await _frames(25)
	_confere(not mina.is_in_use() and not mina.visible, "Mina: volta ao pool depois de explodir")
	_confere(not mina.is_in_group(BinaryMine.GROUP_MINES) and not mina.is_exploded() and mina.get_age() == 0.0,
			"Mina: estado limpo ao voltar ao pool")
	_confere(_minas_ativas().is_empty(), "Mina: nenhuma mina ativa sobrando")
	alvo.queue_free()
	vizinho.queue_free()
	longe.queue_free()
	_inimigos.clear()
	await _frames(2)

	# Some sozinha se ninguém chegar.
	_ab._cancel_all_effects()
	var curta: AbilityEffect = _efeito("BinaryMineEffect.tscn", dados, {"lifetime": 0.5})
	await _frames(45)
	_confere(_minas_ativas().is_empty(), "Mina: some sozinha ao fim do tempo de vida")
	_confere(not is_instance_valid(curta) or curta.is_queued_for_deletion() or curta._cleaned, "Mina: o efeito termina logo após plantar")

	# Limite de minas ao mesmo tempo (a mais antiga sai).
	for i: int in 4:
		_efeito("BinaryMineEffect.tscn", dados, {"max_mines": 2, "lifetime": 30.0})
		await _frames(20)
	_confere(_minas_ativas().size() == 2, "Mina: respeita o limite de minas ao mesmo tempo (%d)" % _minas_ativas().size())
	# Perder a habilidade (lendária apagando as outras) recolhe as minas.
	_ab.replace_all_with(_dados(&"overclock"))
	await _frames(5)
	_confere(_minas_ativas().is_empty(), "Mina: some quando o jogador perde a habilidade")
	_ab.abilities.clear()
	_fim_secao = true


# --- Drone Aliado ---

func _testar_drone() -> void:
	var alvo: EnemyBase = _novo_inimigo(Vector2(110, 0))
	await _frames(2)
	var vida: int = alvo.health.current_health
	var dados: AbilityData = _dados_curtos(&"drone_aliado", 2.0)
	_ab._activate(dados)
	await _frames(5)
	var drone: AllyDrone = _player.get_node_or_null("AllyDrone") as AllyDrone
	_confere(drone != null, "Drone: nasce como filho do jogador em tempo de execução")
	_confere(not (load("res://characters/turing/Turing.tscn") as PackedScene).instantiate().has_node("AllyDrone"),
			"Drone: o Turing.tscn não foi alterado")
	await _frames(60)
	if drone != null:
		_confere(_perto(drone.position.length(), 48.0, 0.5), "Drone: orbita a 48 px do jogador")
	_confere(alvo.health.current_health < vida, "Drone: atirou e machucou o inimigo (%d -> %d)" % [vida, alvo.health.current_health])
	await _frames(80)
	_confere(_player.get_node_or_null("AllyDrone") == null, "Drone: some ao fim da duração")
	var no_ar: int = 0
	for no: Node in get_tree().root.find_children("*", "PlayerProjectile", true, false):
		if (no as PlayerProjectile).is_in_use():
			no_ar += 1
	await _frames(70)
	for no: Node in get_tree().root.find_children("*", "PlayerProjectile", true, false):
		_confere(not (no as PlayerProjectile).is_in_use(), "Drone: tiros voltam ao pool")
		break
	alvo.queue_free()
	_inimigos.clear()
	await _frames(2)
	_fim_secao = true


# --- Tiro em Leque ---

func _testar_leque() -> void:
	_ab._activate(_dados(&"tiro_em_leque"))
	await _frames(12)
	var tiros: Array[PlayerProjectile] = []
	for no: Node in get_tree().root.find_children("*", "PlayerProjectile", true, false):
		var tiro: PlayerProjectile = no as PlayerProjectile
		if tiro.is_in_use() and tiro.shooter == _player and tiro.damage == 30:
			tiros.append(tiro)
	_confere(tiros.size() == 5, "Leque: 5 projéteis disparados (%d)" % tiros.size())
	if tiros.size() == 5:
		var angulos: Array[float] = []
		for tiro: PlayerProjectile in tiros:
			angulos.append(rad_to_deg(tiro.direction.angle()))
		angulos.sort()
		var abertura: float = angulos[4] - angulos[0]
		_confere(_perto(abertura, 40.0, 0.5), "Leque: arco de 40° (%.1f°)" % abertura)
		var regulares: bool = true
		for i: int in 4:
			regulares = regulares and _perto(angulos[i + 1] - angulos[i], 10.0, 0.5)
		_confere(regulares, "Leque: os 5 tiros são igualmente espaçados (10°)")
	await _frames(70)
	var sobrou: int = 0
	for no: Node in get_tree().root.find_children("*", "PlayerProjectile", true, false):
		if (no as PlayerProjectile).is_in_use():
			sobrou += 1
	_confere(sobrou == 0, "Leque: os tiros voltam ao pool (sobraram %d em uso)" % sobrou)
	_fim_secao = true


# --- Pausa ---

func _testar_pausa() -> void:
	var dados: AbilityData = _dados_curtos(&"reflexos", 5.0)
	_ab._activate(dados)
	var recarga: float = _ab.get_cooldown_left(dados.id)
	var efeito: StatBuffEffect = _ab._effects.back() as StatBuffEffect
	var restante: float = efeito._time_left
	get_tree().paused = true
	await _frames(30)
	_confere(_ab.get_cooldown_left(dados.id) == recarga, "Pausa: a recarga não avança")
	_confere(efeito._time_left == restante and _perto(_mult(StatModifiers.DASH_COOLDOWN), 0.6), "Pausa: a duração do buff não avança")
	get_tree().paused = false
	await _frames(30)
	_confere(_ab.get_cooldown_left(dados.id) < recarga and efeito._time_left < restante, "Fora da pausa: recarga e duração voltam a andar")
	_ab._cancel_all_effects()

	var mina_dados: AbilityData = _dados(&"mina_binaria")
	_ab.learn(mina_dados)
	_efeito("BinaryMineEffect.tscn", mina_dados, {"lifetime": 30.0})
	await _frames(10)
	var minas: Array[BinaryMine] = _minas_ativas()
	if not minas.is_empty():
		var idade: float = minas[0].get_age()
		get_tree().paused = true
		await _frames(30)
		_confere(minas[0].get_age() == idade, "Pausa: a vida da mina não avança")
		get_tree().paused = false
		await _frames(5)
		_confere(minas[0].get_age() > idade, "Fora da pausa: a mina volta a envelhecer")
		minas[0].recycle()
	var drone_dados: AbilityData = _dados_curtos(&"drone_aliado", 3.0)
	_ab._activate(drone_dados)
	await _frames(5)
	var drone: AllyDrone = _player.get_node_or_null("AllyDrone") as AllyDrone
	if drone != null:
		var angulo: Vector2 = drone.position
		var efeito_drone: DroneAllyEffect = _ab._effects.back() as DroneAllyEffect
		var tempo: float = efeito_drone._time_left
		get_tree().paused = true
		await _frames(30)
		_confere(drone.position == angulo and efeito_drone._time_left == tempo, "Pausa: o drone fica parado e a duração não avança")
		get_tree().paused = false
	_ab._cancel_all_effects()
	_ab.abilities.clear()
	await _frames(3)
	_fim_secao = true


# --- Saídas do efeito ---

## Cada efeito novo precisa desfazer tudo na morte do Player e na saída da cena (`_exit_tree`).
func _testar_saidas() -> void:
	await _nova_cena()
	var alvo: EnemyBase = _novo_inimigo(Vector2(60, 0))
	var base: float = alvo.move_speed
	await _frames(2)

	# Morte do Player: atributos e lentidão voltam.
	for id: StringName in [&"reflexos", &"carga_rapida", &"pele_de_ferro", &"overclock", &"pulso_gelido", &"maquina_enigma"]:
		_ab._activate(_dados_curtos(id, 20.0, 5.0 if id == &"overclock" else -1.0))
	_confere(_mult(StatModifiers.DASH_COOLDOWN) != 1.0 and alvo.move_speed != base, "efeitos ativos antes da morte")
	_player.tomar_dano(99999, true)
	await _frames(3)
	_confere(_player.esta_morto(), "o jogador morreu")
	for atributo: StringName in [StatModifiers.DASH_COOLDOWN, StatModifiers.CHARGE_TIME, StatModifiers.DAMAGE_TAKEN,
			StatModifiers.DAMAGE, StatModifiers.MOVE_SPEED]:
		_confere(_mult(atributo) == 1.0, "morte: %s volta a 1.0" % atributo)
	_confere(alvo.move_speed == base, "morte: a move_speed do inimigo volta EXATAMENTE ao original")
	_confere(not EnemySlow.is_slowed(alvo), "morte: nenhuma lentidão sobrando")

	# _exit_tree: o efeito sai da árvore sem terminar (troca de cena).
	await _nova_cena()
	alvo = _novo_inimigo(Vector2(60, 0))
	base = alvo.move_speed
	await _frames(2)
	var stats: StatModifiers = _ab.stats
	for id: StringName in [&"reflexos", &"carga_rapida", &"pele_de_ferro", &"overclock", &"pulso_gelido", &"maquina_enigma", &"drone_aliado"]:
		_ab._activate(_dados_curtos(id, 20.0, 5.0 if id == &"overclock" else -1.0))
	for efeito: AbilityEffect in _ab._effects.duplicate():
		efeito.get_parent().remove_child(efeito)  # dispara _exit_tree
		efeito.free()
	for atributo: StringName in [StatModifiers.DASH_COOLDOWN, StatModifiers.CHARGE_TIME, StatModifiers.DAMAGE_TAKEN,
			StatModifiers.DAMAGE, StatModifiers.MOVE_SPEED]:
		_confere(stats.get_mult(atributo) == 1.0, "_exit_tree: %s volta a 1.0" % atributo)
	_confere(alvo.move_speed == base, "_exit_tree: a move_speed do inimigo volta EXATAMENTE ao original")
	await _frames(3)
	_confere(_player.get_node_or_null("AllyDrone") == null, "_exit_tree: o drone some")
	_fim_secao = true


# --- Ajuste 2: Escudo ---

func _testar_escudo() -> void:
	await _nova_cena()
	var dados: AbilityData = _dados(&"escudo").duplicate() as AbilityData
	dados.duration = 0.5
	var efeito: ShieldEffect = _efeito("ShieldEffect.tscn", dados) as ShieldEffect
	_confere(_player.esta_invulneravel(), "Escudo: invulnerável enquanto dura")
	await _frames(20)
	_confere(not efeito.ended_naturally and efeito.get_node_or_null("EndSound") == null, "Escudo: sem som antes do fim")
	await _frames(20)
	_confere(efeito.ended_naturally, "Escudo: terminou sozinho")
	var som: AudioStreamPlayer = efeito.get_node_or_null("EndSound") as AudioStreamPlayer
	_confere(som != null and som.stream != null and som.bus == &"SFX", "Escudo: toca o som do fim no bus SFX")
	if som != null:
		var wav: AudioStreamWAV = som.stream as AudioStreamWAV
		_confere(wav != null and wav.data.size() > 1000 and wav.get_length() < 0.5, "Escudo: som curto gerado por código (%.2f s)" % wav.get_length())
	await _frames(30)
	_confere(not is_instance_valid(efeito), "Escudo: o efeito some depois do estalo")
	_confere(not _player.esta_invulneravel(), "Escudo: invulnerabilidade acabou")

	# Cortado por morte ou troca de cena: sem som.
	dados.duration = 5.0
	var cortado: ShieldEffect = _efeito("ShieldEffect.tscn", dados) as ShieldEffect
	await _frames(5)
	_ab._cancel_all_effects()
	_confere(not cortado.ended_naturally and cortado.get_node_or_null("EndSound") == null, "Escudo: cancelado não toca o som")
	_confere(not _player.esta_invulneravel(), "Escudo: cancelar tira a invulnerabilidade")
	var cena: ShieldEffect = _efeito("ShieldEffect.tscn", dados) as ShieldEffect
	cena.get_parent().remove_child(cena)  # troca de cena: _exit_tree
	_confere(not cena.ended_naturally and cena.get_node_or_null("EndSound") == null, "Escudo: saída da cena não toca o som")
	cena.free()
	_fim_secao = true


# --- Ajuste 3: círculo do Pulso EMP ---

func _testar_emp_preview() -> void:
	await _nova_cena()
	_ab.command_time_scale = 1.0
	var emp: AbilityData = _dados(&"pulso_emp")
	var previa: EmpRangePreview = _player.get_node_or_null("EmpRangePreview") as EmpRangePreview
	_confere(previa != null, "EMP: a prévia existe no Player")
	if previa == null:
		return
	_ab.learn(emp)
	await _frames(2)
	_confere(not previa.visible, "EMP: oculta com o modo fechado")
	_ab._open_command_mode()
	_confere(not previa.visible, "EMP: oculta com o modo aberto e nada digitado")
	_ab._on_arrow(AbilityData.Dir.DOWN)
	_confere(previa.visible, "EMP: aparece com o modo aberto, o EMP pronto e a sequência combinando")
	var raio_efeito: float = (load(FX_DIR + "EmpPulseEffect.tscn") as PackedScene).instantiate().get("radius")
	_confere(previa.get_radius() == raio_efeito and raio_efeito == EmpPulseEffect.DEFAULT_RADIUS,
			"EMP: o raio da prévia é o raio real do efeito (fonte única: %.0f)" % raio_efeito)
	_ab._on_arrow(AbilityData.Dir.UP)  # ↓↑ não combina: erro
	_confere(not previa.visible, "EMP: some ao errar")
	_ab._on_arrow(AbilityData.Dir.DOWN)
	_confere(previa.visible, "EMP: volta a aparecer quando a sequência combina de novo")
	_ab.close_command_mode()
	_confere(not previa.visible, "EMP: some ao fechar o modo")
	_ab._open_command_mode()
	for dir: int in [AbilityData.Dir.DOWN, AbilityData.Dir.RIGHT, AbilityData.Dir.UP, AbilityData.Dir.LEFT]:
		_ab._on_arrow(dir)
	_confere(previa.visible, "EMP: visível com a sequência completa, antes do Enter")
	_ab._confirm()
	_confere(not previa.visible and not _ab.command_active, "EMP: some ao ativar")
	var efeito_emp: EmpPulseEffect = _ab._effects.back() as EmpPulseEffect
	_confere(efeito_emp != null and efeito_emp.radius == previa.get_radius(), "EMP: o efeito usou o mesmo raio da prévia")
	_ab._open_command_mode()
	_ab._on_arrow(AbilityData.Dir.DOWN)
	_confere(not previa.visible, "EMP: não aparece em recarga")
	_ab.close_command_mode()
	_fim_secao = true


# --- Ajuste 4: halo do Rastro de Fogo ---

func _testar_rastro_de_fogo() -> void:
	await _nova_cena()
	var dados: AbilityData = _dados(&"rastro_de_fogo").duplicate() as AbilityData
	dados.duration = 0.6
	_ab._activate(dados)
	var efeito: FireTrailEffect = _ab._effects.back() as FireTrailEffect
	_confere(efeito.is_halo_visible(), "Rastro: halo aparece ao armar")
	await _frames(5)
	_confere(efeito.is_halo_visible(), "Rastro: halo continua enquanto não golpeia")
	_confere(_player.atacar_com_arma(), "Rastro: o jogador golpeou")
	_confere(not is_instance_valid(efeito) or not efeito.is_halo_visible(), "Rastro: halo some ao consumir o golpe")
	await _frames(40)
	_ab._cancel_all_effects()

	_ab._activate(dados)
	efeito = _ab._effects.back() as FireTrailEffect
	await _frames(50)
	_confere(not is_instance_valid(efeito) or not efeito.is_halo_visible(), "Rastro: halo some ao expirar o tempo")

	dados.duration = 8.0
	_ab._activate(dados)
	efeito = _ab._effects.back() as FireTrailEffect
	_player.tomar_dano(99999, true)
	await _frames(3)
	_confere(not is_instance_valid(efeito) or not efeito.is_halo_visible(), "Rastro: halo some ao morrer")

	await _nova_cena()
	_ab._activate(dados)
	efeito = _ab._effects.back() as FireTrailEffect
	efeito.get_parent().remove_child(efeito)
	_confere(not efeito.is_halo_visible(), "Rastro: halo some na troca de cena")
	efeito.free()
	_fim_secao = true


# --- Ajuste 5: Tiro Perfurante sem mira assistida ---

func _testar_perfurante() -> void:
	await _nova_cena()
	var assist_antes: bool = Platform.aim_assist
	Platform.aim_assist = true  # como no celular
	var direcao: Vector2 = _player.get_shot_direction()
	var inimigo: EnemyBase = _novo_inimigo(_player.global_position + direcao.rotated(deg_to_rad(10.0)) * 200.0)
	await _frames(3)
	_ab._activate(_dados(&"tiro_perfurante"))
	await _frames(12)
	var tiros: Array[PiercingProjectile] = []
	for no: Node in get_tree().root.find_children("*", "PiercingProjectile", true, false):
		if (no as PiercingProjectile).is_in_use():
			tiros.append(no as PiercingProjectile)
	_confere(tiros.size() == 1, "Perfurante: um tiro no ar (%d)" % tiros.size())
	if tiros.size() == 1:
		_confere(tiros[0]._assist_target == null, "Perfurante: sem alvo de mira assistida, mesmo com a assistência ligada")
		_confere(tiros[0].direction.is_equal_approx(direcao), "Perfurante: segue a direção bruta do cursor (sem curvar)")
	# Contraprova: o tiro carregado normal, com a assistência ligada, ainda escolhe alvo.
	var comum: PlayerProjectile = PoolHub.acquire(_player.projectile_scene, _player, PlayerProjectile) as PlayerProjectile
	if comum != null:
		comum.launch(_player.global_position, direcao, 10, 0.5, _player, Platform.aim_assist)
		_confere(comum._assist_target == inimigo, "Contraprova: o tiro normal continua com mira assistida")
		comum.recycle()
	Platform.aim_assist = assist_antes
	inimigo.queue_free()
	_inimigos.clear()
	await _frames(70)
	_fim_secao = true


# --- Ajuste 1 (Cura) ---

func _testar_cura() -> void:
	await _nova_cena()
	_player.hp = 40
	_ab._activate(_dados(&"cura"))
	_confere(_player.hp == 73, "Cura: recupera 4/12 da vida (33 HP): %d" % _player.hp)
	_confere(_dados(&"cura").cooldown == 36.0, "Cura: recarga continua 36 s")
	_confere(_dados(&"cura").description.contains("4 unidades"), "Cura: a descrição diz 4 unidades")
	_fim_secao = true


# --- Ajuste 6: reroll das lendárias ---

func _testar_reroll() -> void:
	await _nova_cena()
	var ui: AbilitiesUI = _player.get_node("AbilitiesUI") as AbilitiesUI
	var menu: LevelUpMenu = ui._menu
	menu.input_delay = 0.2
	RunState.reset()
	_confere(not RunState.reroll_used, "Reroll: começa disponível")
	ui._queue.append(1)
	await _frames(4)
	_confere(ui._menu_open and get_tree().paused, "Reroll: o menu de escolha abriu")
	var antes: Array[AbilityData] = ui._current_offer.duplicate()
	_confere(menu._cards.size() == 3 and not menu._reroll_button.disabled, "Reroll: 3 cartas e botão ativo")
	_confere(menu._reroll_button.focus_mode == Control.FOCUS_ALL, "Reroll: o botão aceita foco (teclado e controle)")

	menu._on_reroll_pressed()  # ainda no atraso anti-clique
	_confere(not RunState.reroll_used, "Reroll: ignorado durante o atraso anti-clique")
	await _frames(20)  # 0,33 s reais > 0,2 s
	menu._on_reroll_pressed()
	await _frames(2)
	_confere(RunState.reroll_used, "Reroll: gastou o reroll da run")
	_confere(menu._cards.size() == 3, "Reroll: continuam 3 cartas")
	var repetiu: bool = false
	for dado: AbilityData in ui._current_offer:
		repetiu = repetiu or antes.has(dado)
	_confere(not repetiu, "Reroll: as cartas novas não repetem as anteriores")
	_confere(menu._reroll_button.disabled and menu._reroll_button.text.contains("usado"), "Reroll: o botão mostra que já foi usado")
	var cartas_atuais: Array[AbilityData] = []
	for carta: LevelUpCard in menu._cards:
		cartas_atuais.append(carta.ability)
	_confere(cartas_atuais == ui._current_offer, "Reroll: o menu mostra exatamente a oferta nova")
	menu._on_card_selected(menu._cards[0].ability)  # logo depois do reroll a entrada trava de novo
	_confere(ui._menu_open, "Reroll: o atraso anti-clique vale de novo depois do reroll")
	await _frames(20)
	var depois: Array[AbilityData] = ui._current_offer.duplicate()
	menu._on_reroll_pressed()
	await _frames(2)
	_confere(ui._current_offer == depois, "Reroll: um segundo reroll não faz nada")
	var escolhida: AbilityData = menu._cards[0].ability
	menu._on_card_selected(escolhida)
	await _frames(3)
	_confere(not ui._menu_open and not get_tree().paused, "Reroll: a escolha fecha o menu e despausa")

	# Run nova: o reroll volta a ficar disponível.
	RunState.reset()
	_confere(not RunState.reroll_used, "Reroll: volta a estar disponível numa run nova")
	# Checkpoint (reiniciar a fase): o estado do reroll volta ao do início da fase.
	RunState.reroll_used = false
	RunState._save_checkpoint()
	RunState.reroll_used = true
	RunState._restore_checkpoint()
	_confere(not RunState.reroll_used, "Reroll: reiniciar a fase restaura o estado do checkpoint")
	RunState.reset()

	# Cancelar a confirmação de uma lendária não gasta o reroll.
	var pedidos: Array[int] = [0]
	var contador: Callable = func() -> void: pedidos[0] += 1
	menu.reroll_requested.connect(contador)
	var lendarias: Array[AbilityData] = [_dados(&"maquina_enigma"), _dados(&"overclock"), _dados(&"modo_sanguinario")]
	var donas: Array[AbilityData] = [_dados(&"reflexos")]
	menu.set_reroll_used(false)
	menu.open(3, lendarias, donas)
	await _frames(20)
	menu._on_card_selected(lendarias[0])
	_confere(menu._confirming, "Reroll: lendária pede confirmação")
	menu._on_reroll_pressed()
	_confere(pedidos[0] == 0, "Reroll: não dá para rerrolar com a confirmação aberta")
	menu._on_back_pressed()
	_confere(not RunState.reroll_used and not menu._confirming, "Reroll: cancelar a confirmação não gasta o reroll")
	menu._on_reroll_pressed()
	_confere(pedidos[0] == 1, "Reroll: depois de cancelar o botão ainda funciona")
	menu.reroll_requested.disconnect(contador)
	menu.close()

	# Tamanho: o pior caso (3 lendárias + manter + rerrolar) cabe na tela base de 1152 x 648.
	menu.set_reroll_used(false)
	menu.input_delay = 0.0
	menu.open(3, lendarias, donas)
	await _frames(4)
	var caixa: Control = menu._cards_box.get_parent() as Control
	# Referência: a altura base do projeto (a janela do modo headless tem outro tamanho).
	var altura_base: float = float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	_confere(caixa.get_combined_minimum_size().y <= altura_base,
			"Reroll: menu com 3 lendárias cabe na altura base (%.0f de %.0f)" % [caixa.get_combined_minimum_size().y, altura_base])
	menu.close()
	_fim_secao = true


# --- HUD das habilidades novas ---

func _hud() -> CommandHud:
	return _player.get_node("AbilitiesUI/CommandHud") as CommandHud


func _slot_de(id: StringName) -> CooldownSlot:
	return _hud()._entries[id]["slot"] as CooldownSlot


func _testar_hud_slots() -> void:
	await _nova_cena()
	var buff: AbilityData = _dados_curtos(&"reflexos", 0.5)
	var overclock: AbilityData = _dados_curtos(&"overclock", 1.0, 0.5)
	_ab.learn(buff)
	_ab.learn(overclock)
	await _frames(3)
	var slot: CooldownSlot = _slot_de(&"reflexos")
	_confere(slot.ability == buff and slot._amulet.ability == buff, "HUD: o slot mostra a habilidade nova")
	_confere(not slot.is_effect_active() and slot._remaining == 0.0, "HUD: slot pronto antes de usar")
	_ab._activate(buff)
	_confere(slot.is_effect_active(), "HUD: estado ativa aparece ao ativar o buff")
	_confere(slot._cooling, "HUD: a recarga conta desde a ativação")
	var restante: float = slot._remaining
	get_tree().paused = true
	await _frames(30)
	_confere(slot._remaining == restante and slot.is_effect_active(), "HUD: tempo do slot parado com o jogo pausado")
	get_tree().paused = false
	await _frames(45)  # passou da duração (0,5 s)
	_confere(not slot.is_effect_active() and slot._cooling, "HUD: o estado ativa some ao terminar e volta a recarga")

	var slot_over: CooldownSlot = _slot_de(&"overclock")
	_ab._activate(overclock)
	await _frames(15)
	_confere(slot_over.is_effect_active() and not slot_over.is_penalty_active(), "HUD: Overclock ativo na fase de bônus (anel dourado)")
	await _frames(25)
	_confere(slot_over.is_effect_active() and slot_over.is_penalty_active(), "HUD: Overclock na fase de penalidade (anel de outra cor)")

	# Menu de build: lista o efeito ativo e marca a penalidade.
	var ui: AbilitiesUI = _player.get_node("AbilitiesUI") as AbilitiesUI
	_confere(ui.open_build_menu(&"overclock"), "HUD: o menu de build abre")
	var linhas: PackedStringArray = []
	for filho: Node in ui._build_menu._active_list.get_children():
		linhas.append((filho as Label).text)
	var tem_linha: bool = false
	for linha: String in linhas:
		tem_linha = tem_linha or (linha.contains("Overclock") and linha.contains("(penalidade)"))
	_confere(tem_linha, "HUD: 'Ativos agora' mostra o Overclock com a penalidade e o tempo (%s)" % str(linhas))
	_confere(ui._build_menu._cards.size() == 2, "HUD: o menu de build mostra as 2 habilidades possuídas")
	var cooldown_aberto: float = _ab.get_cooldown_left(&"overclock")
	await _frames(20)
	_confere(_ab.get_cooldown_left(&"overclock") == cooldown_aberto, "HUD: com o menu de build aberto o tempo fica parado")
	ui._close_build_menu()
	await _frames(3)

	# Com o máximo de habilidades (3 slots) nada se sobrepõe nem sai da tela.
	_ab.learn(_dados(&"pele_de_ferro"))
	await _frames(5)
	var janela: Window = get_window()
	var tamanho_antes: Vector2i = janela.size
	for tamanho: Vector2i in [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1024, 768)]:  # 16:9 e 4:3
		janela.size = tamanho
		await _frames(4)
		var retangulos: Array[Rect2] = []
		for id: StringName in _hud()._entries:
			retangulos.append((_hud()._entries[id]["slot"] as CooldownSlot).get_global_rect())
		var tela: Rect2 = get_viewport().get_visible_rect()
		var sobrepoe: bool = false
		var fora: bool = false
		for i: int in retangulos.size():
			fora = fora or not tela.encloses(retangulos[i])
			for j: int in range(i + 1, retangulos.size()):
				sobrepoe = sobrepoe or retangulos[i].intersects(retangulos[j])
		_confere(retangulos.size() == 3 and not sobrepoe and not fora,
				"HUD: 3 slots sem sobreposição e dentro da tela em %dx%d (área %s)" % [tamanho.x, tamanho.y, tela.size])
	janela.size = tamanho_antes


	_fim_secao = true
## Cartas das 9 novas: o texto cabe na área reservada, sem cortar nem estourar.
func _testar_hud_cartas() -> void:
	await _nova_cena()
	var menu: LevelUpMenu = LevelUpMenu.new()
	menu.input_delay = 0.0
	add_child(menu)
	var ids: Array = NOVAS.keys()
	var maior_nome: float = 0.0
	for i: int in range(0, ids.size(), 3):
		var oferta: Array[AbilityData] = []
		for k: int in range(i, mini(i + 3, ids.size())):
			oferta.append(_dados(ids[k]))
		menu.open(3, oferta, [])
		await _frames(3)
		for carta: LevelUpCard in menu._cards:
			var etiquetas: Array[Node] = carta.find_children("*", "Label", true, false)
			var achou_nome: bool = false
			var achou_descricao: bool = false
			for no: Node in etiquetas:
				var etiqueta: Label = no as Label
				if etiqueta.text == carta.ability.display_name:
					achou_nome = true
					_confere(etiqueta.get_line_count() <= 2, "Carta %s: nome em até 2 linhas (%d)" % [carta.ability.id, etiqueta.get_line_count()])
					maior_nome = maxf(maior_nome, etiqueta.get_minimum_size().x)
				elif etiqueta.text == carta.ability.description:
					achou_descricao = true
					_confere(etiqueta.size.y <= LevelUpCard.DESCRIPTION_HEIGHT + 1.0 and etiqueta.get_line_count() <= 4,
							"Carta %s: descrição cabe sem cortar (%d linhas, %.0f px)" % [carta.ability.id, etiqueta.get_line_count(), etiqueta.size.y])
			_confere(achou_nome and achou_descricao, "Carta %s: nome e descrição aparecem" % carta.ability.id)
			if carta.ability.rarity == AbilityData.Rarity.LENDARIA:
				var tem_aviso: bool = false
				for no: Node in etiquetas:
					tem_aviso = tem_aviso or (no as Label).text == LevelUpCard.WARNING_TEXT
				_confere(tem_aviso, "Carta %s: aviso de perda da lendária" % carta.ability.id)
		menu.close()
	menu.queue_free()

	# Linhas do painel do modo comando: o nome mais longo das novas cabe onde cabe o das antigas.
	var largura_antiga: float = _largura_nome(&"cavaleiro_imbativel")
	for id: StringName in ids:
		_confere(_largura_nome(id) <= largura_antiga, "Painel de comando: o nome de %s cabe na coluna (%.0f <= %.0f px)" % [id, _largura_nome(id), largura_antiga])
	_fim_secao = true


func _largura_nome(id: StringName) -> float:
	var etiqueta: Label = Label.new()
	etiqueta.text = _dados(id).display_name
	add_child(etiqueta)
	var largura: float = etiqueta.get_minimum_size().x
	etiqueta.queue_free()
	return largura


func _testar_demo() -> void:
	var demo: Node = (load("res://tests/hud_habilidades_novas.tscn") as PackedScene).instantiate()
	add_child(demo)
	await _frames(5)
	var abas: TabContainer = demo.get_child(1) as TabContainer
	_confere(abas != null and abas.get_tab_count() == 7, "Demo: a cena de pré-visualização abre com as 7 abas")
	demo.queue_free()
	await _frames(2)
	_fim_secao = true
