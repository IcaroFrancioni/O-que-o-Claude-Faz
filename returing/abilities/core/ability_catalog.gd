class_name AbilityCatalog
extends Resource
## Catálogo único com todas as habilidades. Para criar uma nova, duplique um `.tres` e adicione aqui.

## Quantas cartas o menu de level-up oferece.
const OFFER_SIZE: int = 3

@export var abilities: Array[AbilityData] = []

@export_group("Oferta")
## Peso de uma lendária no sorteio (1.0 = igual às demais; menor = mais rara).
@export_range(0.0, 10.0, 0.05) var legendary_weight: float = 1.0
## Menor nível em que lendárias podem aparecer.
@export_range(1, 10) var legendary_min_level: int = 3

static var _validated: bool = false


## Roda o validador uma vez por execução do jogo.
func validate_once() -> void:
	if _validated:
		return
	_validated = true
	AbilityData.validate(abilities)


## Procura uma habilidade pelo id (null se não existir).
func find_by_id(ability_id: StringName) -> AbilityData:
	for data: AbilityData in abilities:
		if data != null and data.id == ability_id:
			return data
	return null


## Sorteia até 3 habilidades para o nível, sem repetir e sem as ids excluídas
## (já possuídas ou rejeitadas). Lendárias só entram a partir de `legendary_min_level`.
func draw_offer(level: int, excluded_ids: Array[StringName]) -> Array[AbilityData]:
	var pool: Array[AbilityData] = []
	for data: AbilityData in abilities:
		if data == null or excluded_ids.has(data.id):
			continue
		if data.rarity == AbilityData.Rarity.LENDARIA and level < legendary_min_level:
			continue
		pool.append(data)

	var result: Array[AbilityData] = []
	while result.size() < OFFER_SIZE and not pool.is_empty():
		var total: float = 0.0
		for data: AbilityData in pool:
			total += _weight_of(data)
		var pick: int = pool.size() - 1
		if total > 0.0:
			var roll: float = randf() * total
			var acumulado: float = 0.0
			for i: int in pool.size():
				acumulado += _weight_of(pool[i])
				if roll < acumulado:
					pick = i
					break
		result.append(pool[pick])
		pool.remove_at(pick)
	return result


func _weight_of(data: AbilityData) -> float:
	return legendary_weight if data.rarity == AbilityData.Rarity.LENDARIA else 1.0
