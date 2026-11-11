
extends Node2D

@export_group("Controles")
@export var acao_ataque: StringName = &"p1_ataque"
@export var acao_ataque_cima: StringName = &"p1_ataque_cima"
@export var acao_ataque_baixo: StringName = &"p1_ataque_baixo"

@export_group("Porcentagem")
@export var percentual_lateral: float = 12.0
@export var percentual_cima: float = 10.0
@export var percentual_baixo: float = 14.0

@export_group("Knockback")
@export var forca_base_knockback: float = 300.0

@export_group("Tempo")
@export var duracao_ataque: float = 0.16
@export var intervalo_ataques: float = 0.38

@export_group("Alcance")
@export var alcance_lateral: float = 55.0
@export var alcance_vertical: float = 55.0

var personagem: CharacterBody2D
var hitbox: Area2D
var forma_hitbox: CollisionShape2D

var ataque_ativo: bool = false
var tempo_ataque: float = 0.0
var tempo_recarga: float = 0.0

var direcao_olhando: float = 1.0
var direcao_knockback: Vector2 = Vector2.RIGHT
var percentual_atual: float = 0.0

var alvos_atingidos: Dictionary = {}


func _ready() -> void:
	personagem = get_parent() as CharacterBody2D

	if personagem == null:
		push_error("AtaquePlayer precisa ser filho do jogador!")
		return

	criar_hitbox()


func criar_hitbox() -> void:
	hitbox = Area2D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 0
	hitbox.collision_mask = 1
	hitbox.monitoring = true

	add_child(hitbox)

	forma_hitbox = CollisionShape2D.new()
	forma_hitbox.name = "CollisionShape2D"

	var retangulo := RectangleShape2D.new()
	retangulo.size = Vector2(75, 40)

	forma_hitbox.shape = retangulo
	forma_hitbox.disabled = true

	hitbox.add_child(forma_hitbox)


func _physics_process(delta: float) -> void:
	if personagem == null:
		return

	if personagem.velocity.x > 1.0:
		direcao_olhando = 1.0
	elif personagem.velocity.x < -1.0:
		direcao_olhando = -1.0

	tempo_recarga = maxf(tempo_recarga - delta, 0.0)

	if ataque_ativo:
		tempo_ataque -= delta
		verificar_acertos()

		if tempo_ataque <= 0.0:
			finalizar_ataque()

	elif tempo_recarga <= 0.0:
		if Input.is_action_just_pressed(acao_ataque):
			iniciar_ataque()


func iniciar_ataque() -> void:
	ataque_ativo = true
	tempo_ataque = duracao_ataque
	tempo_recarga = intervalo_ataques

	alvos_atingidos.clear()

	if Input.is_action_pressed(acao_ataque_cima):
		percentual_atual = percentual_cima

		hitbox.position = Vector2(0, -alcance_vertical)
		forma_hitbox.shape.size = Vector2(45, 75)

		direcao_knockback = Vector2(0, -1)

	elif Input.is_action_pressed(acao_ataque_baixo):
		percentual_atual = percentual_baixo

		hitbox.position = Vector2(0, alcance_vertical)
		forma_hitbox.shape.size = Vector2(65, 55)

		direcao_knockback = Vector2(direcao_olhando, 0.5).normalized()

	else:
		percentual_atual = percentual_lateral

		hitbox.position = Vector2(
			alcance_lateral * direcao_olhando,
			0
		)

		forma_hitbox.shape.size = Vector2(75, 40)

		direcao_knockback = Vector2(
			direcao_olhando,
			-0.35
		).normalized()

	forma_hitbox.set_deferred("disabled", false)


func verificar_acertos() -> void:
	for corpo in hitbox.get_overlapping_bodies():

		if corpo == personagem:
			continue

		var porcentagem = corpo.get_node_or_null("VidaInimigo")

		if porcentagem == null:
			continue

		var id_alvo: int = corpo.get_instance_id()

		if alvos_atingidos.has(id_alvo):
			continue

		alvos_atingidos[id_alvo] = true

		porcentagem.receber_ataque(
			percentual_atual,
			direcao_knockback,
			forca_base_knockback
		)


func finalizar_ataque() -> void:
	ataque_ativo = false
	forma_hitbox.set_deferred("disabled", true)
