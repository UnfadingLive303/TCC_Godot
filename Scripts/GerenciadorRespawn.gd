
extends Node

@export_group("Personagens")
@export var jogador: CharacterBody2D
@export var bot: CharacterBody2D

@export_group("Cenas")
@export var cena_jogador: PackedScene
@export var cena_bot: PackedScene

@export_group("Spawners")
@export var spawner_jogador: Marker2D
@export var spawner_bot: Marker2D

@export_group("Vidas e tempo")
@export var vidas_maximas: int = 3
@export var tempo_respawn: float = 1.5

@export_group("Plataforma temporária")
@export var sprite_plataforma: Texture2D
@export var tamanho_visual_plataforma: Vector2 = Vector2(250, 150)
@export var tamanho_colisao_plataforma: Vector2 = Vector2(130, 50)
@export var folga_plataforma: float = 0.0
@export var tempo_plataforma: float = 5.0
@export var altura_fallback_personagem: float = 64.0

@export_group("Sensor da plataforma")
@export var margem_sensor: float = 30.0
@export var altura_sensor: float = 80.0

var vidas_jogador: int = 0
var vidas_bot: int = 0

var jogador_derrotado: bool = false
var bot_derrotado: bool = false


func _ready() -> void:
	add_to_group("gerenciador_respawn")

	if not verificar_configuracao():
		return

	vidas_jogador = vidas_maximas
	vidas_bot = vidas_maximas

	configurar_personagem(jogador, "jogador")
	configurar_personagem(bot, "bot")

	jogador.global_position = spawner_jogador.global_position
	bot.global_position = spawner_bot.global_position

	atualizar_alvo_bot()

	print("GERENCIADOR DE RESPAWN INICIADO!")


func verificar_configuracao() -> bool:
	if not is_instance_valid(jogador):
		push_error("Jogador não configurado!")
		return false

	if not is_instance_valid(bot):
		push_error("Bot não configurado!")
		return false

	if cena_jogador == null or cena_bot == null:
		push_error("Cenas dos personagens não configuradas!")
		return false

	if not is_instance_valid(spawner_jogador):
		push_error("PosicaoJogador não configurada!")
		return false

	if not is_instance_valid(spawner_bot):
		push_error("PosicaoBot não configurada!")
		return false

	return true


func configurar_personagem(
	personagem: CharacterBody2D,
	grupo: String
) -> void:
	if not is_instance_valid(personagem):
		return

	personagem.add_to_group(grupo)
	personagem.collision_layer |= 1
	personagem.collision_mask |= 1
	personagem.velocity = Vector2.ZERO

	verificar_sistemas_combate(personagem)

	call_deferred("aplicar_excecoes_colisao")


func verificar_sistemas_combate(
	personagem: CharacterBody2D
) -> void:
	if personagem.is_in_group("jogador"):
		if personagem.find_child("AtaquePlayer", true, false) == null:
			push_error("AtaquePlayer não encontrado!")

		if personagem.find_child("VidaPlayer", true, false) == null:
			push_error("VidaPlayer não encontrado!")

	elif personagem.is_in_group("bot"):
		if personagem.find_child("AtaqueBot", true, false) == null:
			push_error("AtaqueBot não encontrado!")

		if personagem.find_child("VidaBot", true, false) == null:
			push_error("VidaBot não encontrado!")


func aplicar_excecoes_colisao() -> void:
	var jogadores = get_tree().get_nodes_in_group("jogador")
	var bots = get_tree().get_nodes_in_group("bot")

	for personagem_jogador in jogadores:
		for personagem_bot in bots:
			if not is_instance_valid(personagem_jogador):
				continue

			if not is_instance_valid(personagem_bot):
				continue

			personagem_jogador.add_collision_exception_with(
				personagem_bot
			)

			personagem_bot.add_collision_exception_with(
				personagem_jogador
			)


func eliminar_personagem(personagem: CharacterBody2D) -> void:
	if not is_instance_valid(personagem):
		return

	var eh_jogador = personagem.is_in_group("jogador")
	var eh_bot = personagem.is_in_group("bot")

	if eh_jogador:
		if jogador_derrotado:
			return

		jogador_derrotado = true
		vidas_jogador -= 1
		jogador = null
		personagem.queue_free()

		print("JOGADOR ELIMINADO! Vidas: ", vidas_jogador)

		if vidas_jogador > 0:
			await get_tree().create_timer(tempo_respawn).timeout

			if is_inside_tree():
				await ressuscitar_jogador()
		else:
			print("JOGADOR SEM VIDAS!")

	elif eh_bot:
		if bot_derrotado:
			return

		bot_derrotado = true
		vidas_bot -= 1
		bot = null
		personagem.queue_free()

		print("BOT ELIMINADO! Vidas: ", vidas_bot)

		if vidas_bot > 0:
			await get_tree().create_timer(tempo_respawn).timeout

			if is_inside_tree():
				await ressuscitar_bot()
		else:
			print("BOT SEM VIDAS!")


