extends Node
## Player falso dos testes de qa/: só expõe o que o RunRecorder consulta.

var morto: bool = false
var hp_maximo: int = 100


func esta_morto() -> bool:
	return morto
