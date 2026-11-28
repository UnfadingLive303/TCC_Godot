class_name HudCombate
extends CanvasLayer
## HUD minimalista (estilo Brawlhalla): retrato redondo + porcentagem de repulsão +
## vidas (coroinhas), embaixo no centro da tela. Sem caixas nem barras.
## Procura os personagens pelos grupos "jogador" e "bot" e as vidas no nó do grupo
## "gerenciador_respawn", então acompanha os respawns sozinho.
##
## Para criar: add_child(HudCombate.new())   (o gerenciador_respawn já faz isso)

# --- CONFIGURAÇÕES ---
const PASTA := "res://menu/"                 # coroa_vitoria.png / coroa_derrota.png
const PASTA_SPRITES := "res://menu/sprites/" # retrato_jogador.png / retrato_bot.png

@export var instalar_automaticamente: bool = true   # coloca o componente Repulsao nos personagens
@export var teclas_de_teste: bool = true            # F1/F2 = golpe no jogador/bot, F3 = zera (desligue ao lançar o jogo)
@export var caminho_fonte: String = ""              # opcional, ex: "res://fonts/Orbitron-Bold.ttf"

var _fonte: Font = null
var _tex_viva: Texture2D
var _tex_morta: Texture2D
var _p_jogador: Painel
var _p_bot: Painel
var _acumulado := 0.0


class Painel extends RefCounted:
	var raiz: HBoxContainer
	var retrato: TextureRect
	var numero: Label
	var coroas_box: HBoxContainer
	var coroas: Array[TextureRect] = []
	var repulsao: Repulsao = null
	var conexao: Callable
	var exibido: float = 0.0
	var alvo: float = 0.0
	var tween: Tween
	var tween_retrato: Tween
	var vidas_atuais: int = -1


func _init() -> void:
	layer = 50


func _ready() -> void:
	if caminho_fonte != "" and ResourceLoader.exists(caminho_fonte):
		_fonte = load(caminho_fonte)
	_tex_viva = load(PASTA + "coroa_vitoria.png")
	_tex_morta = load(PASTA + "coroa_derrota.png")
	_construir()


func _process(delta: float) -> void:
	_acumulado += delta
	if _acumulado < 0.1:
		return
	_acumulado = 0.0
	_vincular(_p_jogador, get_tree().get_first_node_in_group("jogador"))
	_vincular(_p_bot, get_tree().get_first_node_in_group("bot"))
	_atualizar_vidas()


func _unhandled_input(evento: InputEvent) -> void:
	if not teclas_de_teste:
		return
	if evento is InputEventKey and evento.pressed and not evento.echo:
		match evento.keycode:
			KEY_F1:
				_golpe_de_teste("jogador", "bot")
			KEY_F2:
				_golpe_de_teste("bot", "jogador")
			KEY_F3:
				for p in [_p_jogador, _p_bot]:
					if p.repulsao != null and is_instance_valid(p.repulsao):
						p.repulsao.resetar()


func _golpe_de_teste(grupo_alvo: String, grupo_atacante: String) -> void:
	var alvo := get_tree().get_first_node_in_group(grupo_alvo)
	var atacante := get_tree().get_first_node_in_group(grupo_atacante) as Node2D
	Repulsao.aplicar(alvo, atacante, 15.0)


# ---------------------------------------------------------------- construção

func _construir() -> void:
	var raiz := Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)

	var margem := MarginContainer.new()
	margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margem.add_theme_constant_override("margin_bottom", 22)
	raiz.add_child(margem)

	var linha := HBoxContainer.new()
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.size_flags_vertical = Control.SIZE_SHRINK_END   # fica no rodapé
	linha.add_theme_constant_override("separation", 300)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margem.add_child(linha)

	_p_jogador = _criar_painel("jogador")
	linha.add_child(_p_jogador.raiz)
	_p_bot = _criar_painel("bot")
	linha.add_child(_p_bot.raiz)


func _criar_painel(quem: String) -> Painel:
	var p := Painel.new()

	var caixa := HBoxContainer.new()
	caixa.add_theme_constant_override("separation", 10)
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.raiz = caixa

	p.retrato = TextureRect.new()
	p.retrato.texture = load(PASTA_SPRITES + "retrato_%s.png" % quem)
	p.retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p.retrato.custom_minimum_size = Vector2(66, 66)
	p.retrato.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var retrato := p.retrato
	retrato.resized.connect(func() -> void: retrato.pivot_offset = retrato.size / 2.0)
	caixa.add_child(p.retrato)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", -6)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.add_child(coluna)

	p.numero = Label.new()
	p.numero.custom_minimum_size = Vector2(120, 0)
	p.numero.add_theme_font_size_override("font_size", 54)
	p.numero.add_theme_color_override("font_outline_color", Color("120826"))
	p.numero.add_theme_constant_override("outline_size", 12)
	if _fonte:
		p.numero.add_theme_font_override("font", _fonte)
	var numero := p.numero
	numero.resized.connect(func() -> void: numero.pivot_offset = numero.size / 2.0)
	coluna.add_child(p.numero)

	p.coroas_box = HBoxContainer.new()
	p.coroas_box.add_theme_constant_override("separation", 4)
	p.coroas_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(p.coroas_box)

	_definir_exibicao(0.0, p)
	return p


