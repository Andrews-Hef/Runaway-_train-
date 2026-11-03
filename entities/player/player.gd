class_name Player
extends CharacterBody2D
## Personnage joueur en vue de dessus.
##
## Il ne lit QUE les actions de l'InputMap (move_*, attack, interact).
## Clavier, manette et contrôles tactiles passent tous par ces actions :
## le joueur ne sait pas (et n'a pas à savoir) quel périphérique est utilisé.

## Vitesse de déplacement max, en pixels de jeu par seconde.
@export var move_speed: float = 80.0
## Vitesse à laquelle on atteint move_speed (px/s²).
@export var acceleration: float = 900.0
## Vitesse à laquelle on s'arrête quand on lâche les commandes (px/s²).
@export var friction: float = 1100.0

## Dernière direction regardée (utile plus tard pour viser, récolter...).
var facing: Vector2 = Vector2.DOWN

@onready var _sprite: Sprite2D = $Sprite2D

var _feedback_tween: Tween


func _physics_process(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")

	if input_dir != Vector2.ZERO:
		facing = input_dir.normalized()
		velocity = velocity.move_toward(input_dir * move_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()

	if absf(input_dir.x) > 0.1:
		_sprite.flip_h = input_dir.x < 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"attack"):
		_play_feedback(Vector2(1.25, 0.8), Color.WHITE)
	elif event.is_action_pressed(&"interact"):
		_play_feedback(Vector2.ONE, Color(1.6, 1.6, 1.6))


## Retour visuel temporaire, en attendant les vraies animations.
func _play_feedback(squash: Vector2, flash: Color) -> void:
	if _feedback_tween:
		_feedback_tween.kill()
	_sprite.scale = squash
	_sprite.modulate = flash
	_feedback_tween = create_tween().set_parallel()
	_feedback_tween.tween_property(_sprite, "scale", Vector2.ONE, 0.12)
	_feedback_tween.tween_property(_sprite, "modulate", Color.WHITE, 0.12)
