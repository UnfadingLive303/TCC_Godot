
extends Node

signal porcentagem_alterada(porcentagem: float)

@export_group("Configuração")
@export var porcentagem_inicial: float = 0.0

var porcentagem: float = 0.0
var personagem: CharacterBody2D


func _ready() -> void:
	personagem = get_parent() as CharacterBody2D

	if personagem == null:
		push_error("VidaInimigo precisa ser filho do inimigo!")
		return

	porcentagem = porcentagem_inicial
	porcentagem_alterada.emit(porcentagem)

	print("Porcentagem do inimigo: ", porcentagem, "%")


func receber_ataque(
	quantidade: float,
	direcao: Vector2,
	forca_base: float
) -> void:

	if personagem == null or quantidade <= 0:
		return

	# Aumenta a porcentagem.
	porcentagem += quantidade

	porcentagem_alterada.emit(porcentagem)

	print("Porcentagem do inimigo: ", porcentagem, "%")

	# Quanto maior a porcentagem, maior o knockback.
	var multiplicador: float = 1.0 + (porcentagem / 100.0)

	var forca_final: float = forca_base * multiplicador

	# Aplica o lançamento.
	if personagem.has_method("receber_knockback"):
		personagem.receber_knockback(
			direcao,
			forca_final
		)


func resetar_porcentagem() -> void:
	porcentagem = 0.0

	porcentagem_alterada.emit(porcentagem)

	print("Porcentagem reiniciada!")
