extends Control
## Menu principal "Rivals Arena" animado (Godot 4.x)
## Anexe este script ao nó raiz (Control) da cena do menu e defina-a como Main Scene.
## Requer também o arquivo transicao.gd (classe TransicaoCena) na mesma pasta.

# --- CONFIGURAÇÕES: ajuste aqui ---
const CENA_ARENA := "res://Scenes/arena.tscn"                    # caminho da sua cena "arena"
const URL_COMUNIDADE := "https://rivals-arena-beta.vercel.app"  # link do site/comunidade
const PASTA := "res://menu/"                              # pasta onde estão as imagens

# Tamanho da arte original (base para posicionar tudo proporcionalmente)
const LARGURA_ARTE := 1671.0
const ALTURA_ARTE := 941.0

# Posição de cada botão na arte: [x, y, largura, altura]
const POS_JOGAR := Rect2(45, 363, 484, 98)
const POS_COMUNIDADE := Rect2(38, 451, 448, 91)
const POS_SAIR := Rect2(38, 539, 448, 91)

# --- Ajustes de animação ---
const ESCALA_FUNDO := 1.05      # zoom base do fundo (precisa ser > 1 para o parallax não mostrar bordas)
const RESPIRACAO := 0.035       # quanto o fundo "respira" (zoom lento em loop)
const PARALAXE := 14.0          # deslocamento máximo do fundo seguindo o mouse (px)
const DESLOC_HOVER := 14.0      # quanto o botão desliza para a direita no hover (px)

