
extends Node2D

@export_group("Ataque leve")
@export var dano_leve: float = 8.0
@export var forca_leve: float = 300.0

@export_group("Ataque médio")
@export var dano_medio: float = 12.0
@export var forca_media: float = 450.0

@export_group("Ataque forte")
@export var dano_forte: float = 18.0
@export var forca_forte: float = 650.0

@export_group("Configurações")
@export var duracao_ataque: float = 0.2
@export var intervalo_ataque: float = 0.5

@export_group("Hitbox")
@export var tamanho_hitbox: Vector2 = Vector2(110, 70)
@export var distancia_hitbox: float = 65.0

var personagem: CharacterBody2D
var hitbox: Area2D

var atacando: bool = false
var tempo_restante: float = 0.0

var dano_atual: float = 0.0
var forca_atual: float = 0.0

var alvos_atingidos: Array[Node] = []


func _ready() -> void:
	personagem = get_parent() as CharacterBody2D

	if personagem == null:
		push_error("AtaqueBot precisa ser filho de Bot!")
		return

	criar_hitbox()

	print("BOT: Sistema de ataques iniciado!")


func _physics_process(delta: float) -> void:
	tempo_restante = maxf(tempo_restante - delta, 0.0)

	if atacando:
		detectar_alvos()


func criar_hitbox() -> void:
	hitbox = Area2D.new()
	hitbox.name = "HitboxBot"

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

	print("BOT: Hitbox criada!")


func atualizar_hitbox() -> void:
	var sprite = personagem.get_node_or_null("Sprite2D")

	var direcao: float = 1.0

	if sprite != null and sprite.flip_h:
		direcao = -1.0

	hitbox.position = Vector2(
		distancia_hitbox * direcao,
		0.0
	)


func executar_ataque(tipo: int) -> void:
	if atacando or tempo_restante > 0.0:
		return

	match tipo:
		1:
			dano_atual = dano_leve
			forca_atual = forca_leve

		2:
			dano_atual = dano_medio
			forca_atual = forca_media

		3:
			dano_atual = dano_forte
			forca_atual = forca_forte

		_:
			return

	atacando = true

	tempo_restante = intervalo_ataque

	alvos_atingidos.clear()

	atualizar_hitbox()

	var animador := personagem.get_node_or_null("AnimadorPersonagem") as AnimadorPersonagem
	if animador != null:
		animador.atacar()

	print("BOT: Ataque ", tipo, " iniciado!")

	await get_tree().physics_frame

	if not is_inside_tree():
		return

	await get_tree().create_timer(duracao_ataque).timeout

	if not is_inside_tree():
		return

	atacando = false

	print("BOT: Ataque finalizado!")


func detectar_alvos() -> void:
	if not is_instance_valid(hitbox):
		return

	for corpo in hitbox.get_overlapping_bodies():

		if corpo == personagem:
			continue

		if alvos_atingidos.has(corpo):
			continue

		var vida = corpo.get_node_or_null("VidaPlayer")

		if vida == null:
			continue

		alvos_atingidos.append(corpo)

		var direcao: Vector2 = (
			corpo.global_position - personagem.global_position
		)

		vida.receber_ataque(
			dano_atual,
			direcao,
			forca_atual
		)

		Repulsao.aplicar(corpo, personagem, 12.0)

		print("BOT: Jogador atingido!")
		print("BOT: Dano causado: ", dano_atual)
		print("BOT: Força do golpe: ", forca_atual)
		print("BOT: Repulsão adicionada: 12.0")
