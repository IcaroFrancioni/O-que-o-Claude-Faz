extends Node
## Auditoria de carga: carrega todo script, cena e recurso do projeto (fora de addons) e conta
## o que falha. Erros e avisos do GDScript saem no console durante a carga.
## Rodar: godot --headless --path . res://qa/audit_load.tscn

const PULAR: PackedStringArray = ["res://addons", "res://.godot", "res://entrega"]
const EXTENSOES: PackedStringArray = ["gd", "tscn", "tres"]


func _ready() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var arquivos: PackedStringArray = []
	_listar("res://", arquivos)
	arquivos.sort()
	var falhas: PackedStringArray = []
	var contagem: Array[int] = [0, 0, 0]
	for caminho: String in arquivos:
		contagem[EXTENSOES.find(caminho.get_extension())] += 1
		var recurso: Resource = ResourceLoader.load(caminho)
		if recurso == null:
			falhas.append(caminho)
	for f: String in falhas:
		printerr("FALHA_DE_CARGA: ", f)
	print("audit_load: %d arquivos (%d gd, %d tscn, %d tres), %d falhas de carga" % [
			arquivos.size(), contagem[0], contagem[1], contagem[2], falhas.size()])
	get_tree().quit(1 if not falhas.is_empty() else 0)


func _listar(pasta: String, saida: PackedStringArray) -> void:
	for p: String in PULAR:
		if pasta.begins_with(p):
			return
	for arquivo: String in DirAccess.get_files_at(pasta):
		if EXTENSOES.has(arquivo.get_extension()):
			saida.append(pasta.path_join(arquivo))
	for sub: String in DirAccess.get_directories_at(pasta):
		_listar(pasta.path_join(sub), saida)
