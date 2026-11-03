class_name ExposureComponent
extends Node
## Exposition du porteur à l'infection (0 à 1).
##
## Monte quand le porteur marche sur un sol infecté, ou quand on l'appelle
## via add() (récolte d'une ressource infectée, coup d'un infecté plus tard).

signal changed(value: float)
## Le porteur entre ou sort d'une zone infectée (utile pour l'alerte du HUD).
signal zone_changed(inside: bool)

## Exposition gagnée par seconde sur un sol infecté à 100 %.
@export var ground_rate: float = 0.04

var value: float = 0.0
var in_infected_zone: bool = false
## Sol à surveiller (injecté par la zone). Sans sol, seul add() fait monter l'exposition.
var ground: InfectionGround

var _body: Node2D


func _ready() -> void:
	_body = get_parent() as Node2D


func _physics_process(delta: float) -> void:
	if ground == null or _body == null:
		return
	var infection: float = ground.get_infection_at(_body.global_position)
	var inside: bool = infection > 0.0
	if inside != in_infected_zone:
		in_infected_zone = inside
		zone_changed.emit(inside)
	if inside:
		add(infection * ground_rate * delta)


func add(amount: float) -> void:
	if amount <= 0.0 or value >= 1.0:
		return
	value = minf(value + amount, 1.0)
	changed.emit(value)
