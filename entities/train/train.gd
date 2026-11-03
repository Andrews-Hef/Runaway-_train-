class_name Train
extends Node2D
## Le train à quai pendant un arrêt.
##
## Il ne décide de rien : la StopSession lui dit quand siffler et quand partir.
## La porte du wagon est un Interactable (« Monter à bord »).

signal boarding_requested

## Distance parcourue en partant (sort de l'écran par la droite).
@export var departure_distance: float = 900.0
@export var departure_duration: float = 3.5

@onready var door: Interactable = $Door
@onready var _body: StaticBody2D = $Body
@onready var _cars: Node2D = $Cars

var _shake_tween: Tween


func _ready() -> void:
	door.interacted.connect(func(_actor: Node2D) -> void: boarding_requested.emit())


## Le sifflet : le train tremble, en attendant le son et la vapeur.
func whistle() -> void:
	if _shake_tween:
		_shake_tween.kill()
	_shake_tween = create_tween().set_loops(6)
	_shake_tween.tween_property(_cars, "position:x", 1.0, 0.05)
	_shake_tween.tween_property(_cars, "position:x", -1.0, 0.05)
	_shake_tween.finished.connect(func() -> void: _cars.position.x = 0.0)


## Le train s'en va vers la droite. Renvoie le tween pour pouvoir l'attendre.
func depart() -> Tween:
	door.monitorable = false
	_body.process_mode = Node.PROCESS_MODE_DISABLED
	var tween := create_tween()
	tween.tween_property(self, "position:x", position.x + departure_distance, departure_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return tween
