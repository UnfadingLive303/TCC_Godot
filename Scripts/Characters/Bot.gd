
extends CharacterBody2D

@export_group("Movimentação")
@export var velocidade: float = 350.0
@export var forca_pulo: float = -500.0
@export var gravidade: float = 1200.0
@export var max_pulos: int = 2

@export_group("Knockback")
@export var tempo_recuperacao: float = 0.25

var pulos_realizados: int = 0
var direcao_movimento: float = 0.0
var pulo_solicitado: bool = false
var tempo_knockback: float = 0.0


func _physics_process(delta: float) -> void:
	aplicar_gravidade(delta)

	if tempo_knockback > 0.0:
		tempo_knockback = maxf(
			tempo_knockback - delta,
			0.0
		)
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
	velocity.x = direcao_movimento * velocidade

	atualizar_direcao_sprite()


func atualizar_direcao_sprite() -> void:
	var sprite = get_node_or_null("Sprite2D")

	if sprite == null:
		return

	if absf(direcao_movimento) > 0.01:
		sprite.flip_h = direcao_movimento < 0.0


func executar_pulo() -> void:
	if not pulo_solicitado:
		return

	pulo_solicitado = false

	if pulos_realizados < max_pulos:
		velocity.y = forca_pulo
		pulos_realizados += 1

		print(
			"BOT: Pulo realizado! ",
			pulos_realizados,
			"/",
			max_pulos
		)


func definir_direcao(valor: float) -> void:
	direcao_movimento = clampf(valor, -1.0, 1.0)


func solicitar_pulo() -> void:
	pulo_solicitado = true


func receber_knockback(
	direcao: Vector2,
	forca: float
) -> void:
	if direcao == Vector2.ZERO:
		return

	velocity = direcao.normalized() * forca

	tempo_knockback = tempo_recuperacao
	direcao_movimento = 0.0
	pulo_solicitado = false

	print("BOT: Recebeu knockback!")
