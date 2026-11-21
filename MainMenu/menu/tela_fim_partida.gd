class_name TelaFimDePartida
extends CanvasLayer
## Tela de VITÓRIA / DERROTA da Rivals Arena (Godot 4.x).
## Normalmente você não usa este script direto: o GerenciadorPartida chama
## TelaFimDePartida.mostrar(...) quando as vidas de alguém chegam a 0.
##
## Uso manual (para testar):
##   TelaFimDePartida.mostrar(get_tree(), TelaFimDePartida.Resultado.VITORIA)

enum Resultado { VITORIA, DERROTA }

# --- CONFIGURAÇÕES: ajuste aqui ---
const PASTA := "res://menu/"                           # onde estão coroa_vitoria.png / coroa_derrota.png
const CAMINHO_MENU := "res://menu/menu_principal.tscn" # cena do menu principal
const CAMINHO_FONTE := ""                              # opcional, ex: "res://fonts/Orbitron-Bold.ttf"

const COR_OURO := Color("ffc420")
const COR_CARMESIM := Color("ff3b5c")
const COR_ROXO := Color("6d2bd9")
const COR_ROXO_CLARO := Color("b98cff")

var resultado: Resultado = Resultado.VITORIA

var _venceu := true
var _destaque: Color
var _fonte: Font = null
var _raiz: Control
var _fundo: ColorRect
var _raios: Raios
var _vinheta: TextureRect
var _particulas: CPUParticles2D
var _coroa: TextureRect
var _titulo: Label
var _subtitulo: Label
var _botoes: HBoxContainer
var _botao_principal: Button
var _pronto := false
var _saindo := false


## Cria a tela dentro da cena atual (assim ela some sozinha quando a cena trocar).
static func mostrar(arvore: SceneTree, res: Resultado) -> TelaFimDePartida:
	var tela := TelaFimDePartida.new()
	tela.resultado = res
	var pai: Node = arvore.current_scene if arvore.current_scene != null else arvore.root
	pai.add_child(tela)
	return tela


func _init() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS   # continua animando com o jogo pausado


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = true
	_venceu = resultado == Resultado.VITORIA
	_destaque = COR_OURO if _venceu else COR_CARMESIM
	if CAMINHO_FONTE != "" and ResourceLoader.exists(CAMINHO_FONTE):
		_fonte = load(CAMINHO_FONTE)
	_construir()
	_animar_entrada()


# ---------------------------------------------------------------- construção

func _construir() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP   # bloqueia cliques no jogo pausado
	add_child(_raiz)

	_fundo = ColorRect.new()
	_fundo.color = Color(0.07, 0.02, 0.18, 0.0) if _venceu else Color(0.12, 0.0, 0.05, 0.0)
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(_fundo)

	if _venceu:
		_raios = Raios.new()
		_raios.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_raios.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_raios.modulate.a = 0.0
		_raiz.add_child(_raios)
	else:
		_vinheta = _criar_vinheta()
		_raiz.add_child(_vinheta)

	_criar_particulas()

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(centro)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 10)
	centro.add_child(coluna)

	# Coroa (dourada na vitória, quebrada na derrota)
	_coroa = TextureRect.new()
	_coroa.texture = load(PASTA + ("coroa_vitoria.png" if _venceu else "coroa_derrota.png"))
	_coroa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_coroa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_coroa.custom_minimum_size = Vector2(280, 170)
	_coroa.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_coroa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coroa.resized.connect(func() -> void: _coroa.pivot_offset = _coroa.size / 2.0)
	coluna.add_child(_coroa)

	# Título
	_titulo = Label.new()
	_titulo.text = "VITÓRIA!" if _venceu else "DERROTA"
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.add_theme_font_size_override("font_size", 120)
	_titulo.add_theme_color_override("font_color", _destaque)
	_titulo.add_theme_color_override("font_outline_color", Color("2a0a5e") if _venceu else Color("2a0010"))
	_titulo.add_theme_constant_override("outline_size", 18)
	_titulo.add_theme_color_override("font_shadow_color", Color(_destaque, 0.45))
	_titulo.add_theme_constant_override("shadow_offset_x", 0)
	_titulo.add_theme_constant_override("shadow_offset_y", 6)
	if _fonte:
		_titulo.add_theme_font_override("font", _fonte)
	_titulo.resized.connect(func() -> void: _titulo.pivot_offset = _titulo.size / 2.0)
	coluna.add_child(_titulo)

	# Subtítulo
	_subtitulo = Label.new()
	_subtitulo.text = "O ADVERSÁRIO FICOU SEM VIDAS" if _venceu else "VOCÊ FICOU SEM VIDAS"
	_subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitulo.add_theme_font_size_override("font_size", 28)
	_subtitulo.add_theme_color_override("font_color", COR_ROXO_CLARO)
	if _fonte:
		_subtitulo.add_theme_font_override("font", _fonte)
	coluna.add_child(_subtitulo)

	var espaco := Control.new()
	espaco.custom_minimum_size = Vector2(0, 28)
	espaco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(espaco)

	# Botões
	_botoes = HBoxContainer.new()
	_botoes.add_theme_constant_override("separation", 24)
	_botoes.alignment = BoxContainer.ALIGNMENT_CENTER
	_botoes.modulate.a = 0.0
	coluna.add_child(_botoes)

	_botao_principal = _criar_botao("JOGAR NOVAMENTE" if _venceu else "TENTAR DE NOVO", _ao_jogar_novamente)
	_criar_botao("MENU PRINCIPAL", _ao_menu)


