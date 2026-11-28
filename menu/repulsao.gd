class_name Repulsao
extends Node
## Componente de REPULSÃO acumulativa (estilo Brawlhalla / Smash).
## Cada golpe recebido aumenta a porcentagem; quanto maior a porcentagem,
## mais longe o personagem é lançado pelos próximos golpes.
##
## Uso (1 linha, no script de ataque, onde o dano é aplicado):
##     Repulsao.aplicar(alvo, self, 12.0)
##       alvo     = o personagem que levou o golpe (CharacterBody2D)
##       self     = quem atacou (usado para saber para que lado lançar)
##       12.0     = quanto a porcentagem sobe com esse golpe
##     (3º parâmetro opcional: força do golpe, 1.0 = normal; golpes fortes > 1.0)
##
## O componente se instala sozinho no personagem se ainda não existir.
## O lançamento é um movimento extra (move_and_collide) somado ao movimento
## normal do personagem, então funciona sem alterar o script de movimento.

signal porcentagem_alterada(nova: float, anterior: float)
signal lancado(velocidade: Vector2)
signal atordoamento_terminou

@export var porcentagem: float = 0.0
@export var porcentagem_maxima: float = 999.0
@export_group("Lançamento")
@export var peso: float = 1.0                    # > 1 = mais pesado (voa menos)
@export var forca_base: float = 500.0            # lançamento com 0% de porcentagem
@export var fator_porcentagem: float = 0.012     # cada 1% soma 1,2% à força (100% => 2,2x)
@export_range(0.0, 1.5, 0.05) var elevacao: float = 0.55        # quanto o golpe "levanta" o alvo
@export_range(0.80, 0.99, 0.005) var amortecimento: float = 0.94  # perda de velocidade por frame (60fps)
@export_range(0.0, 1.0, 0.05) var ricochete: float = 0.3        # quanto bate e volta em paredes/teto

var _vel := Vector2.ZERO
var _tempo := 0.0

## true enquanto o personagem está sendo lançado (útil para bloquear o controle)
var atordoado: bool:
	get:
		return _tempo > 0.0


func _ready() -> void:
	set_physics_process(false)


## Atalho: encontra (ou cria) o componente no alvo e aplica o golpe.
static func aplicar(alvo: Node, atacante: Node2D, dano: float, forca: float = 1.0) -> Repulsao:
	if alvo == null or not is_instance_valid(alvo):
		return null

	var rep := alvo.find_child("Repulsao", true, false) as Repulsao
	if rep == null:
		rep = Repulsao.new()
		rep.name = "Repulsao"
		alvo.add_child(rep)

	var direcao := Vector2.RIGHT
	var alvo_2d := alvo as Node2D
	if atacante != null and alvo_2d != null:
		var d := alvo_2d.global_position - atacante.global_position
		if d.length() > 1.0:
			direcao = d.normalized()

	rep.receber_golpe(dano, direcao, forca)
	return rep


## "direcao" aponta para longe de quem atacou. Retorna a velocidade inicial do lançamento.
func receber_golpe(dano: float, direcao: Vector2, forca: float = 1.0) -> Vector2:
	var anterior := porcentagem
	porcentagem = clampf(porcentagem + maxf(dano, 0.0), 0.0, porcentagem_maxima)
	porcentagem_alterada.emit(porcentagem, anterior)

	var dir := direcao.normalized() if direcao.length() > 0.001 else Vector2.RIGHT
	dir.y = minf(dir.y, 0.0)   # nunca empurra para dentro do chão
	var vetor := Vector2(dir.x, dir.y - elevacao).normalized()

	var intensidade := forca_base * forca * (1.0 + porcentagem * fator_porcentagem) / maxf(peso, 0.1)
	_vel = vetor * intensidade
	_tempo = clampf(0.15 + intensidade * 0.0004, 0.15, 1.4)
	set_physics_process(true)

	lancado.emit(_vel)
	return _vel


## Zera a porcentagem (ex.: ao ressuscitar).
func resetar() -> void:
	var anterior := porcentagem
	porcentagem = 0.0
	_vel = Vector2.ZERO
	_tempo = 0.0
	set_physics_process(false)
	porcentagem_alterada.emit(0.0, anterior)


func _physics_process(delta: float) -> void:
	var corpo := get_parent() as CharacterBody2D
	if corpo == null or _tempo <= 0.0:
		_encerrar()
		return

	_tempo -= delta
	_vel *= pow(amortecimento, delta * 60.0)

	var colisao := corpo.move_and_collide(_vel * delta)
	if colisao != null:
		_vel = _vel.bounce(colisao.get_normal()) * ricochete

	if _tempo <= 0.0 or _vel.length() < 30.0:
		_encerrar()


func _encerrar() -> void:
	_tempo = 0.0
	_vel = Vector2.ZERO
	set_physics_process(false)
	atordoamento_terminou.emit()
