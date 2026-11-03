class_name Player
extends CharacterBody2D
## Personnage joueur en vue de dessus.
##
## Il ne lit QUE les actions de l'InputMap (move_*, attack, interact).
## Clavier, manette et contrôles tactiles passent tous par ces actions :
## le joueur ne sait pas (et n'a pas à savoir) quel périphérique est utilisé.
##
## Animations td2d (voir art/) : idle, walk, harvest, attack, chacune en
## 4 directions (suffixes _s, _e, _n, _w).

signal attacked(direction: Vector2)

## Vitesse de déplacement max, en pixels de jeu par seconde (16 px = 1 m).
@export var move_speed: float = 72.0
## Vitesse à laquelle on atteint move_speed (px/s²).
@export var acceleration: float = 900.0
## Vitesse à laquelle on s'arrête quand on lâche les commandes (px/s²).
@export var friction: float = 1100.0
## Vitesse de lecture du coup (1 = vitesse de l'animation td2d).
@export var attack_speed: float = 1.6

## Dernière direction regardée.
var facing: Vector2 = Vector2.DOWN
## false : le joueur ne répond plus aux commandes (fin de sortie, cinématique...).
var controls_enabled: bool = true

@onready var exposure: ExposureComponent = $Exposure
@onready var interactor: Interactor = $Interactor
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

var _attacking: bool = false


func _ready() -> void:
	_sprite.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	var input_dir: Vector2 = Vector2.ZERO
	var harvesting: bool = interactor.is_holding()
	# Pendant un coup ou une récolte, le personnage est occupé : il ne marche pas.
	if controls_enabled and not harvesting and not _attacking:
		input_dir = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")

	if input_dir != Vector2.ZERO:
		facing = input_dir.normalized()
		velocity = velocity.move_toward(input_dir * move_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()

	if harvesting:
		facing = (interactor.target.global_position - global_position).normalized()
	_update_animation(input_dir != Vector2.ZERO, harvesting)


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	interactor.set_physics_process(enabled)


func _unhandled_input(event: InputEvent) -> void:
	if controls_enabled and not _attacking and event.is_action_pressed(&"attack"):
		_attack()


func _attack() -> void:
	_attacking = true
	_sprite.speed_scale = attack_speed
	_sprite.play(StringName("attack_" + direction_name(facing)))
	attacked.emit(facing)


func _on_animation_finished() -> void:
	if _attacking:
		_attacking = false
		_sprite.speed_scale = 1.0


func _update_animation(moving: bool, harvesting: bool) -> void:
	if _attacking:
		return
	var action: String = "walk" if moving else "idle"
	if harvesting:
		action = "harvest"
	var animation_name := StringName(action + "_" + direction_name(facing))
	if _sprite.animation != animation_name:
		_sprite.play(animation_name)


## Direction cardinale la plus proche d'un vecteur : "s", "e", "n" ou "w".
static func direction_name(direction: Vector2) -> String:
	if absf(direction.x) > absf(direction.y):
		return "e" if direction.x > 0.0 else "w"
	return "s" if direction.y >= 0.0 else "n"
