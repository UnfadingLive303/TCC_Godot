
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
@export var tamanho_plataforma: Vector2 = Vector2(120, 12)
@export var deslocamento_plataforma_y: float = 50.0
@export var tempo_plataforma: float = 5.0

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

	print("================================")
	print("GERENCIADOR DE RESPAWN INICIADO")
	print("Vidas do jogador: ", vidas_jogador)
	print("Vidas do bot: ", vidas_bot)
	print("================================")


func verificar_configuracao() -> bool:
	if not is_instance_valid(jogador):
		push_error("Jogador não configurado no Inspector!")
		return false

	if not is_instance_valid(bot):
		push_error("Bot não configurado no Inspector!")
		return false

	if cena_jogador == null:
		push_error("Cena Personagem.tscn não configurada!")
		return false

	if cena_bot == null:
		push_error("Cena Bot.tscn não configurada!")
		return false

	if not is_instance_valid(spawner_jogador):
		push_error("PosicaoJogador não configurada!")
		return false

	if not is_instance_valid(spawner_bot):
		push_error("PosicaoBot não configurada!")
		return false

	return true


func configurar_personagem(personagem: CharacterBody2D, grupo: String) -> void:
	if not is_instance_valid(personagem):
		return

	personagem.add_to_group(grupo)

	# Garante que os personagens sejam detectados pelas hitboxes.
	personagem.collision_layer = personagem.collision_layer | 1

	# Mantém a colisão física com objetos da camada 1.
	personagem.collision_mask = personagem.collision_mask | 1

	personagem.velocity = Vector2.ZERO

	print("COLISÃO CONFIGURADA: ", personagem.name)

	verificar_sistemas_combate(personagem)


func verificar_sistemas_combate(personagem: CharacterBody2D) -> void:
	if personagem.is_in_group("jogador"):
		if personagem.find_child("AtaquePlayer", true, false) == null:
			push_error("AtaquePlayer não encontrado no jogador!")

		if personagem.find_child("VidaPlayer", true, false) == null:
			push_error("VidaPlayer não encontrado no jogador!")

	elif personagem.is_in_group("bot"):
		if personagem.find_child("AtaqueBot", true, false) == null:
			push_error("AtaqueBot não encontrado no bot!")

		if personagem.find_child("VidaBot", true, false) == null:
			push_error("VidaBot não encontrado no bot!")


func eliminar_personagem(personagem: CharacterBody2D) -> void:
	if not is_instance_valid(personagem):
		return

	var eh_jogador: bool = personagem.is_in_group("jogador")
	var eh_bot: bool = personagem.is_in_group("bot")

	if eh_jogador:
		if jogador_derrotado:
			return

		jogador_derrotado = true
		vidas_jogador -= 1

		print("JOGADOR ELIMINADO!")
		print("Vidas restantes: ", vidas_jogador)

		jogador = null
		personagem.queue_free()

		if vidas_jogador > 0:
			await get_tree().create_timer(tempo_respawn).timeout

			if is_inside_tree():
				await ressuscitar_jogador()
		else:
			print("JOGADOR SEM VIDAS! FIM DE JOGO.")

	elif eh_bot:
		if bot_derrotado:
			return

		bot_derrotado = true
		vidas_bot -= 1

		print("BOT ELIMINADO!")
		print("Vidas restantes: ", vidas_bot)

		bot = null
		personagem.queue_free()

		if vidas_bot > 0:
			await get_tree().create_timer(tempo_respawn).timeout

			if is_inside_tree():
				await ressuscitar_bot()
		else:
			print("BOT SEM VIDAS!")

	else:
		push_warning("Personagem não reconhecido: " + personagem.name)


