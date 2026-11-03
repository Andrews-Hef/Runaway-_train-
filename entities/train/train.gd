class_name Train
extends Node2D
## Le train : à quai pendant un arrêt, ou en marche pendant un trajet.
##
## Il ne décide de rien : la zone (ou le trajet) lui dit quand siffler et partir.
## La porte du wagon est un Interactable (« Monter à bord »).

signal boarding_requested

## Distance parcourue en partant (sort de l'écran par la droite).
@export var departure_distance: float = 900.0
@export var departure_duration: float = 3.5
## Démarrer directement en marche (scène de trajet).
@export var start_running: bool = false

@onready var door: Interactable = $Door
@onready var _body: StaticBody2D = $Body
@onready var _cars: Node2D = $Cars
@onready var _smoke: CPUParticles2D = $Cars/Locomotive/Smoke

var running: bool = false
var _shake_tween: Tween


func _ready() -> void:
	door.interacted.connect(func(_actor: Node2D) -> void: boarding_requested.emit())
	if start_running:
		set_running(true)
	else:
		set_running(false)


## En marche : roues qui tournent et grosse fumée. À l'arrêt : un filet de fumée.
func set_running(value: bool) -> void:
	running = value
	for car: Node in _cars.get_children():
		if car is AnimatedSprite2D:
			(car as AnimatedSprite2D).play(&"run_s" if value else &"idle_s")
	_smoke.amount = 24 if value else 6
	_smoke.initial_velocity_min = 18.0 if value else 6.0
	_smoke.initial_velocity_max = 28.0 if value else 10.0


## Le sifflet : le train tremble et crache un jet de vapeur.
func whistle() -> void:
	if _shake_tween:
		_shake_tween.kill()
	_shake_tween = create_tween().set_loops(6)
	_shake_tween.tween_property(_cars, "position:x", 1.0, 0.05)
	_shake_tween.tween_property(_cars, "position:x", -1.0, 0.05)
	_shake_tween.finished.connect(func() -> void: _cars.position.x = 0.0)
	_smoke.restart()
	_smoke.amount = 24


## Le train s'en va vers la droite. Renvoie le tween pour pouvoir l'attendre.
func depart() -> Tween:
	door.monitorable = false
	_body.process_mode = Node.PROCESS_MODE_DISABLED
	set_running(true)
	var tween := create_tween()
	tween.tween_property(self, "position:x", position.x + departure_distance, departure_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return tween