var _cena: Control
var _fundo: TextureRect
var _particulas: CPUParticles2D
var _flash: ColorRect
var _botoes: Array[TextureButton] = []
var _tweens: Dictionary = {}    # botão -> Tween do hover
var _respiracao: Tween
var _pulso: Tween
var _b_jogar: TextureButton
var _deslocamento := Vector2.ZERO
var _pronto := false            # terminou a animação de entrada
var _saindo := false            # já clicou em jogar/sair


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Faixas pretas caso a janela não tenha a mesma proporção da arte
	var preto := ColorRect.new()
	preto.color = Color.BLACK
	preto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(preto)

	var proporcao := AspectRatioContainer.new()
	proporcao.ratio = LARGURA_ARTE / ALTURA_ARTE
	proporcao.stretch_mode = AspectRatioContainer.STRETCH_FIT
	proporcao.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(proporcao)

	_cena = Control.new()
	_cena.clip_contents = true   # o zoom do fundo não vaza para as faixas pretas
	proporcao.add_child(_cena)

	_criar_fundo()
	_criar_particulas()

	_b_jogar = _criar_botao("jogar", POS_JOGAR, _ao_jogar)
	_criar_botao("comunidade", POS_COMUNIDADE, _ao_comunidade)
	_criar_botao("sair", POS_SAIR, _ao_sair)

	_flash = ColorRect.new()
	_flash.color = Color(1.0, 0.85, 0.4, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cena.add_child(_flash)

	_animar_entrada()


func _process(delta: float) -> void:
	if _fundo == null:
		return
	# Parallax: o fundo acompanha levemente o mouse
	var tela := get_viewport_rect().size
	var alvo := Vector2.ZERO
	if tela.x > 0.0 and tela.y > 0.0:
		alvo = (get_viewport().get_mouse_position() / tela - Vector2(0.5, 0.5)) * -2.0 * PARALAXE
	_deslocamento = _deslocamento.lerp(alvo, 1.0 - exp(-4.0 * delta))
	_fundo.position = _deslocamento


# ---------------------------------------------------------------- construção

func _criar_fundo() -> void:
	_fundo = TextureRect.new()
	_fundo.texture = load(PASTA + "fundo_menu.png")
	_fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fundo.stretch_mode = TextureRect.STRETCH_SCALE
	_fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo.resized.connect(func() -> void: _fundo.pivot_offset = _fundo.size / 2.0)
	_cena.add_child(_fundo)


func _criar_particulas() -> void:
	# Faíscas douradas/roxas subindo pela arena
	var gradiente := Gradient.new()
	gradiente.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	gradiente.colors = PackedColorArray([
		Color(1.0, 0.78, 0.2, 0.0),
		Color(1.0, 0.78, 0.2, 0.9),
		Color(0.72, 0.42, 1.0, 0.6),
		Color(0.72, 0.42, 1.0, 0.0),
	])

	_particulas = CPUParticles2D.new()
	_particulas.amount = 90
	_particulas.lifetime = 9.0
	_particulas.preprocess = 8.0
	_particulas.local_coords = false
	_particulas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particulas.emission_rect_extents = Vector2(800, 4)
	_particulas.direction = Vector2(0, -1)
	_particulas.spread = 14.0
	_particulas.gravity = Vector2.ZERO
	_particulas.initial_velocity_min = 70.0
	_particulas.initial_velocity_max = 150.0
	_particulas.scale_amount_min = 2.0
	_particulas.scale_amount_max = 5.0
	_particulas.color_ramp = gradiente
	_cena.add_child(_particulas)

	_cena.resized.connect(_ajustar_particulas)
	_ajustar_particulas.call_deferred()


func _ajustar_particulas() -> void:
	var tam := _cena.size
	_particulas.position = Vector2(tam.x * 0.5, tam.y + 10.0)
	_particulas.emission_rect_extents = Vector2(maxf(tam.x * 0.5, 1.0), 4.0)


func _criar_botao(nome: String, area: Rect2, acao: Callable) -> TextureButton:
	var normal: Texture2D = load(PASTA + "botoes/%s_normal.png" % nome)
	var destaque: Texture2D = load(PASTA + "botoes/%s_hover.png" % nome)

	var b := TextureButton.new()
	b.texture_normal = normal
	b.texture_hover = destaque
	b.texture_focused = destaque
	b.texture_pressed = destaque
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.modulate.a = 0.0   # começa invisível; a animação de entrada faz surgir

	# Posição proporcional: acompanha o tamanho da janela
	b.anchor_left = area.position.x / LARGURA_ARTE
	b.anchor_right = (area.position.x + area.size.x) / LARGURA_ARTE
	b.anchor_top = area.position.y / ALTURA_ARTE
	b.anchor_bottom = (area.position.y + area.size.y) / ALTURA_ARTE
	b.offset_left = 0
	b.offset_right = 0
	b.offset_top = 0
	b.offset_bottom = 0

	b.pressed.connect(acao)
	# O mouse move o foco, então só um botão fica destacado por vez
	b.mouse_entered.connect(func() -> void:
		if _pronto and not _saindo:
			b.grab_focus())
	b.focus_entered.connect(_hover.bind(b, true))
	b.focus_exited.connect(_hover.bind(b, false))
	b.button_down.connect(_mover.bind(b, 0.97, DESLOC_HOVER, 0.06))
	b.button_up.connect(_mover.bind(b, 1.05, DESLOC_HOVER, 0.10))
	b.resized.connect(func() -> void: b.pivot_offset = b.size / 2.0)

	_cena.add_child(b)
	_botoes.append(b)
	return b


# ------------------------------------------------------------------ animações

func _animar_entrada() -> void:
	# Fundo: sai do preto e "pousa" no zoom base
	_fundo.modulate = Color(0, 0, 0, 1)
	_fundo.scale = Vector2.ONE * 1.18
	var intro := create_tween().set_parallel(true)
	intro.tween_property(_fundo, "modulate", Color.WHITE, 1.1)
	intro.tween_property(_fundo, "scale", Vector2.ONE * ESCALA_FUNDO, 1.8) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Botões: deslizam da esquerda, um após o outro
	for i in _botoes.size():
		var b := _botoes[i]
		b.offset_left = -360.0
		b.offset_right = -360.0
		var atraso := 0.55 + i * 0.14
		var t := create_tween().set_parallel(true)
		t.tween_property(b, "offset_left", 0.0, 0.55).set_delay(atraso) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(b, "offset_right", 0.0, 0.55).set_delay(atraso) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(b, "modulate:a", 1.0, 0.35).set_delay(atraso)

	await get_tree().create_timer(1.4).timeout
	_pronto = true
	_b_jogar.grab_focus()
	_iniciar_loops()


func _iniciar_loops() -> void:
	# Fundo "respirando" (zoom lento em loop)
	_respiracao = create_tween().set_loops()
	_respiracao.tween_property(_fundo, "scale", Vector2.ONE * (ESCALA_FUNDO + RESPIRACAO), 8.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_respiracao.tween_property(_fundo, "scale", Vector2.ONE * ESCALA_FUNDO, 8.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Botão JOGAR pulsando suavemente (chama o jogador para a ação)
	_pulso = create_tween().set_loops()
	_pulso.tween_property(_b_jogar, "modulate", Color(1.3, 1.18, 1.45), 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulso.tween_property(_b_jogar, "modulate", Color.WHITE, 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _hover(b: TextureButton, ativo: bool) -> void:
	if not _pronto or _saindo:
		return
	_mover(b, 1.05 if ativo else 1.0, DESLOC_HOVER if ativo else 0.0, 0.12)


func _mover(b: TextureButton, escala: float, deslocamento: float, tempo: float) -> void:
	if not _pronto or _saindo:
		return
	var antigo: Tween = _tweens.get(b, null)
	if antigo != null and antigo.is_valid():
		antigo.kill()
	var t := create_tween().set_parallel(true)
	t.tween_property(b, "scale", Vector2(escala, escala), tempo) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(b, "offset_left", deslocamento, tempo) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(b, "offset_right", deslocamento, tempo) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tweens[b] = t


func _clarao(intensidade: float, tempo: float) -> void:
	var t := create_tween()
	t.tween_property(_flash, "color:a", intensidade, tempo * 0.3)
	t.tween_property(_flash, "color:a", 0.0, tempo * 0.7)


# ------------------------------------------------------------ ações dos botões

func _ao_jogar() -> void:
	if _saindo or not _pronto:
		return
	_saindo = true
	if _respiracao:
		_respiracao.kill()
	if _pulso:
		_pulso.kill()
	_clarao(0.6, 0.45)

	# Botões saem para a esquerda, em sequência
	for i in _botoes.size():
		var b := _botoes[i]
		var antigo: Tween = _tweens.get(b, null)
		if antigo != null and antigo.is_valid():
			antigo.kill()
		var t := create_tween().set_parallel(true)
		t.tween_property(b, "offset_left", -420.0, 0.35).set_delay(i * 0.06) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t.tween_property(b, "offset_right", -420.0, 0.35).set_delay(i * 0.06) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t.tween_property(b, "modulate", Color(1, 1, 1, 0), 0.3).set_delay(i * 0.06)

	# Câmera "mergulha" na arena
	var zoom := create_tween().set_parallel(true)
	zoom.tween_property(_fundo, "scale", Vector2.ONE * 1.4, 0.95) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	zoom.tween_property(_fundo, "modulate", Color(1.6, 1.4, 1.9), 0.6)

	await get_tree().create_timer(0.45).timeout

	# A transição fica na raiz da árvore, então sobrevive à troca de cena
	var transicao := TransicaoCena.new()
	get_tree().root.add_child(transicao)
	transicao.iniciar(CENA_ARENA)


func _ao_comunidade() -> void:
	if _saindo or not _pronto:
		return
	_clarao(0.25, 0.3)
	OS.shell_open(URL_COMUNIDADE)


func _ao_sair() -> void:
	if _saindo or not _pronto:
		return
	_saindo = true
	var t := create_tween()
	t.tween_property(_cena, "modulate", Color(0, 0, 0, 1), 0.45)
	await t.finished
	get_tree().quit()
