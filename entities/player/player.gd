class_name Player
extends CharacterBody2D
## Personnage joueur en vue de dessus.
##
## Il ne lit QUE les actions de l'InputMap (move_*, attack, interact).
## Clavier, manette et contrôles tactiles passent tous par ces actions :
## le joueur ne sait pas (et n'a pas à savoir) quel périphérique est utilisé.

## Vitesse de déplacement max, en pixels de jeu par seconde (16 px = 1 m).
@export var move_speed: float = 72.0
## Vitesse à laquelle on atteint move_speed (px/s²).
@export var acceleration: float = 900.0
## Vitesse à laquelle on s'arrête quand on lâche les commandes (px/s²).
@export var friction: float = 1100.0

## Dernière direction regardée (utile plus tard pour viser, récolter...).
var facing: Vector2 = Vector2.DOWN
## false : le joueur ne répond plus aux commandes (fin de sortie, cinématique...).
var controls_enabled: bool = true

@onready var exposure: ExposureComponent = $Exposure
@onready var interactor: Interactor = $Interactor
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

var _feedback_tween: Tween


func _physics_process(delta: float) -> void:
	var input_dir: Vector2 = Vector2.ZERO
	if controls_enabled:
		input_dir = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")

	if input_dir != Vector2.ZERO:
		facing = input_dir.normalized()
		velocity = velocity.move_toward(input_dir * move_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
	_update_animation(input_dir != Vector2.ZERO)


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	interactor.set_physics_process(enabled)


func _unhandled_input(event: InputEvent) -> void:
	if controls_enabled and event.is_action_pressed(&"attack"):
		_play_feedback(Vector2(1.25, 0.8))


## Animations td2d : idle_<dir> et walk_<dir>, avec dir = s, e, n ou w.
func _update_animation(moving: bool) -> void:
	var animation_name: StringName = StringName(("walk_" if moving else "idle_") + direction_name(facing))
	if _sprite.animation != animation_name:
		_sprite.play(animation_name)


## Direction cardinale la plus proche d'un vecteur : "s", "e", "n" ou "w".
static func direction_name(direction: Vector2) -> String:
	if absf(direction.x) > absf(direction.y):
		return "e" if direction.x > 0.0 else "w"
	return "s" if direction.y >= 0.0 else "n"


## Retour visuel temporaire du coup, en attendant le combat et les animations.
func _play_feedback(squash: Vector2) -> void:
	if _feedback_tween:
		_feedback_tween.kill()
	_sprite.scale = squash
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(_sprite, "scale", Vector2.ONE, 0.12)
