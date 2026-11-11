
extends Node

@export var alvo: CharacterBody2D

@export_group("Movimentação")
@export var distancia_minima: float = 90.0
@export var distancia_maxima: float = 190.0
@export var altura_para_pular: float = 80.0

@export_group("Investidas")
@export var intervalo_minimo: float = 2.5
@export var intervalo_maximo: float = 4.5
@export var duracao_investida: float = 1.5

@export_group("Ataque")
@export var distancia_ataque: float = 130.0
@export var dano_ataque: int = 8
@export var forca_knockback: float = 450.0
@export var duracao_ataque: float = 0.25
@export var intervalo_ataque: float = 1.0

@export_group("Hitbox")
@export var largura_hitbox: float = 110.0
@export var altura_hitbox: float = 60.0
@export var distancia_hitbox: float = 65.0

@export_group("Pulos")
@export var intervalo_pulos: float = 0.7

var personagem: CharacterBody2D
var hitbox: Area2D
var forma_hitbox: CollisionShape2D

var tempo_proxima_investida: float = 0.0
var tempo_investida: float = 0.0
var tempo_ataque: float = 0.0
var tempo_recarga_ataque: float = 0.0
var tempo_para_pular: float = 0.0
var tempo_debug: float = 0.0

var investida_ativa: bool = false
var ataque_ativo: bool = false

var direcao_ataque: float = 1.0
var alvos_atingidos: Dictionary = {}


func _ready() -> void:
	personagem = get_parent() as CharacterBody2D

	if personagem == null:
		push_error("BOT: IA precisa ser filha de um CharacterBody2D!")
		return

	criar_hitbox()
	sortear_investida()

	print("BOT: IA iniciada!")
	print("BOT: Alvo configurado? ", is_instance_valid(alvo))


func criar_hitbox() -> void:
	hitbox = Area2D.new()
	hitbox.name = "HitboxAtaque"
	hitbox.collision_layer = 0
	hitbox.collision_mask = 1
	hitbox.monitoring = true

	personagem.add_child.call_deferred(hitbox)

	forma_hitbox = CollisionShape2D.new()
	forma_hitbox.name = "CollisionShape2D"

	var retangulo := RectangleShape2D.new()
	retangulo.size = Vector2(largura_hitbox, altura_hitbox)

	forma_hitbox.shape = retangulo
	forma_hitbox.disabled = true

	hitbox.add_child(forma_hitbox)


func _physics_process(delta: float) -> void:
	if personagem == null:
		return

	if not is_instance_valid(alvo):
		personagem.direcao_externa = 0.0
		return

	if not is_instance_valid(hitbox):
		return

	var diferenca_x: float = alvo.global_position.x - personagem.global_position.x
	var diferenca_y: float = personagem.global_position.y - alvo.global_position.y
	var distancia: float = absf(diferenca_x)

	# Diagnóstico
	tempo_debug -= delta

	if tempo_debug <= 0.0:
		tempo_debug = 1.0
		print("BOT: Distância: ", distancia)
		print("BOT: Ataque ativo? ", ataque_ativo)

	tempo_recarga_ataque = maxf(tempo_recarga_ataque - delta, 0.0)
	tempo_para_pular = maxf(tempo_para_pular - delta, 0.0)

	if ataque_ativo:
		personagem.direcao_externa = 0.0
		atualizar_posicao_hitbox()
		executar_ataque(delta)

	else:
		controlar_movimento(distancia, diferenca_x, delta)

		if distancia <= distancia_ataque:
			if tempo_recarga_ataque <= 0.0:
				iniciar_ataque(diferenca_x)

	verificar_pulo(diferenca_y)


func atualizar_posicao_hitbox() -> void:
	hitbox.position = Vector2(
		distancia_hitbox * direcao_ataque,
		0.0
	)


func controlar_movimento(
	distancia: float,
	diferenca_x: float,
	delta: float
) -> void:

	if investida_ativa:
		tempo_investida -= delta
		personagem.direcao_externa = signf(diferenca_x)

		if tempo_investida <= 0.0:
			investida_ativa = false
			sortear_investida()

		return

	if distancia > distancia_maxima:
		personagem.direcao_externa = signf(diferenca_x)

	elif distancia < distancia_minima:
		personagem.direcao_externa = -signf(diferenca_x)

	else:
		personagem.direcao_externa = 0.0

	tempo_proxima_investida -= delta

	if tempo_proxima_investida <= 0.0:
		investida_ativa = true
		tempo_investida = duracao_investida


func iniciar_ataque(diferenca_x: float) -> void:
	ataque_ativo = true
	tempo_ataque = duracao_ataque
	tempo_recarga_ataque = intervalo_ataque

	alvos_atingidos.clear()

	direcao_ataque = signf(diferenca_x)

	if is_zero_approx(direcao_ataque):
		direcao_ataque = 1.0

	atualizar_posicao_hitbox()

	forma_hitbox.set_deferred("disabled", false)

	print("BOT: ataque iniciado!")


func executar_ataque(delta: float) -> void:
	tempo_ataque -= delta

	verificar_acertos()

	if tempo_ataque <= 0.0:
		ataque_ativo = false
		forma_hitbox.set_deferred("disabled", true)
		print("BOT: ataque finalizado!")


func verificar_acertos() -> void:
	if not is_instance_valid(hitbox):
		return

	var corpos = hitbox.get_overlapping_bodies()

	if corpos.size() > 0:
		print("BOT: Hitbox detectou ", corpos.size(), " corpo(s)!")

	for corpo in corpos:
		if corpo == personagem:
			continue

		if corpo != alvo:
			continue

		var vida = corpo.get_node_or_null("VidaPlayer")

		if vida == null:
			print("ERRO: VidaPlayer não encontrado!")
			continue

		var id_alvo: int = corpo.get_instance_id()

		if alvos_atingidos.has(id_alvo):
			continue

		alvos_atingidos[id_alvo] = true

		# Aplica dano.
		vida.receber_dano(dano_ataque)

		# Aplica knockback.
		if is_instance_valid(corpo):
			var direcao := Vector2(
				direcao_ataque,
				-0.35
			).normalized()

			if corpo.has_method("receber_knockback"):
				corpo.receber_knockback(
					direcao,
					forca_knockback
				)

				print("BOT: Knockback aplicado!")
			else:
				push_warning("Jogador não possui receber_knockback()!")

		print("BOT: acertou o jogador! Dano: ", dano_ataque)


func verificar_pulo(diferenca_y: float) -> void:
	if personagem.is_on_floor():
		if diferenca_y > altura_para_pular:
			if tempo_para_pular <= 0.0:
				personagem.solicitar_pulo()
				tempo_para_pular = intervalo_pulos


func sortear_investida() -> void:
	tempo_proxima_investida = randf_range(
		intervalo_minimo,
		intervalo_maximo
	)
