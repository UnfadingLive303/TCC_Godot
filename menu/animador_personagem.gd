class_name AnimadorPersonagem
extends Node2D
## Sprites + animações do jogador e do bot (idle, correr, pular, cair,
## ataque1, ataque2, ataque aéreo e dano).
##
## Instalação automática: o gerenciador_respawn chama AnimadorPersonagem.instalar(...)
## em cada personagem (também nos que ressuscitam). O animador:
##  - cria o AnimatedSprite2D a partir da spritesheet e ajusta tamanho/posição à colisão;
##  - escolhe a animação sozinho (velocity, is_on_floor, dano da Repulsao);
##  - detecta o ataque sozinho quando possível (veja "detectar_ataques"), ou
##    você chama  animador.atacar()  no seu script de ataque.
##
## Sinais úteis: impacto(animacao) quando o golpe "acerta" (frame do impacto).

signal impacto(animacao: StringName)
signal ataque_iniciado(animacao: StringName)
signal ataque_terminado

const PASTA_SPRITES := "res://menu/sprites/"
const LARGURA_FRAME := 224
const ALTURA_FRAME := 160
const ALTURA_PERSONAGEM := 112.0   # altura do boneco dentro do frame (px)
const PE_Y_NO_FRAME := 140.0       # linha dos pés dentro do frame

const ANIMACOES := {
	"idle": {"linha": 0, "frames": 4, "fps": 6.0, "loop": true},
	"correr": {"linha": 1, "frames": 6, "fps": 12.0, "loop": true},
	"pular": {"linha": 2, "frames": 2, "fps": 8.0, "loop": false},
	"cair": {"linha": 3, "frames": 2, "fps": 8.0, "loop": true},
	"ataque1": {"linha": 4, "frames": 5, "fps": 16.0, "loop": false},
	"ataque2": {"linha": 5, "frames": 6, "fps": 14.0, "loop": false},
	"ataque_aereo": {"linha": 6, "frames": 4, "fps": 14.0, "loop": false},
	"dano": {"linha": 7, "frames": 2, "fps": 10.0, "loop": false},
}
# frame (começando em 0) em que o golpe realmente "acerta"
const FRAME_IMPACTO := {"ataque1": 2, "ataque2": 3, "ataque_aereo": 1}

# --- CONFIGURAÇÕES ---
@export var grupo: String = "jogador"             # "jogador" ou "bot" (escolhe a spritesheet)
@export var caminho_spritesheet: String = ""      # opcional: usar outra spritesheet
@export var fator_altura: float = 1.15            # altura do boneco = altura da colisão x isso
@export var ajuste_escala: float = 1.0            # multiplicador extra de tamanho
@export var ajuste_posicao: Vector2 = Vector2.ZERO
@export var esconder_sprites_antigos: bool = true # esconde Sprite2D/AnimatedSprite2D que já existiam
@export var detectar_ataques: bool = true         # tenta detectar o ataque sozinho (veja abaixo)
@export var acoes_ataque: PackedStringArray = ["attack", "ataque", "atacar", "golpe", "soco"]
@export var janela_combo: float = 0.55            # segundos para encadear ataque1 -> ataque2

var _corpo: CharacterBody2D
var _sprite: AnimatedSprite2D
var _rep: Repulsao = null
var _atacando := false
var _anim_ataque := ""
var _ultimo_golpe := ""
var _fim_ataque_ms := 0
var _t_gatilho := 0
var _buffer_combo := false
var _tempo_dano := 0.0
var _direcao := 1
var _busca_rep := 0.0
var _sensores: Array[Dictionary] = []


## Cria o animador no personagem, se ainda não existir.
static func instalar(personagem: CharacterBody2D, grupo_: String) -> AnimadorPersonagem:
	if personagem == null or not is_instance_valid(personagem):
		return null
	var existente := personagem.find_child("AnimadorPersonagem", true, false) as AnimadorPersonagem
	if existente != null:
		return existente
	var a := AnimadorPersonagem.new()
	a.name = "AnimadorPersonagem"
	a.grupo = grupo_
	personagem.add_child(a)
	return a


func _ready() -> void:
	_corpo = get_parent() as CharacterBody2D
	if _corpo == null:
		push_error("AnimadorPersonagem precisa ser filho de um CharacterBody2D.")
		set_physics_process(false)
		return
	if not _construir_sprite():
		set_physics_process(false)
		return
	_ajustar_ao_corpo()
	if esconder_sprites_antigos:
		_esconder_antigos()
	if detectar_ataques:
		_preparar_deteccao_de_ataques()
	_sprite.play("idle")


# ---------------------------------------------------------------- construção

