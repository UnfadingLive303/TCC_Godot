extends Control
## Menu principal futurista (Godot 4.x)
## Anexe este script a um nó Control (raiz da cena) e defina como cena principal.

# --- CONFIGURAÇÕES: ajuste aqui ---
const CENA_ARENA := "res://Scenes/arena.tscn"            # caminho da sua cena "arena"
const URL_COMUNIDADE := "https://discord.gg/seu-convite"  # link do site/comunidade
const TITULO := "NEON ARENA"                       # nome do seu jogo
const CAMINHO_FONTE := ""                          # opcional, ex: "res://fonts/Orbitron-Bold.ttf"

# --- Paleta futurista ---
const COR_FUNDO := Color("05060f")
const COR_CIANO := Color("00e5ff")
const COR_MAGENTA := Color("ff2bd6")
const COR_GRADE := Color(0.0, 0.9, 1.0, 0.08)

const PASSO_GRADE := 48.0

var _deslocamento := 0.0
var _fonte: Font = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if CAMINHO_FONTE != "" and ResourceLoader.exists(CAMINHO_FONTE):
		_fonte = load(CAMINHO_FONTE)
	_construir_interface()


func _process(delta: float) -> void:
	# Faz a grade do fundo "deslizar" lentamente
	_deslocamento = fmod(_deslocamento + delta * 20.0, PASSO_GRADE)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COR_FUNDO)

	var x := 0.0
	while x <= size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), COR_GRADE, 1.0)
		x += PASSO_GRADE

	var y := _deslocamento - PASSO_GRADE
	while y <= size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), COR_GRADE, 1.0)
		y += PASSO_GRADE

	# Faixas neon no topo e na base
	draw_rect(Rect2(0, 0, size.x, 3), COR_CIANO)
	draw_rect(Rect2(0, size.y - 3, size.x, 3), COR_MAGENTA)


func _construir_interface() -> void:
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 18)
	centro.add_child(coluna)

	# Título
	var titulo := Label.new()
	titulo.text = TITULO
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 72)
	titulo.add_theme_color_override("font_color", COR_CIANO)
	titulo.add_theme_color_override("font_outline_color", COR_MAGENTA)
	titulo.add_theme_constant_override("outline_size", 3)
	titulo.add_theme_color_override("font_shadow_color", Color(COR_CIANO, 0.5))
	titulo.add_theme_constant_override("shadow_offset_x", 0)
	titulo.add_theme_constant_override("shadow_offset_y", 0)
	titulo.add_theme_constant_override("shadow_outline_size", 12)
	if _fonte:
		titulo.add_theme_font_override("font", _fonte)
	coluna.add_child(titulo)

	# Espaçador entre título e botões
	var espaco := Control.new()
	espaco.custom_minimum_size = Vector2(0, 40)
	coluna.add_child(espaco)

	# Botões
	var botao_jogar := _criar_botao("JOGAR", _ao_jogar)
	coluna.add_child(botao_jogar)
	coluna.add_child(_criar_botao("COMUNIDADE", _ao_comunidade))
	coluna.add_child(_criar_botao("SAIR", _ao_sair))

	# Foco inicial (permite navegar com teclado/controle)
	botao_jogar.grab_focus.call_deferred()


func _criar_botao(texto: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(340, 58)
	b.add_theme_font_size_override("font_size", 24)
	if _fonte:
		b.add_theme_font_override("font", _fonte)

	b.add_theme_color_override("font_color", COR_CIANO)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)

	var normal := _estilo(Color(0.02, 0.08, 0.14, 0.8), COR_CIANO)
	var destaque := _estilo(Color(0.12, 0.02, 0.16, 0.9), COR_MAGENTA)
	var apertado := _estilo(Color(COR_MAGENTA, 0.4), COR_MAGENTA)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", destaque)
	b.add_theme_stylebox_override("focus", destaque)
	b.add_theme_stylebox_override("pressed", apertado)

	b.pressed.connect(acao)
	b.mouse_entered.connect(_animar.bind(b, 1.06))
	b.mouse_exited.connect(_animar.bind(b, 1.0))
	b.focus_entered.connect(_animar.bind(b, 1.06))
	b.focus_exited.connect(_animar.bind(b, 1.0))
	b.resized.connect(func() -> void: b.pivot_offset = b.size / 2.0)
	return b


func _estilo(fundo: Color, borda: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fundo
	s.border_color = borda
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	s.shadow_color = Color(borda, 0.45)
	s.shadow_size = 10
	return s


func _animar(botao: Button, escala: float) -> void:
	var tween := create_tween()
	tween.tween_property(botao, "scale", Vector2(escala, escala), 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# --- Ações dos botões ---
func _ao_jogar() -> void:
	get_tree().change_scene_to_file(CENA_ARENA)


func _ao_comunidade() -> void:
	OS.shell_open(URL_COMUNIDADE)


func _ao_sair() -> void:
	get_tree().quit()
