class_name InteriorPlayer
extends Node2D
## Le joueur à l'intérieur du train, vu de profil : il marche à gauche et à droite.
##
## Mêmes actions que dehors (move_left / move_right, interact) : clavier,
## manette et joystick tactile marchent sans rien changer.

## Vitesse de marche, en pixels par seconde (ici 32 px = 1 m).
@export var move_speed: float = 110.0

## Limites de déplacement (les deux bouts du train), réglées par la scène.
var min_x: float = -INF
var max_x: float = INF
var controls_enabled: bool = true

@onready var interactor: Interactor = $Interactor
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _physics_process(delta: float) -> void:
	var direction: float = 0.0
	if controls_enabled and not interactor.is_holding():
		direction = Input.get_axis(&"move_left", &"move_right")
	position.x = clampf(position.x + direction * move_speed * delta, min_x, max_x)
	if absf(direction) > 0.1:
		_sprite.flip_h = direction < 0.0
	var animation_name: StringName = &"walk_e" if absf(direction) > 0.1 else &"idle_e"
	if _sprite.animation != animation_name:
		_sprite.play(animation_name)


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	interactor.set_physics_process(enabled)
