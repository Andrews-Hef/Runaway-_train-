class_name Train
extends Node2D
## Le train : à quai pendant un arrêt, ou en marche pendant un trajet.
##
## Il ne décide de rien : la zone (ou le trajet) lui dit quand siffler et partir.
## La porte du wagon est un Interactable (« Monter à bord »).
##
## Le nombre de wagons suit la composition du train (set_wagon_count) : les wagons
## en plus s'attellent en queue, vers la gauche. La porte et la locomotive ne
## bougent pas, donc la zone d'arrêt garde le même plan.

signal boarding_requested

## Distance parcourue en partant (sort de l'écran par la droite).
@export var departure_distance: float = 900.0
@export var departure_duration: float = 3.5
## Démarrer directement en marche (scène de trajet).
@export var start_running: bool = false

## Wagons dessinés dans la scène (WagonRear, WagonFront).
const BASE_WAGONS: int = 2
## Écart entre deux wagons, en pixels.
const WAGON_PITCH: float = 104.0
const WAGON_FRAMES: SpriteFrames = preload("res://assets/sprites/wagon/wagon.tres")
## Vitesse de l'animation des roues en marche (1 = vitesse td2d).
const RUN_ANIMATION_SPEED: float = 0.55

@onready var door: Interactable = $Door
@onready var _body: StaticBody2D = $Body
@onready var _cars: Node2D = $Cars
@onready var _smoke: CPUParticles2D = $Cars/Locomotive/Smoke
@onready var _body_shape: CollisionShape2D = $Body/CollisionShape2D

var running: bool = false
var _shake_tween: Tween
var _extra_wagons: int = 0
var _base_body_size: Vector2
var _base_body_x: float


func _ready() -> void:
	_base_body_size = (_body_shape.shape as RectangleShape2D).size
	_base_body_x = _body_shape.position.x
	door.interacted.connect(func(_actor: Node2D) -> void: boarding_requested.emit())
	if start_running:
		set_running(true)
	else:
		set_running(false)


## Nombre de wagons derrière la locomotive (2 sont toujours dessinés).
func set_wagon_count(count: int) -> void:
	for child: Node in _cars.get_children():
		if child.name.begins_with("WagonExtra"):
			_cars.remove_child(child)
			child.queue_free()
	_extra_wagons = maxi(count - BASE_WAGONS, 0)
	var rear: AnimatedSprite2D = $Cars/WagonRear
	for i: int in _extra_wagons:
		var wagon := AnimatedSprite2D.new()
		wagon.name = "WagonExtra%d" % i
		wagon.sprite_frames = WAGON_FRAMES
		wagon.centered = false
		wagon.offset = rear.offset
		wagon.position = rear.position - Vector2(WAGON_PITCH * (i + 1), 0.0)
		_cars.add_child(wagon)
		_cars.move_child(wagon, 0)
	# Le corps physique couvre tout le train.
	var shape := RectangleShape2D.new()
	shape.size = _base_body_size + Vector2(WAGON_PITCH * _extra_wagons, 0.0)
	_body_shape.shape = shape
	_body_shape.position.x = _base_body_x - WAGON_PITCH * _extra_wagons / 2.0
	set_running(running)


## Longueur du train en pixels, de la queue au bout de la locomotive.
func length() -> float:
	return _base_body_size.x + WAGON_PITCH * _extra_wagons


## Un point du flanc du train, côté quai (là où la horde frappe) : t = 0 queue, 1 tête.
func flank_point(t: float) -> Vector2:
	var shape := _body_shape.shape as RectangleShape2D
	var left: float = _body_shape.position.x - shape.size.x / 2.0
	var local := Vector2(left + shape.size.x * clampf(t, 0.0, 1.0), _body_shape.position.y + shape.size.y / 2.0 + 8.0)
	return to_global(local)


## Coup reçu (horde) : le train rougit un instant.
func hit_flash() -> void:
	_cars.modulate = Color(1.0, 0.5, 0.45)
	create_tween().tween_property(_cars, "modulate", Color.WHITE, 0.3)


## En marche : roues qui tournent et grosse fumée. À l'arrêt : un filet de fumée.
func set_running(value: bool) -> void:
	running = value
	for car: Node in _cars.get_children():
		if car is AnimatedSprite2D:
			(car as AnimatedSprite2D).play(&"run_s" if value else &"idle_s")
			# Les roues tournent au rythme du décor qui défile (ralenti).
			(car as AnimatedSprite2D).speed_scale = RUN_ANIMATION_SPEED if value else 1.0
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
	var distance: float = departure_distance + WAGON_PITCH * _extra_wagons
	tween.tween_property(self, "position:x", position.x + distance, departure_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return tween
