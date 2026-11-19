
extends Node

signal porcentagem_alterada(nova_porcentagem: float)

@export_group("Porcentagem")
@export var porcentagem_inicial: float = 0.0

@export_group("Knockback")
@export var multiplicador_knockback: float = 1.0
@export var aumento_porcentagem: float = 1.0

var porcentagem: float = 0.0
var personagem: CharacterBody2D


func _ready() -> void:
	personagem = get_parent() as CharacterBody2D

	if personagem == null:
		push_error("VidaPlayer precisa ser filho do jogador!")
		return

	porcentagem = porcentagem_inicial
	porcentagem_alterada.emit(porcentagem)

	print("VIDA PLAYER: Sistema iniciado!")
	print("VIDA PLAYER: Porcentagem: ", porcentagem, "%")


func receber_ataque(quantidade: float, direcao: Vector2, forca_base: float) -> void:
	if not is_instance_valid(personagem):
		return

	if quantidade <= 0.0:
		return

	porcentagem += quantidade * aumento_porcentagem
	porcentagem_alterada.emit(porcentagem)

	var multiplicador: float = (1.0 + porcentagem / 100.0) * multiplicador_knockback
	var forca_final: float = forca_base * multiplicador

	if personagem.has_method("receber_knockback"):
		personagem.receber_knockback(direcao, forca_final)

	print("VIDA PLAYER: Recebeu ataque!")
	print("VIDA PLAYER: Porcentagem: ", porcentagem, "%")
	print("VIDA PLAYER: Knockback: ", forca_final)


func resetar_porcentagem() -> void:
	porcentagem = 0.0
	porcentagem_alterada.emit(porcentagem)
	print("VIDA PLAYER: Porcentagem reiniciada!")


func obter_porcentagem() -> float:
	return porcentagem
