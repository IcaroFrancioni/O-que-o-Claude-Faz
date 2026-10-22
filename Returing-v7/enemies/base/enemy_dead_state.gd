class_name EnemyDeadState
extends EnemyState
## Estado final do StateWarden (canônico DEAD): o inimigo para de se mover.
## A animação de morte e a liberação do nó ficam com o EnemyBase; este estado só
## garante que a máquina termina "dentro" de um estado seguro e travado.


func _on_enter() -> void:
	enemy.velocity = Vector2.ZERO
