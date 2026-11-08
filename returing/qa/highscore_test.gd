extends SceneTree
## Testes dos recordes locais (usa um arquivo temporário, nunca o do jogador).
## Rodar: godot --headless --path . --script qa/highscore_test.gd

const ARQUIVO_TESTE: String = "user://returing_recordes_teste.cfg"

var _falhas: int = 0
var _total: int = 0


func _initialize() -> void:
	HighScoreStore.caminho = ARQUIVO_TESTE
	_limpar()
	_rodar()
	_limpar()
	print("highscore_test: %d verificações, %d falhas" % [_total, _falhas])
	quit(1 if _falhas > 0 else 0)


func _confere(condicao: bool, nome: String) -> void:
	_total += 1
	if not condicao:
		_falhas += 1
		printerr("FALHOU: ", nome)


func _limpar() -> void:
	if FileAccess.file_exists(ARQUIVO_TESTE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ARQUIVO_TESTE))


func _escrever(texto: String) -> void:
	var f := FileAccess.open(ARQUIVO_TESTE, FileAccess.WRITE)
	f.store_string(texto)
	f.close()


func _rodar() -> void:
	_confere(HighScoreStore.carregar().is_empty(), "sem arquivo = sem recorde")

	var r: Dictionary = HighScoreStore.registrar(11333, &"B", 1020.0)
	_confere(r["novo_recorde"] == true, "primeira run cria recorde")
	var salvo: Dictionary = HighScoreStore.carregar()
	_confere(salvo["total"] == 11333 and salvo["rank"] == &"B" and salvo["tempo_s"] == 1020.0, "recorde salvo e relido")

	r = HighScoreStore.registrar(9000, &"C", 900.0)
	_confere(r["novo_recorde"] == false, "total menor não é recorde")
	salvo = HighScoreStore.carregar()
	_confere(salvo["total"] == 11333 and salvo["rank"] == &"B", "total e rank mantidos")
	_confere(salvo["tempo_s"] == 900.0, "melhor tempo atualiza sozinho")

	r = HighScoreStore.registrar(11333, &"B", 1000.0)
	_confere(r["novo_recorde"] == false, "total igual não é recorde")

	r = HighScoreStore.registrar(18000, &"S", 1500.0)
	_confere(r["novo_recorde"] == true and r["anterior"]["total"] == 11333, "total maior é recorde")
	salvo = HighScoreStore.carregar()
	_confere(salvo["total"] == 18000 and salvo["rank"] == &"S" and salvo["tempo_s"] == 900.0, "novo recorde não piora o melhor tempo")

	_escrever("isto não é um arquivo de configuração {{{")
	_confere(HighScoreStore.carregar().is_empty(), "arquivo corrompido = sem recorde")
	r = HighScoreStore.registrar(5000, &"D", 2000.0)
	_confere(r["novo_recorde"] == true and HighScoreStore.carregar()["total"] == 5000, "corrompido é sobrescrito sem erro")

	_escrever("[recorde]\nmelhor_total=\"abc\"\nrank=\"Z\"\nmelhor_tempo_s=10.0\n")
	_confere(HighScoreStore.carregar().is_empty(), "tipos/rank inválidos = sem recorde")