func _construir_sprite() -> bool:
	var caminho := caminho_spritesheet
	if caminho == "":
		caminho = PASTA_SPRITES + "spritesheet_%s.png" % grupo
	var textura := load(caminho) as Texture2D
	if textura == null:
		push_error("AnimadorPersonagem: spritesheet não encontrada: " + caminho)
		return false

	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for nome in ANIMACOES:
		var info: Dictionary = ANIMACOES[nome]
		frames.add_animation(nome)
		frames.set_animation_speed(nome, info["fps"])
		frames.set_animation_loop(nome, info["loop"])
		for i in range(info["frames"]):
			var atlas := AtlasTexture.new()
			atlas.atlas = textura
			atlas.region = Rect2(i * LARGURA_FRAME, info["linha"] * ALTURA_FRAME, LARGURA_FRAME, ALTURA_FRAME)
			frames.add_frame(nome, atlas)

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.animation_finished.connect(_ao_terminar_animacao)
	_sprite.frame_changed.connect(_ao_mudar_frame)
	add_child(_sprite)
	return true


## Escala o sprite pela altura da colisão e alinha os pés do boneco aos pés da colisão.
func _ajustar_ao_corpo() -> void:
	var altura_colisao := 64.0
	var pe_y := 32.0
	var centro_x := 0.0

	var forma := _corpo.find_child("CollisionShape2D", true, false) as CollisionShape2D
	if forma != null and forma.shape != null:
		var limites: Rect2 = forma.shape.get_rect()
		var rel := forma.global_scale.y / _corpo.global_scale.y
		var local := _corpo.to_local(forma.global_position)
		altura_colisao = limites.size.y * absf(rel)
		pe_y = local.y + limites.end.y * rel
		centro_x = local.x

	var esc := (altura_colisao * fator_altura * ajuste_escala) / ALTURA_PERSONAGEM
	_sprite.scale = Vector2(esc, esc)
	# o frame é centrado; os pés ficam (PE_Y_NO_FRAME - metade da altura) abaixo do centro
	var pes_abaixo_do_centro := (PE_Y_NO_FRAME - ALTURA_FRAME / 2.0) * esc
	_sprite.position = Vector2(centro_x, pe_y - pes_abaixo_do_centro) + ajuste_posicao


func _esconder_antigos() -> void:
	for tipo in ["Sprite2D", "AnimatedSprite2D"]:
		for no in _corpo.find_children("*", tipo, true, false):
			if no == _sprite or is_ancestor_of(no):
				continue
			(no as CanvasItem).visible = false


# ---------------------------------------------- detecção automática do ataque

func _preparar_deteccao_de_ataques() -> void:
	var nome := "AtaquePlayer" if grupo == "jogador" else "AtaqueBot"
	var no := _corpo.find_child(nome, true, false)
	if no == null:
		return

	# 1) sinais do nó de ataque cujo nome indica "ataque" (ex.: atacou, ataque_iniciado)
	for info in no.get_signal_list():
		if not _sinal_de_ataque(String(info["name"]).to_lower()):
			continue
		var qtd := (info["args"] as Array).size()
		var chamada := Callable(self, "atacar").unbind(qtd)
		if not no.is_connected(info["name"], chamada):
			no.connect(info["name"], chamada)

	# 2) hitbox sendo ligada: Area2D.monitoring ou CollisionShape2D.disabled
	var candidatos: Array[Node] = [no]
	candidatos.append_array(no.find_children("*", "Area2D", true, false))
	candidatos.append_array(no.find_children("*", "CollisionShape2D", true, false))
	for c in candidatos:
		if c is Area2D:
			_sensores.append({"no": c, "prop": "monitoring", "invertido": false, "antes": bool(c.monitoring)})
		elif c is CollisionShape2D:
			_sensores.append({"no": c, "prop": "disabled", "invertido": true, "antes": not bool(c.disabled)})


func _sinal_de_ataque(s: String) -> bool:
	var inclui := ["atac", "ataq", "attack", "golpe", "soco", "chute"]
	var exclui := ["acert", "atingi", "dano", "damage", "hurt", "hit", "final", "termin",
			"fim", "end", "finish", "recarreg", "cooldown", "pronto"]
	var ok := false
	for t in inclui:
		if s.contains(t):
			ok = true
	if not ok:
		return false
	for t in exclui:
		if s.contains(t):
			return false
	return true


func _atualizar_sensores() -> void:
	for sensor in _sensores:
		var no = sensor["no"]
		if not is_instance_valid(no):
			continue
		var valor := bool(no.get(sensor["prop"]))
		var ativo := (not valor) if sensor["invertido"] else valor
		if ativo and not sensor["antes"]:
			atacar()
		sensor["antes"] = ativo