func ressuscitar_jogador() -> void:
	var novo_jogador = cena_jogador.instantiate() as CharacterBody2D

	if novo_jogador == null:
		push_error("Falha ao criar jogador!")
		return

	get_parent().add_child(novo_jogador)

	configurar_personagem(novo_jogador, "jogador")

	novo_jogador.global_position = spawner_jogador.global_position
	novo_jogador.velocity = Vector2.ZERO

	jogador = novo_jogador
	jogador_derrotado = false

	await get_tree().physics_frame

	if not is_instance_valid(jogador):
		return

	criar_plataforma(jogador)
	atualizar_alvo_bot()

	print("JOGADOR RESSUSCITOU!")


func ressuscitar_bot() -> void:
	var novo_bot = cena_bot.instantiate() as CharacterBody2D

	if novo_bot == null:
		push_error("Falha ao criar bot!")
		return

	get_parent().add_child(novo_bot)

	configurar_personagem(novo_bot, "bot")

	novo_bot.global_position = spawner_bot.global_position
	novo_bot.velocity = Vector2.ZERO

	bot = novo_bot
	bot_derrotado = false

	await get_tree().physics_frame

	if not is_instance_valid(bot):
		return

	criar_plataforma(bot)
	atualizar_alvo_bot()

	print("BOT RESSUSCITOU!")


func atualizar_alvo_bot() -> void:
	if not is_instance_valid(bot):
		return

	if not is_instance_valid(jogador):
		return

	var ia = bot.get_node_or_null("IA")

	if ia == null:
		push_error("Nó IA não encontrado!")
		return

	ia.set("alvo", jogador)


func obter_posicao_dos_pes(
	personagem: CharacterBody2D
) -> float:
	var forma = personagem.find_child(
		"CollisionShape2D",
		true,
		false
	) as CollisionShape2D

	if forma == null or forma.shape == null:
		return (
			personagem.global_position.y
			+ altura_fallback_personagem / 2.0
		)

	var limites: Rect2 = forma.shape.get_rect()
	var escala_y: float = forma.global_scale.y

	return (
		forma.global_position.y
		+ limites.end.y * escala_y
	)


func criar_plataforma(personagem: CharacterBody2D) -> void:
	if not is_instance_valid(personagem):
		return

	var plataforma := StaticBody2D.new()
	plataforma.name = "PlataformaTemporaria"

	plataforma.collision_layer = 1
	plataforma.collision_mask = 0

	# COLISÃO: 130 x 50.
	var colisao := CollisionShape2D.new()
	var retangulo := RectangleShape2D.new()

	retangulo.size = tamanho_colisao_plataforma
	colisao.shape = retangulo

	plataforma.add_child(colisao)

	# SPRITE: 250 x 150.
	if sprite_plataforma != null:
		var sprite := Sprite2D.new()
		sprite.texture = sprite_plataforma

		var tamanho_textura: Vector2 = sprite_plataforma.get_size()

		if tamanho_textura.x > 0 and tamanho_textura.y > 0:
			sprite.scale = Vector2(
				tamanho_visual_plataforma.x / tamanho_textura.x,
				tamanho_visual_plataforma.y / tamanho_textura.y
			)

		plataforma.add_child(sprite)

	get_parent().add_child(plataforma)

	# Posiciona a superfície da colisão na altura dos pés.
	var pe_y: float = obter_posicao_dos_pes(personagem)

	var meia_altura: float = tamanho_colisao_plataforma.y / 2.0

	plataforma.global_position = Vector2(
		personagem.global_position.x,
		pe_y + meia_altura + folga_plataforma
	)

	# Sensor de saída independente.
	var sensor := Area2D.new()
	sensor.name = "SensorSaida"

	sensor.collision_layer = 0
	sensor.collision_mask = 1
	sensor.monitoring = true
	sensor.monitorable = false

	var forma_sensor := CollisionShape2D.new()
	var retangulo_sensor := RectangleShape2D.new()

	retangulo_sensor.size = Vector2(
		tamanho_colisao_plataforma.x + margem_sensor,
		altura_sensor
	)

	forma_sensor.shape = retangulo_sensor
	sensor.add_child(forma_sensor)

	plataforma.add_child(sensor)

	sensor.body_exited.connect(
		_on_plataforma_body_exited.bind(
			plataforma,
			personagem
		)
	)

	print("PLATAFORMA CRIADA!")
	print("Tamanho visual: ", tamanho_visual_plataforma)
	print("Tamanho da colisão: ", tamanho_colisao_plataforma)

	remover_plataforma_apos_tempo(plataforma)


func _on_plataforma_body_exited(
	corpo: Node2D,
	plataforma: StaticBody2D,
	personagem: CharacterBody2D
) -> void:
	if corpo != personagem:
		return

	if is_instance_valid(plataforma):
		print("PERSONAGEM SAIU DA PLATAFORMA!")
		plataforma.queue_free()


func remover_plataforma_apos_tempo(
	plataforma: StaticBody2D
) -> void:
	await get_tree().create_timer(tempo_plataforma).timeout

	if is_instance_valid(plataforma):
		plataforma.queue_free()
		print("PLATAFORMA REMOVIDA!")