func _reconstruir_coroas(p: Painel, maximo: int) -> void:
	for filho in p.coroas_box.get_children():
		filho.queue_free()
	p.coroas.clear()
	for i in maximo:
		var coroa := TextureRect.new()
		coroa.texture = _tex_viva
		coroa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coroa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coroa.custom_minimum_size = Vector2(24, 14)
		coroa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coroa.resized.connect(func() -> void: coroa.pivot_offset = coroa.size / 2.0)
		p.coroas_box.add_child(coroa)
		p.coroas.append(coroa)
	p.vidas_atuais = -1


# ------------------------------------------------------- ligação com o jogo

func _vincular(p: Painel, personagem: Node) -> void:
	var rep: Repulsao = null
	if personagem != null and is_instance_valid(personagem):
		rep = personagem.find_child("Repulsao", true, false) as Repulsao
		if rep == null and instalar_automaticamente and personagem is CharacterBody2D:
			rep = Repulsao.new()
			rep.name = "Repulsao"
			personagem.add_child(rep)

	if rep == p.repulsao:
		return

	# desconecta do componente antigo (o personagem pode ter morrido)
	if p.repulsao != null and is_instance_valid(p.repulsao):
		if p.repulsao.porcentagem_alterada.is_connected(p.conexao):
			p.repulsao.porcentagem_alterada.disconnect(p.conexao)

	p.repulsao = rep
	if rep != null:
		p.conexao = _ao_mudar.bind(p)
		rep.porcentagem_alterada.connect(p.conexao)
		_animar_para(p, rep.porcentagem, p.alvo)
	else:
		_animar_para(p, 0.0, p.alvo)   # personagem eliminado: volta a 0%


func _atualizar_vidas() -> void:
	var ger := get_tree().get_first_node_in_group("gerenciador_respawn")
	_p_jogador.coroas_box.visible = ger != null
	_p_bot.coroas_box.visible = ger != null
	if ger == null:
		return
	var maximo := _ler_int(ger, "vidas_maximas", 3)
	_aplicar_vidas(_p_jogador, _ler_int(ger, "vidas_jogador", maximo), maximo)
	_aplicar_vidas(_p_bot, _ler_int(ger, "vidas_bot", maximo), maximo)


func _ler_int(no: Node, propriedade: String, padrao: int) -> int:
	var valor = no.get(propriedade)
	if valor == null:
		return padrao
	return int(valor)


func _aplicar_vidas(p: Painel, vidas: int, maximo: int) -> void:
	if p.coroas.size() != maximo:
		_reconstruir_coroas(p, maximo)
	if vidas == p.vidas_atuais:
		return

	var perdeu := p.vidas_atuais >= 0 and vidas < p.vidas_atuais
	p.vidas_atuais = vidas

	for i in p.coroas.size():
		var viva := i < vidas
		p.coroas[i].texture = _tex_viva if viva else _tex_morta
		p.coroas[i].modulate = Color.WHITE if viva else Color(0.6, 0.5, 0.75, 0.7)

	if perdeu and vidas >= 0 and vidas < p.coroas.size():
		var coroa := p.coroas[vidas]
		coroa.scale = Vector2.ONE * 1.8
		create_tween().tween_property(coroa, "scale", Vector2.ONE, 0.45) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ animação

func _ao_mudar(nova: float, anterior: float, p: Painel) -> void:
	_animar_para(p, nova, anterior)


func _animar_para(p: Painel, nova: float, anterior: float) -> void:
	p.alvo = nova
	if p.tween != null and p.tween.is_valid():
		p.tween.kill()

	var t := create_tween().set_parallel(true)
	p.tween = t

	# número "rola" até o novo valor
	t.tween_method(_definir_exibicao.bind(p), p.exibido, nova, 0.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# golpe recebido: número estoura e pisca; retrato balança
	if nova > anterior:
		var forca := clampf((nova - anterior) / 20.0, 0.4, 1.6)
		p.numero.scale = Vector2.ONE * (1.0 + 0.35 * forca)
		p.numero.rotation_degrees = randf_range(-6.0, 6.0) * forca
		t.tween_property(p.numero, "scale", Vector2.ONE, 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(p.numero, "rotation_degrees", 0.0, 0.45) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		t.tween_property(p.numero, "modulate", Color.WHITE, 0.3).from(Color(2.2, 2.2, 2.2))

		if p.tween_retrato != null and p.tween_retrato.is_valid():
			p.tween_retrato.kill()
		p.retrato.scale = Vector2.ONE * (1.0 + 0.16 * forca)
		p.retrato.rotation_degrees = randf_range(-10.0, 10.0) * forca
		var tr := create_tween().set_parallel(true)
		p.tween_retrato = tr
		tr.tween_property(p.retrato, "scale", Vector2.ONE, 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tr.tween_property(p.retrato, "rotation_degrees", 0.0, 0.5) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _definir_exibicao(valor: float, p: Painel) -> void:
	p.exibido = valor
	p.numero.text = "%d%%" % roundi(valor)
	p.numero.add_theme_color_override("font_color", _cor_para(valor))


## Branco -> amarelo -> laranja -> vermelho -> carmesim conforme a porcentagem sobe
func _cor_para(valor: float) -> Color:
	var pontos: Array[float] = [0.0, 50.0, 100.0, 150.0, 200.0]
	var cores: Array[Color] = [
		Color.WHITE, Color("ffe14a"), Color("ff9a1f"), Color("ff5a2a"), Color("e0112f"),
	]
	if valor >= pontos[pontos.size() - 1]:
		return cores[cores.size() - 1]
	for i in range(pontos.size() - 1):
		if valor < pontos[i + 1]:
			return cores[i].lerp(cores[i + 1], inverse_lerp(pontos[i], pontos[i + 1], valor))
	return cores[cores.size() - 1]