func _unhandled_input(evento: InputEvent) -> void:
	if not detectar_ataques or grupo != "jogador":
		return
	for acao in acoes_ataque:
		if InputMap.has_action(acao) and evento.is_action_pressed(acao):
			atacar()
			return


# ------------------------------------------------------------------- ataque

## Toca a animação de ataque. Chame isto no seu script de ataque se a detecção
## automática não pegar. "tipo" opcional: "ataque1", "ataque2" ou "ataque_aereo".
func atacar(tipo: String = "") -> void:
	if _corpo == null or _sprite == null:
		return
	var agora := Time.get_ticks_msec()
	if agora - _t_gatilho < 120:   # ignora gatilhos duplicados (sinal + input etc.)
		return
	_t_gatilho = agora

	if _atacando:
		if _anim_ataque == "ataque1" and tipo == "":
			_buffer_combo = true   # apertou de novo durante o golpe 1: encadeia o golpe 2
		return

	if tipo == "":
		if not _corpo.is_on_floor():
			tipo = "ataque_aereo"
		elif _ultimo_golpe == "ataque1" and (agora - _fim_ataque_ms) / 1000.0 < janela_combo:
			tipo = "ataque2"
		else:
			tipo = "ataque1"
	_iniciar_ataque(tipo)


func _iniciar_ataque(tipo: String) -> void:
	_atacando = true
	_anim_ataque = tipo
	_buffer_combo = false
	var inimigo := _achar_inimigo()
	if inimigo != null:
		_direcao = 1 if inimigo.global_position.x >= _corpo.global_position.x else -1
	_sprite.flip_h = _direcao < 0
	_sprite.play(tipo)
	ataque_iniciado.emit(tipo)


func _ao_terminar_animacao() -> void:
	var nome := String(_sprite.animation)
	if _atacando and nome == _anim_ataque:
		_atacando = false
		_ultimo_golpe = nome
		_fim_ataque_ms = Time.get_ticks_msec()
		ataque_terminado.emit()
		if _buffer_combo and nome == "ataque1" and _corpo.is_on_floor():
			_buffer_combo = false
			_t_gatilho = 0
			_iniciar_ataque("ataque2")


func _ao_mudar_frame() -> void:
	if _atacando and FRAME_IMPACTO.get(String(_sprite.animation), -1) == _sprite.frame:
		impacto.emit(_sprite.animation)


# ------------------------------------------------------------ estado / dano

func _physics_process(delta: float) -> void:
	if _corpo == null:
		return
	_atualizar_sensores()
	_buscar_repulsao(delta)

	if _tempo_dano > 0.0:
		_tempo_dano -= delta
		if _rep != null and is_instance_valid(_rep) and _rep.atordoado:
			_tempo_dano = maxf(_tempo_dano, 0.08)   # continua em "dano" enquanto voa
		_atacando = false
		_tocar("dano")
	elif not _atacando:
		if not _corpo.is_on_floor():
			_tocar("pular" if _corpo.velocity.y < 0.0 else "cair")
		elif absf(_corpo.velocity.x) > 20.0:
			_tocar("correr")
		else:
			_tocar("idle")

	_atualizar_direcao()


func _tocar(nome: String) -> void:
	if String(_sprite.animation) != nome:
		_sprite.play(nome)


func _atualizar_direcao() -> void:
	if not _atacando and _tempo_dano <= 0.0:
		var vx := _corpo.velocity.x
		if absf(vx) > 15.0:
			_direcao = 1 if vx > 0.0 else -1
		else:
			var inimigo := _achar_inimigo()
			if inimigo != null:
				_direcao = 1 if inimigo.global_position.x >= _corpo.global_position.x else -1
	_sprite.flip_h = _direcao < 0


func _achar_inimigo() -> Node2D:
	var outro := "bot" if grupo == "jogador" else "jogador"
	var no := get_tree().get_first_node_in_group(outro) as Node2D
	if no == _corpo:
		return null
	return no


func _buscar_repulsao(delta: float) -> void:
	if _rep != null and is_instance_valid(_rep):
		return
	_busca_rep -= delta
	if _busca_rep > 0.0:
		return
	_busca_rep = 0.2
	_rep = _corpo.find_child("Repulsao", true, false) as Repulsao
	if _rep != null:
		_rep.porcentagem_alterada.connect(_ao_dano)


func _ao_dano(nova: float, anterior: float) -> void:
	if nova <= anterior:
		return
	_tempo_dano = 0.32
	_atacando = false
	_buffer_combo = false
	var t := create_tween()
	t.tween_property(_sprite, "modulate", Color.WHITE, 0.22).from(Color(2.5, 2.2, 2.2))
