
extends Node

signal vida_alterada(vida_atual: int, vida_maxima: int)
signal morreu

@export_group("Configuração de vida")
@export var vida_maxima: int = 100

var vida_atual: int = 0
var personagem: CharacterBody2D
var esta_morto: bool = false


func _ready() -> void:
	personagem = get_parent() as CharacterBody2D

	if personagem == null:
		push_error("VidaPlayer precisa ser filho do jogador!")
		return

	vida_atual = vida_maxima
	vida_alterada.emit(vida_atual, vida_maxima)

	print("Vida do jogador: ", vida_atual)


func receber_dano(quantidade: int) -> void:
	if esta_morto or quantidade <= 0:
		return

	vida_atual = maxi(vida_atual - quantidade, 0)
	vida_alterada.emit(vida_atual, vida_maxima)

	print("Vida do jogador: ", vida_atual, "/", vida_maxima)

	if vida_atual <= 0:
		morrer()


func curar(quantidade: int) -> void:
	if esta_morto or quantidade <= 0:
		return

	vida_atual = mini(vida_atual + quantidade, vida_maxima)
	vida_alterada.emit(vida_atual, vida_maxima)

	print("Jogador curado: ", vida_atual, "/", vida_maxima)


func morrer() -> void:
	if esta_morto:
		return

	esta_morto = true
	print("O jogador foi derrotado!")

	morreu.emit()
	personagem.queue_free()
