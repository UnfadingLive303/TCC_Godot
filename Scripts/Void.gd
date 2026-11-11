
extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(corpo: Node2D) -> void:
	print(corpo.name, " caiu no Void e foi destruído!")

	corpo.queue_free()
