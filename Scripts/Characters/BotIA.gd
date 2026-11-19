
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
@export var intervalo_decisao_minimo: float = 0.10
@export var intervalo_decisao_maximo: float = 0.22
@export_range(0.0, 1.0) var chance_esquivar: float = 0.90
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
	if not is_instance_valid(personagem):
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

	if tempo_decisao <= 0.0:
		analisar_situacao()


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


func analisar_situacao() -> void:
	var diferenca_x: float = (
		alvo.global_position.x - personagem.global_position.x
	)

	var diferenca_y: float = (
		personagem.global_position.y - alvo.global_position.y
	)

	var distancia_x: float = absf(diferenca_x)
	var distancia_y: float = absf(diferenca_y)

	var direcao: float = signf(diferenca_x)

	var jogador_atacando: bool = verificar_ataque_jogador()

	# Prioridade: esquivar de ataques próximos.
	if (
		jogador_atacando
		and distancia_x <= distancia_esquiva
		and distancia_y <= alcance_vertical
		and randf() <= chance_esquivar
	):
		esquivar(direcao)
		return

	# Persegue o jogador quando ele está em uma plataforma superior.
	if diferenca_y > distancia_pulo:
		perseguir(direcao)
		tentar_pular()
		return

	# Aproxima-se rapidamente quando está longe.
	if distancia_x > distancia_ataque:
		perseguir(direcao)
		return

	# Evita ficar colado no jogador.
	if distancia_x < distancia_minima:
		reposicionar(direcao)
		return

	# Ataca quando encontra uma oportunidade.
	combater()


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


func combater() -> void:
	estado = Estado.COMBATER

	personagem.definir_direcao(0.0)

	if (
		not sistema_ataque.atacando
		and sistema_ataque.tempo_restante <= 0.0
		and randf() <= chance_atacar
	):
		iniciar_ataque()

	tempo_decisao = randf_range(0.12, 0.25)


func esquivar(direcao: float) -> void:
	estado = Estado.ESQUIVAR

	personagem.definir_direcao(-direcao)

	if (
		personagem.is_on_floor()
		and randf() <= chance_pulo_esquiva
	):
		tentar_pular()

	tempo_decisao = randf_range(0.18, 0.30)

	print("BOT IA: Esquivando do ataque!")


func reposicionar(direcao: float) -> void:
	estado = Estado.REPOSICIONAR

	personagem.definir_direcao(-direcao)

	tempo_decisao = randf_range(0.15, 0.25)


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


func iniciar_ataque() -> void:
	var sorteio: int = randi_range(1, 100)
	var tipo: int

	if sorteio <= 45:
		tipo = 1
	elif sorteio <= 85:
		tipo = 2
	else:
		tipo = 3

	sistema_ataque.executar_ataque(tipo)

	print("BOT IA: Executando ataque ", tipo)
