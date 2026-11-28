
extends Node

enum Estado {
	PERSEGUIR,
	COMBATER,
	ESQUIVAR,
	REPOSICIONAR
}

@export_group("Alvo")
@export var alvo: CharacterBody2D

@export_group("Distâncias")
@export var distancia_ataque: float = 110.0
@export var distancia_minima: float = 40.0
@export var distancia_esquiva: float = 150.0
@export var distancia_pulo: float = 75.0

@export_group("Decisões")
@export var intervalo_decisao_minimo: float = 0.05
@export var intervalo_decisao_maximo: float = 0.10
@export_range(0.0, 1.0) var chance_esquivar: float = 0.75
@export_range(0.0, 1.0) var chance_atacar: float = 0.95

@export_group("Pulos")
@export var intervalo_pulo_minimo: float = 0.5
@export var intervalo_pulo_maximo: float = 0.9
@export_range(0.0, 1.0) var chance_pulo_esquiva: float = 0.40

@export_group("Ataques")
@export var alcance_vertical: float = 90.0

var personagem: CharacterBody2D
var sistema_ataque: Node2D
var ataque_jogador: Node2D

var estado: Estado = Estado.PERSEGUIR

var tempo_decisao: float = 0.0
var tempo_pulo: float = 0.0
var tempo_busca: float = 0.0
var reagiu_ao_golpe: bool = false


func _ready() -> void:
	randomize()

	personagem = get_parent() as CharacterBody2D

	if personagem == null:
		push_error("BOT IA: IA precisa ser filha de Bot!")
		return

	sistema_ataque = personagem.get_node_or_null("AtaqueBot")

	if sistema_ataque == null:
		push_error("BOT IA: AtaqueBot não encontrado!")
		return

	buscar_jogador()
	print("BOT IA: Dificuldade difícil iniciada!")


func _physics_process(delta: float) -> void:
	if not is_instance_valid(personagem) or not is_instance_valid(sistema_ataque):
		return

	tempo_decisao = maxf(tempo_decisao - delta, 0.0)
	tempo_pulo = maxf(tempo_pulo - delta, 0.0)
	tempo_busca = maxf(tempo_busca - delta, 0.0)

	if personagem.tempo_knockback > 0.0:
		return

	if not is_instance_valid(alvo):
		if tempo_busca <= 0.0:
			buscar_jogador()
			tempo_busca = 0.35

		personagem.definir_direcao(0.0)
		return

	atualizar_direcao()

	var jogador_atacando := verificar_ataque_jogador()
	if not jogador_atacando:
		if reagiu_ao_golpe:
			tempo_decisao = 0.0
		reagiu_ao_golpe = false

	if tempo_decisao <= 0.0:
		analisar_situacao(jogador_atacando)


func buscar_jogador() -> void:
	var encontrado = get_tree().get_first_node_in_group("jogador")

	if encontrado is CharacterBody2D:
		alvo = encontrado
		print("BOT IA: Jogador encontrado!")


func atualizar_direcao() -> void:
	var sprite = personagem.get_node_or_null("Sprite2D")

	if sprite == null:
		return

	sprite.flip_h = (
		alvo.global_position.x < personagem.global_position.x
	)


func analisar_situacao(jogador_atacando: bool) -> void:
	var diferenca_x: float = (
		alvo.global_position.x - personagem.global_position.x
	)

	var diferenca_y: float = (
		personagem.global_position.y - alvo.global_position.y
	)

	var distancia_x: float = absf(diferenca_x)
	var distancia_y: float = absf(diferenca_y)

	var direcao: float = signf(diferenca_x)

	# Reage uma vez por golpe e só quando a hitbox ameaça o bot.
	if (
		jogador_atacando
		and not reagiu_ao_golpe
		and distancia_x <= distancia_esquiva
		and distancia_y <= alcance_vertical
		and limites_colisao(ataque_jogador.hitbox).intersects(
			limites_colisao(personagem).grow(8.0)
		)
	):
		reagiu_ao_golpe = true
		if randf() <= chance_esquivar:
			esquivar(direcao)
			return

	# Persegue o jogador quando ele está em uma plataforma superior.
	if diferenca_y > distancia_pulo:
		perseguir(direcao)
		tentar_pular()
		return

	var deslocamento := Vector2(sistema_ataque.distancia_hitbox, 0.0)
	if direcao < 0.0:
		deslocamento.x *= -1.0
	var limites_golpe := limites_colisao(sistema_ataque.hitbox)
	limites_golpe.position += personagem.to_global(deslocamento) - sistema_ataque.hitbox.global_position
	if distancia_x > distancia_ataque or not limites_golpe.intersects(limites_colisao(alvo)):
		perseguir(direcao)
		return

	var em_recarga: bool = sistema_ataque.tempo_restante > 0.0
	if em_recarga and not sistema_ataque.atacando and distancia_x < distancia_minima:
		reposicionar(direcao)
		return

	var contra_ataque: bool = not jogador_atacando and is_instance_valid(ataque_jogador) and ataque_jogador.tempo_restante > 0.0
	combater(not em_recarga and not sistema_ataque.atacando, contra_ataque)


func limites_colisao(corpo: Node2D) -> Rect2:
	for filho in corpo.get_children():
		if filho is CollisionShape2D and filho.shape != null:
			return filho.global_transform * filho.shape.get_rect()
	return Rect2()


func verificar_ataque_jogador() -> bool:
	if not is_instance_valid(alvo):
		return false

	ataque_jogador = alvo.get_node_or_null("AtaquePlayer")

	if ataque_jogador == null:
		return false

	return ataque_jogador.atacando


func perseguir(direcao: float) -> void:
	estado = Estado.PERSEGUIR

	personagem.definir_direcao(direcao)

	tempo_decisao = randf_range(
		intervalo_decisao_minimo,
		intervalo_decisao_maximo
	)


func combater(pode_atacar: bool, contra_ataque: bool) -> void:
	estado = Estado.COMBATER

	personagem.definir_direcao(0.0)

	if pode_atacar and (contra_ataque or randf() <= chance_atacar):
		iniciar_ataque(contra_ataque)

	tempo_decisao = randf_range(intervalo_decisao_minimo, intervalo_decisao_maximo)


func esquivar(direcao: float) -> void:
	estado = Estado.ESQUIVAR

	personagem.definir_direcao(-direcao)

	if (
		personagem.is_on_floor()
		and randf() <= chance_pulo_esquiva
	):
		tentar_pular()

	tempo_decisao = randf_range(0.10, 0.16)

	print("BOT IA: Esquivando do ataque!")


func reposicionar(direcao: float) -> void:
	estado = Estado.REPOSICIONAR

	personagem.definir_direcao(-direcao)

	tempo_decisao = randf_range(intervalo_decisao_minimo, intervalo_decisao_maximo)


func tentar_pular() -> void:
	if tempo_pulo > 0.0:
		return

	if not personagem.is_on_floor():
		return

	personagem.solicitar_pulo()

	tempo_pulo = randf_range(
		intervalo_pulo_minimo,
		intervalo_pulo_maximo
	)


func iniciar_ataque(contra_ataque: bool) -> void:
	var sorteio: int = randi_range(1, 100)
	var tipo: int

	if contra_ataque:
		tipo = 3
	elif sorteio <= 45:
		tipo = 1
	elif sorteio <= 85:
		tipo = 2
	else:
		tipo = 3

	sistema_ataque.executar_ataque(tipo)

	print("BOT IA: Executando ataque ", tipo)
