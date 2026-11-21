class_name TransicaoCena
extends CanvasLayer
## Transição de cena: faixas roxas com borda dourada fecham a tela, mostram uma
## barra de carregamento enquanto a nova cena carrega e depois se abrem.
##
## Uso:
##   var t := TransicaoCena.new()
##   get_tree().root.add_child(t)
##   t.iniciar("res://arena.tscn", "ENTRANDO NA ARENA")

const QTD_FAIXAS := 14
const COR_FAIXA := Color("160830")
const COR_BORDA := Color("ffc420")
const COR_SUBTITULO := Color("b98cff")
const DURACAO_FAIXA := 0.40       # tempo que cada faixa leva para fechar/abrir
const ATRASO_FAIXA := 0.04        # defasagem entre faixas (efeito de onda)
const TEMPO_MINIMO := 0.9         # tempo mínimo da tela de carregamento (evita "piscar")

var _raiz: Control
var _faixas: Array[ColorRect] = []
var _conteudo: Control
var _barra: ProgressBar
var _altura := 0.0
var _texto := "ENTRANDO NA ARENA"


func _init() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS


## O nó precisa já estar na árvore (add_child) antes de chamar.
## "texto" é o título mostrado na tela de carregamento.
func iniciar(caminho: String, texto: String = "ENTRANDO NA ARENA") -> void:
	_texto = texto
	_construir()
	await _fechar()
	var ok: bool = await _carregar_e_trocar(caminho)
	if ok:
		# espera a nova cena entrar na árvore antes de abrir
		await get_tree().process_frame
		await get_tree().process_frame
	else:
		# não achou a cena: recarrega o menu para não deixá-lo travado
		get_tree().paused = false
		get_tree().reload_current_scene()
		await get_tree().process_frame
		await get_tree().process_frame
	await _abrir()
	queue_free()


func _construir() -> void:
	var tela := get_viewport().get_visible_rect().size
	_altura = tela.y

	_raiz = Control.new()
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP   # bloqueia cliques durante a transição
	add_child(_raiz)

	var largura := tela.x / QTD_FAIXAS
	for i in QTD_FAIXAS:
		var faixa := ColorRect.new()
		faixa.color = COR_FAIXA
		faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		faixa.position = Vector2(floorf(i * largura), 0.0)
		faixa.size = Vector2(ceilf(largura) + 1.0, 0.0)

		var borda := ColorRect.new()
		borda.color = COR_BORDA
		borda.mouse_filter = Control.MOUSE_FILTER_IGNORE
		borda.anchor_left = 0.0
		borda.anchor_right = 1.0
		borda.anchor_top = 1.0
		borda.anchor_bottom = 1.0
		borda.offset_left = 0.0
		borda.offset_right = 0.0
		borda.offset_top = -4.0
		borda.offset_bottom = 0.0
		faixa.add_child(borda)

		_raiz.add_child(faixa)
		_faixas.append(faixa)

	# Conteúdo central (texto + barra de carregamento)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.modulate.a = 0.0
	_raiz.add_child(centro)
	_conteudo = centro

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 16)
	centro.add_child(coluna)

	var titulo := Label.new()
	titulo.text = _texto
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 44)
	titulo.add_theme_color_override("font_color", COR_BORDA)
	titulo.add_theme_color_override("font_outline_color", Color("2a0a5e"))
	titulo.add_theme_constant_override("outline_size", 8)
	coluna.add_child(titulo)

	var subtitulo := Label.new()
	subtitulo.text = "LUTE. CONQUISTE. FAÇA PARTE."
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitulo.add_theme_font_size_override("font_size", 20)
	subtitulo.add_theme_color_override("font_color", COR_SUBTITULO)
	coluna.add_child(subtitulo)

	_barra = ProgressBar.new()
	_barra.custom_minimum_size = Vector2(460, 12)
	_barra.min_value = 0.0
	_barra.max_value = 100.0
	_barra.show_percentage = false
	var fundo_barra := StyleBoxFlat.new()
	fundo_barra.bg_color = Color(0.08, 0.03, 0.18, 0.9)
	fundo_barra.border_color = Color("6d2bd9")
	fundo_barra.set_border_width_all(2)
	fundo_barra.set_corner_radius_all(6)
	var preenchimento := StyleBoxFlat.new()
	preenchimento.bg_color = COR_BORDA
	preenchimento.set_corner_radius_all(6)
	_barra.add_theme_stylebox_override("background", fundo_barra)
	_barra.add_theme_stylebox_override("fill", preenchimento)
	coluna.add_child(_barra)

	# Título pulsando
	var pulso := create_tween().set_loops()
	pulso.tween_property(titulo, "modulate:a", 0.55, 0.6).set_trans(Tween.TRANS_SINE)
	pulso.tween_property(titulo, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)


func _fechar() -> void:
	var t := create_tween().set_parallel(true)
	for i in _faixas.size():
		t.tween_property(_faixas[i], "size:y", _altura, DURACAO_FAIXA) \
			.set_delay(i * ATRASO_FAIXA) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	var aparece := create_tween()
	aparece.tween_property(_conteudo, "modulate:a", 1.0, 0.2)


func _carregar_e_trocar(caminho: String) -> bool:
	if not ResourceLoader.exists(caminho):
		push_error("TransicaoCena: cena não encontrada: " + caminho)
		return false

	ResourceLoader.load_threaded_request(caminho)
	var inicio := Time.get_ticks_msec()
	var progresso: Array = []

	while true:
		var status := ResourceLoader.load_threaded_get_status(caminho, progresso)
		var real: float = progresso[0] if progresso.size() > 0 else 0.0
		var tempo := (Time.get_ticks_msec() - inicio) / 1000.0
		_barra.value = minf(real, clampf(tempo / TEMPO_MINIMO, 0.0, 1.0)) * 100.0

		if status == ResourceLoader.THREAD_LOAD_FAILED \
				or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("TransicaoCena: falha ao carregar " + caminho)
			return false
		if status == ResourceLoader.THREAD_LOAD_LOADED and tempo >= TEMPO_MINIMO:
			break
		await get_tree().process_frame

	_barra.value = 100.0
	var cena := ResourceLoader.load_threaded_get(caminho) as PackedScene
	if cena == null:
		return false
	get_tree().change_scene_to_packed(cena)
	get_tree().paused = false   # a nova cena começa rodando (a tela de fim de partida pausa o jogo)
	Engine.time_scale = 1.0
	return true


func _abrir() -> void:
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE   # a nova cena já pode receber cliques
	var t := create_tween().set_parallel(true)
	t.tween_property(_conteudo, "modulate:a", 0.0, 0.25)
	for i in _faixas.size():
		t.tween_property(_faixas[i], "size:y", 0.0, DURACAO_FAIXA) \
			.set_delay(0.15 + i * ATRASO_FAIXA) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await t.finished
