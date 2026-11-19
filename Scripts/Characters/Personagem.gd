
extends CharacterBody2D

@export_group("Movimentação")
@export var velocidade: float = 350.0
@export var forca_pulo: float = -500.0
@export var gravidade: float = 1200.0
@export var max_pulos: int = 2

@export_group("Controles")
@export var acao_esquerda: StringName = &"p1_esquerda"
@export var acao_direita: StringName = &"p1_direita"
@export var acao_pulo: StringName = &"p1_pulo"

@export_group("Inteligência Artificial")
@export var controle_por_ia: bool = false

@export_group("Knockback")
@export var tempo_recuperacao: float = 0.25

var pulos_realizados: int = 0
var direcao_externa: float = 0.0
var pulo_solicitado: bool = false
var tempo_knockback: float = 0.0


func _physics_process(delta: float) -> void:
	aplicar_gravidade(delta)

	if tempo_knockback > 0.0:
		tempo_knockback = maxf(tempo_knockback - delta, 0.0)
	else:
		movimentar()
		executar_pulo()

	move_and_slide()


func aplicar_gravidade(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravidade * delta
	else:
		pulos_realizados = 0



func movimentar() -> void:
	var direcao: float = 0.0

	if controle_por_ia:
		direcao = direcao_externa
	else:
		direcao = Input.get_axis(
			acao_esquerda,
			acao_direita
		)

	velocity.x = direcao * velocidade

	if not controle_por_ia and absf(direcao) > 0.01:
		var sprite = get_node_or_null("Sprite2D")

		if sprite != null:
			sprite.flip_h = direcao < 0.0


func executar_pulo() -> void:
	var pediu_pulo: bool = false

	if controle_por_ia:
		pediu_pulo = pulo_solicitado
		pulo_solicitado = false
	else:
		pediu_pulo = Input.is_action_just_pressed(acao_pulo)

	if pediu_pulo and pulos_realizados < max_pulos:
		velocity.y = forca_pulo
		pulos_realizados += 1


func solicitar_pulo() -> void:
	pulo_solicitado = true


func receber_knockback(direcao: Vector2, forca: float) -> void:
	if direcao == Vector2.ZERO:
		return

	velocity = direcao.normalized() * forca
	tempo_knockback = tempo_recuperacao

	direcao_externa = 0.0
	pulo_solicitado = false

	print("Personagem recebeu knockback! Força: ", forca)
