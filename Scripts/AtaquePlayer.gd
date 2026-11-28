
extends Node2D

@export_group("Ataque")
@export var dano: float = 10.0
@export var forca_knockback: float = 350.0
@export var tempo_ataque: float = 0.25
@export var intervalo_ataque: float = 0.4

@export_group("Hitbox")
@export var tamanho_hitbox: Vector2 = Vector2(100, 70)
@export var distancia_hitbox: float = 65.0

var personagem: CharacterBody2D
var hitbox: Area2D

var tempo_restante: float = 0.0
var atacando: bool = false

var alvos_atingidos: Array[Node] = []


func _ready() -> void:
	personagem = get_parent() as CharacterBody2D

	if personagem == null:
		push_error("AtaquePlayer precisa ser filho do jogador!")
		return

	criar_hitbox()

	print("JOGADOR: Sistema de ataque iniciado!")


func _physics_process(delta: float) -> void:
	tempo_restante = maxf(tempo_restante - delta, 0.0)

	if Input.is_action_just_pressed("ataque_1"):
		atacar()

	if atacando:
		detectar_alvos()


func criar_hitbox() -> void:
	hitbox = Area2D.new()
	hitbox.name = "HitboxJogador"

	hitbox.collision_layer = 0
	hitbox.collision_mask = 1

	hitbox.monitoring = true
	hitbox.monitorable = false

	var forma := CollisionShape2D.new()
	var retangulo := RectangleShape2D.new()

	retangulo.size = tamanho_hitbox
	forma.shape = retangulo

	hitbox.add_child(forma)
	add_child(hitbox)

	print("JOGADOR: Hitbox criada!")


func atualizar_hitbox() -> void:
	var sprite = personagem.get_node_or_null("Sprite2D")

	var direcao: float = 1.0

	if sprite != null and sprite.flip_h:
		direcao = -1.0

	hitbox.position = Vector2(
		distancia_hitbox * direcao,
		0.0
	)


func atacar() -> void:
	if atacando or tempo_restante > 0.0:
		return

	atacando = true

	tempo_restante = intervalo_ataque

	alvos_atingidos.clear()

	atualizar_hitbox()

	var animador := personagem.get_node_or_null("AnimadorPersonagem") as AnimadorPersonagem
	if animador != null:
		animador.atacar()

	print("JOGADOR: Ataque iniciado!")

	await get_tree().physics_frame

	if not is_inside_tree():
		return

	await get_tree().create_timer(tempo_ataque).timeout

	atacando = false

	print("JOGADOR: Ataque finalizado!")


func detectar_alvos() -> void:
	if not is_instance_valid(hitbox):
		return

	for corpo in hitbox.get_overlapping_bodies():

		if corpo == personagem:
			continue

		if alvos_atingidos.has(corpo):
			continue

		var vida = corpo.get_node_or_null("VidaBot")

		if vida == null:
			continue

		alvos_atingidos.append(corpo)

		var direcao: Vector2 = (
			corpo.global_position - personagem.global_position
		)

		vida.receber_ataque(
			dano,
			direcao,
			forca_knockback
		)

		Repulsao.aplicar(corpo, personagem, 12.0)

		print("JOGADOR: Bot atingido!")
		print("JOGADOR: Dano causado: ", dano)
		print("JOGADOR: Repulsão adicionada: 12.0")
