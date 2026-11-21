class_name GerenciadorPartida
extends Node
## Controla as vidas do jogador e do bot e decide quando mostrar
## a tela de VITÓRIA (bot com 0 vidas) ou DERROTA (jogador com 0 vidas).
##
## Como usar:
##  1) Adicione um nó "Node" na cena arena e anexe este script.
##  2) Sempre que alguém perder vida, chame:
##        gerenciador.tirar_vida_jogador()   # jogador perdeu 1 vida
##        gerenciador.tirar_vida_bot()       # bot perdeu 1 vida
##     ou, se as vidas já existem em outro script seu:
##        gerenciador.definir_vidas(vidas_do_jogador, vidas_do_bot)
##     (pode chamar a cada mudança de vida; a verificação é automática)

signal vidas_alteradas(vidas_jogador: int, vidas_bot: int)
signal vitoria
signal derrota

@export var vidas_jogador: int = 3
@export var vidas_bot: int = 3
@export var camera_lenta: bool = true                        # câmera lenta no golpe final
@export_range(0.0, 3.0, 0.1) var atraso_tela: float = 0.8    # segundos (tempo real) até a tela aparecer

var encerrada := false


func tirar_vida_jogador(quantidade: int = 1) -> void:
	definir_vidas(vidas_jogador - quantidade, vidas_bot)


func tirar_vida_bot(quantidade: int = 1) -> void:
	definir_vidas(vidas_jogador, vidas_bot - quantidade)


func definir_vidas(jogador: int, bot: int) -> void:
	if encerrada:
		return
	vidas_jogador = maxi(jogador, 0)
	vidas_bot = maxi(bot, 0)
	vidas_alteradas.emit(vidas_jogador, vidas_bot)

	# Se os dois zerarem na mesma chamada, vale a derrota
	if vidas_jogador <= 0:
		_encerrar(false)
	elif vidas_bot <= 0:
		_encerrar(true)


func _encerrar(venceu: bool) -> void:
	encerrada = true
	if venceu:
		vitoria.emit()
	else:
		derrota.emit()

	if camera_lenta:
		Engine.time_scale = 0.3
	await get_tree().create_timer(atraso_tela, true, false, true).timeout   # ignora o time_scale
	Engine.time_scale = 1.0

	var resultado := TelaFimDePartida.Resultado.VITORIA if venceu else TelaFimDePartida.Resultado.DERROTA
	TelaFimDePartida.mostrar(get_tree(), resultado)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