func _criar_botao(texto: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(330, 64)
	b.add_theme_font_size_override("font_size", 26)
	if _fonte:
		b.add_theme_font_override("font", _fonte)
	b.add_theme_color_override("font_color", COR_ROXO_CLARO)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)

	var normal := _estilo(Color(0.09, 0.03, 0.2, 0.92), COR_ROXO)
	var destaque := _estilo(Color(0.16, 0.05, 0.3, 0.95), _destaque)
	var apertado := _estilo(Color(_destaque, 0.35), _destaque)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", destaque)
	b.add_theme_stylebox_override("focus", destaque)
	b.add_theme_stylebox_override("pressed", apertado)

	b.pressed.connect(acao)
	b.mouse_entered.connect(func() -> void:
		if _pronto and not _saindo:
			b.grab_focus())
	b.resized.connect(func() -> void: b.pivot_offset = b.size / 2.0)
	_botoes.add_child(b)
	return b


func _estilo(fundo: Color, borda: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fundo
	s.border_color = borda
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.shadow_color = Color(borda, 0.4)
	s.shadow_size = 10
	return s


func _criar_vinheta() -> TextureRect:
	# Borda vermelha pulsando ao redor da tela (derrota)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.45, 1.0])
	grad.colors = PackedColorArray([Color(0.8, 0.0, 0.15, 0.0), Color(0.8, 0.0, 0.15, 0.75)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 512
	tex.height = 512

	var v := TextureRect.new()
	v.texture = tex
	v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.stretch_mode = TextureRect.STRETCH_SCALE
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.modulate.a = 0.0
	return v


func _criar_particulas() -> void:
	_particulas = CPUParticles2D.new()
	_particulas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particulas.emission_rect_extents = Vector2(800, 4)
	_particulas.direction = Vector2(0, 1)
	_particulas.local_coords = false

	if _venceu:
		# Confete dourado / roxo / branco / rosa
		var cores := Gradient.new()
		cores.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		cores.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75])
		cores.colors = PackedColorArray([
			Color("ffc420"), Color("ffffff"), Color("a566ff"), Color("ff5ac8"),
		])
		_particulas.amount = 140
		_particulas.lifetime = 6.0
		_particulas.spread = 25.0
		_particulas.gravity = Vector2(0, 160)
		_particulas.initial_velocity_min = 120.0
		_particulas.initial_velocity_max = 320.0
		_particulas.angular_velocity_min = -360.0
		_particulas.angular_velocity_max = 360.0
		_particulas.scale_amount_min = 5.0
		_particulas.scale_amount_max = 10.0
		_particulas.color_initial_ramp = cores
	else:
		# Brasas apagadas caindo devagar
		var fade := Gradient.new()
		fade.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
		fade.colors = PackedColorArray([
			Color(0.9, 0.2, 0.3, 0.0), Color(0.9, 0.2, 0.3, 0.7),
			Color(0.5, 0.15, 0.3, 0.5), Color(0.5, 0.15, 0.3, 0.0),
		])
		_particulas.amount = 50
		_particulas.lifetime = 7.0
		_particulas.spread = 30.0
		_particulas.gravity = Vector2(0, 40)
		_particulas.initial_velocity_min = 20.0
		_particulas.initial_velocity_max = 60.0
		_particulas.scale_amount_min = 2.0
		_particulas.scale_amount_max = 5.0
		_particulas.color_ramp = fade

	_raiz.add_child(_particulas)
	get_viewport().size_changed.connect(_ajustar_particulas)
	_ajustar_particulas()


func _ajustar_particulas() -> void:
	var tela := get_viewport().get_visible_rect().size
	_particulas.position = Vector2(tela.x * 0.5, -20.0)
	_particulas.emission_rect_extents = Vector2(maxf(tela.x * 0.5, 1.0), 4.0)


# ------------------------------------------------------------------ animações

func _animar_entrada() -> void:
	# Fundo escurece
	create_tween().tween_property(_fundo, "color:a", 0.85 if _venceu else 0.9, 0.45)

	# Efeito de ambiente
	if _venceu:
		create_tween().tween_property(_raios, "modulate:a", 1.0, 1.0)
		var giro := create_tween().set_loops()
		giro.tween_property(_raios, "rotation_degrees", 360.0, 40.0).from(0.0)
	else:
		create_tween().tween_property(_vinheta, "modulate:a", 1.0, 0.6)
		var pulso := create_tween().set_loops()
		pulso.tween_property(_vinheta, "modulate:a", 0.55, 1.1).set_trans(Tween.TRANS_SINE)
		pulso.tween_property(_vinheta, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)

	# Coroa
	_coroa.modulate.a = 0.0
	if _venceu:
		_coroa.scale = Vector2.ONE * 2.6
		_coroa.rotation_degrees = -25.0
		var c := create_tween().set_parallel(true)
		c.tween_property(_coroa, "scale", Vector2.ONE, 0.75).set_delay(0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		c.tween_property(_coroa, "rotation_degrees", 0.0, 0.75).set_delay(0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		c.tween_property(_coroa, "modulate:a", 1.0, 0.25).set_delay(0.25)
	else:
		_coroa.scale = Vector2.ONE * 1.8
		var c := create_tween().set_parallel(true)
		c.tween_property(_coroa, "scale", Vector2.ONE, 0.8).set_delay(0.25) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		c.tween_property(_coroa, "modulate:a", 1.0, 0.25).set_delay(0.25)

	# Título "estoura" na tela
	_titulo.modulate.a = 0.0
	_titulo.scale = Vector2.ONE * 0.4
	var t := create_tween().set_parallel(true)
	t.tween_property(_titulo, "scale", Vector2.ONE, 0.55).set_delay(0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_titulo, "modulate:a", 1.0, 0.25).set_delay(0.6)

	# Tremor de tela na derrota
	if not _venceu:
		var tremor := create_tween()
		tremor.tween_interval(0.6)
		for i in 8:
			var forca := 1.0 - i / 8.0
			tremor.tween_property(_raiz, "position",
				Vector2(randf_range(-14.0, 14.0), randf_range(-10.0, 10.0)) * forca, 0.04)
		tremor.tween_property(_raiz, "position", Vector2.ZERO, 0.05)

	# Subtítulo e botões aparecem em seguida
	_subtitulo.modulate.a = 0.0
	create_tween().tween_property(_subtitulo, "modulate:a", 1.0, 0.4).set_delay(1.05)
	create_tween().tween_property(_botoes, "modulate:a", 1.0, 0.4).set_delay(1.3)

	await get_tree().create_timer(1.6).timeout
	_pronto = true
	_botao_principal.grab_focus()

	if _venceu:
		# Brilho dourado pulsando no título
		var brilho := create_tween().set_loops()
		brilho.tween_property(_titulo, "modulate", Color(1.25, 1.12, 0.8), 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		brilho.tween_property(_titulo, "modulate", Color.WHITE, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ------------------------------------------------------------ ações dos botões

func _ao_jogar_novamente() -> void:
	if not _pronto or _saindo:
		return
	_saindo = true
	var cena := get_tree().current_scene
	var caminho := cena.scene_file_path if cena != null else ""
	if caminho == "":
		get_tree().paused = false
		get_tree().reload_current_scene()
		return
	_iniciar_transicao(caminho, "PREPARANDO A ARENA")


func _ao_menu() -> void:
	if not _pronto or _saindo:
		return
	_saindo = true
	_iniciar_transicao(CAMINHO_MENU, "VOLTANDO AO MENU")


func _iniciar_transicao(caminho: String, texto: String) -> void:
	# A transição vive na raiz da árvore e despausa o jogo ao trocar de cena
	var transicao := TransicaoCena.new()
	get_tree().root.add_child(transicao)
	transicao.iniciar(caminho, texto)


# ---------------------------------------------------- raios de luz (vitória)

class Raios extends Control:
	var cor := Color(1.0, 0.8, 0.3, 0.10)
	var quantidade := 14

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			pivot_offset = size / 2.0

	func _draw() -> void:
		var centro := size / 2.0
		var raio := size.length()
		var passo := TAU / quantidade
		for i in quantidade:
			var a := i * passo
			var p1 := centro + Vector2.RIGHT.rotated(a - passo * 0.16) * raio
			var p2 := centro + Vector2.RIGHT.rotated(a + passo * 0.16) * raio
			draw_colored_polygon(PackedVector2Array([centro, p1, p2]), cor)
