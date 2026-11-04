class_name HealthComponent
extends Node
## Points de vie d'un personnage (joueur ou ennemi).
##
## Ne fait que compter : qui frappe, et ce qui se passe à la mort, est décidé
## ailleurs (signaux damaged et died).

signal changed(health: int, max_health: int)
## Coup encaissé. `from` : position de celui qui frappe (pour le recul).
signal damaged(amount: int, from: Vector2)
signal died

@export var max_health: int = 10
## Temps d'invincibilité après un coup (secondes). 0 = aucun.
@export var invulnerable_time: float = 0.0

var health: int = 0
var _invulnerable_until: float = 0.0


func _ready() -> void:
	health = max_health


func reset(new_max: int = -1) -> void:
	if new_max > 0:
		max_health = new_max
	health = max_health
	_invulnerable_until = 0.0
	changed.emit(health, max_health)


func is_dead() -> bool:
	return health <= 0


func is_invulnerable() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _invulnerable_until


## Encaisse un coup. Renvoie les dégâts vraiment pris (0 si invincible ou déjà mort).
func take_damage(amount: int, from: Vector2 = Vector2.ZERO) -> int:
	if amount <= 0 or is_dead() or is_invulnerable():
		return 0
	var taken: int = mini(amount, health)
	health -= taken
	if invulnerable_time > 0.0:
		_invulnerable_until = Time.get_ticks_msec() / 1000.0 + invulnerable_time
	changed.emit(health, max_health)
	damaged.emit(taken, from)
	if health <= 0:
		died.emit()
	return taken


func heal(amount: int) -> void:
	if amount <= 0 or is_dead():
		return
	health = mini(health + amount, max_health)
	changed.emit(health, max_health)
