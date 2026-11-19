
extends Area2D


func _ready() -> void:
	monitoring = true

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	print("VOID: Sistema iniciado!")


func _on_body_entered(corpo: Node2D) -> void:
	print("VOID: Corpo detectado: ", corpo.name)

	if not corpo is CharacterBody2D:
		return

	var gerenciador = get_tree().get_first_node_in_group(
		"gerenciador_respawn"
	)

	if gerenciador == null:
		push_error("VOID: GerenciadorRespawn não encontrado!")
		return

	print("VOID: Eliminando personagem: ", corpo.name)

	gerenciador.eliminar_personagem(corpo)