func ressuscitar_jogador() -> void:
	var novo_jogador = cena_jogador.instantiate() as CharacterBody2D

	if novo_jogador == null:
		push_error("Falha ao instanciar Personagem.tscn!")
		return

	configurar_personagem(novo_jogador, "jogador")

	get_parent().add_child(novo_jogador)

	novo_jogador.global_position = spawner_jogador.global_position

	jogador = novo_jogador
	jogador_derrotado = false

	# Aguarda a física reconhecer o novo personagem.
	await get_tree().physics_frame

	if not is_instance_valid(jogador):
		return

	criar_plataforma(jogador)
	atualizar_alvo_bot()

	print("JOGADOR RESSUSCITOU!")
	print("Vidas disponíveis: ", vidas_jogador)


func ressuscitar_bot() -> void:
	var novo_bot = cena_bot.instantiate() as CharacterBody2D

	if novo_bot == null:
		push_error("Falha ao instanciar Bot.tscn!")
		return

	configurar_personagem(novo_bot, "bot")

	get_parent().add_child(novo_bot)

	novo_bot.global_position = spawner_bot.global_position

	bot = novo_bot
	bot_derrotado = false

	# Aguarda a física reconhecer o novo personagem.
	await get_tree().physics_frame

	if not is_instance_valid(bot):
		return

	atualizar_alvo_bot()
	criar_plataforma(bot)

	print("BOT RESSUSCITOU!")
	print("Vidas disponíveis: ", vidas_bot)


func atualizar_alvo_bot() -> void:
	if not is_instance_valid(bot):
		push_error("Gerenciador: Bot não existe!")
		return

	if not is_instance_valid(jogador):
		push_error("Gerenciador: Jogador não existe!")
		return

	var ia = bot.get_node_or_null("IA")

	if ia == null:
		push_error("Gerenciador: Nó IA não encontrado!")
		return

	ia.set("alvo", jogador)

	print("GERENCIADOR: Alvo do bot atualizado!")
	print("Bot: ", bot.name)
	print("Alvo: ", jogador.name)


func criar_plataforma(personagem: CharacterBody2D) -> void:
	if not is_instance_valid(personagem):
		return

	var plataforma := StaticBody2D.new()
	plataforma.name = "PlataformaTemporaria"

	plataforma.collision_layer = 1
	plataforma.collision_mask = 1

	var colisao := CollisionShape2D.new()
	var retangulo := RectangleShape2D.new()

	retangulo.size = tamanho_plataforma
	colisao.shape = retangulo

	plataforma.add_child(colisao)

	if sprite_plataforma != null:
		var sprite := Sprite2D.new()
		sprite.texture = sprite_plataforma

		var tamanho_textura = sprite_plataforma.get_size()

		if tamanho_textura.x > 0 and tamanho_textura.y > 0:
			sprite.scale = Vector2(
				tamanho_plataforma.x / tamanho_textura.x,
				tamanho_plataforma.y / tamanho_textura.y
			)

		plataforma.add_child(sprite)

	get_parent().add_child(plataforma)

	plataforma.global_position = (
		personagem.global_position
		+ Vector2(0, deslocamento_plataforma_y)
	)

	var sensor := Area2D.new()
	sensor.name = "SensorSaida"

	sensor.collision_layer = 0
	sensor.collision_mask = 1
	sensor.monitoring = true
	sensor.monitorable = false

	var forma_sensor := CollisionShape2D.new()
	var retangulo_sensor := RectangleShape2D.new()

	retangulo_sensor.size = Vector2(
		tamanho_plataforma.x + 40,
		130
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

	print("Plataforma temporária criada!")

	remover_plataforma_apos_tempo(plataforma)


func _on_plataforma_body_exited(
	corpo: Node2D,
	plataforma: StaticBody2D,
	personagem: CharacterBody2D
) -> void:
	if corpo != personagem:
		return

	if is_instance_valid(plataforma):
		print("Personagem saiu da plataforma!")
		plataforma.queue_free()


func remover_plataforma_apos_tempo(
	plataforma: StaticBody2D
) -> void:
	await get_tree().create_timer(tempo_plataforma).timeout

	if is_instance_valid(plataforma):
		print("Tempo da plataforma acabou!")
		plataforma.queue_free()
