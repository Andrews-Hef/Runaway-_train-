extends Node2D
## Gare refuge : une ville fortifiée sur la ligne, tous les GameState.REFUGE_EVERY arrêts.
##
## Zone sûre : pas d'infection, pas de chrono, le train attend. On y trouve :
## - le comptoir (échanger le surplus du stock),
## - le bureau de quarantaine (recrues saines, contre des matériaux),
## - le mécanicien du dépôt (renforcer la locomotive).
## On repart en remontant à bord.

const JOURNEY_SCENE: String = "res://levels/journey/journey.tscn"
const RefugeMenu = preload("res://ui/refuge/refuge_menu.gd")
const TILE_SIZE: int = ZoneGenerator.TILE_SIZE
const SIZE_IN_TILES: Vector2i = Vector2i(40, 17)

const STATION_HOUSE: Texture2D = preload("res://assets/sprites/props/station_house.png")
const PALISADE: Texture2D = preload("res://assets/sprites/props/palisade.png")
const CART: Texture2D = preload("res://assets/sprites/props/cart.png")
const SHELTER: Texture2D = preload("res://assets/sprites/props/shelter.png")
const WORKBENCH: Texture2D = preload("res://assets/sprites/interior/workbench.png")
const MERCHANT_FRAMES: SpriteFrames = preload("res://assets/sprites/merchant/merchant.tres")
const PEOPLE_FRAMES: SpriteFrames = preload("res://assets/sprites/refugee/refugee.tres")

## Postes de la gare : [position, poste, texte, onglet du menu].
const STATIONS: Array[Array] = [
	[Vector2(250, 196), &"trade", "Comptoir : échanger", RefugeMenu.Tab.TRADE],
	[Vector2(520, 190), &"recruit", "Bureau de quarantaine : recruter", RefugeMenu.Tab.RECRUIT],
	[Vector2(392, 104), &"depot", "Dépôt : renforcer la locomotive", RefugeMenu.Tab.DEPOT],
]

@onready var _ground: TileMapLayer = $Ground
@onready var _world: Node2D = $World
@onready var _train: Train = $World/Train
@onready var _player: Player = $World/Player
@onready var _camera: Camera2D = $World/Player/Camera2D
@onready var _menu: CanvasLayer = $RefugeMenu
@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _prompt: Label = %Prompt
@onready var _fade: ColorRect = %Fade

var refuge: RefugeData
var _target: Interactable
var _leaving: bool = false


func _ready() -> void:
	refuge = GameState.current_refuge if GameState.current_refuge else GameState.REFUGES[0]
	_paint_ground()
	_build_bounds()
	_build_town()
	_train.set_wagon_count(GameState.train.size() - 1)
	_train.position = ZoneGenerator.TRAIN_POSITION
	_train.door.prompt = "Repartir"
	_train.boarding_requested.connect(_leave)
	_player.position = ZoneGenerator.TRAIN_POSITION + _train.door.position + Vector2(0.0, 40.0)
	_camera.limit_right = SIZE_IN_TILES.x * TILE_SIZE
	_camera.limit_bottom = SIZE_IN_TILES.y * TILE_SIZE
	_camera.reset_smoothing()
	_player.interactor.target_changed.connect(_on_target_changed)
	_menu.call(&"setup", refuge, GameState.current_seed)
	_menu.connect(&"closed", _on_menu_closed)
	InputMode.changed.connect(func(_device: int) -> void: _refresh_prompt())
	_title.text = "Arrêt n°%d : %s" % [GameState.stop_number, refuge.display_name]
	_subtitle.text = "Zone sûre : pas d'infection, le train attend. Remonte à bord pour repartir."
	_fade.color.a = 1.0
	create_tween().tween_property(_fade, "color:a", 0.0, 0.4)


# --- Construction ------------------------------------------------------------------

## Voie en haut, quai en terre battue dessous, place et chemins dans la ville.
func _paint_ground() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.current_seed
	for y: int in SIZE_IN_TILES.y:
		for x: int in SIZE_IN_TILES.x:
			var tile: int = ZoneGenerator.Tile.GRASS_B if rng.randf() < 0.4 else ZoneGenerator.Tile.GRASS_A
			if y == ZoneGenerator.RAILS_ROW:
				tile = ZoneGenerator.Tile.RAILS
			elif y > ZoneGenerator.RAILS_ROW and y <= ZoneGenerator.RAILS_ROW + ZoneGenerator.PLATFORM_ROWS:
				tile = ZoneGenerator.Tile.DIRT
			elif y > ZoneGenerator.RAILS_ROW and (absi(x - 25) <= 1 or (y >= 11 and y <= 13 and x >= 10 and x <= 37)):
				tile = ZoneGenerator.Tile.DIRT # chemins vers les postes
			_ground.set_cell(Vector2i(x, y), 0, Vector2i(tile, 0))


func _build_bounds() -> void:
	var size_px := Vector2(SIZE_IN_TILES * TILE_SIZE)
	var body := StaticBody2D.new()
	body.name = "Bounds"
	for wall: Array in [[Vector2.ZERO, Vector2.RIGHT], [Vector2(size_px.x, 0.0), Vector2.LEFT],
			[Vector2.ZERO, Vector2.DOWN], [Vector2(0.0, size_px.y), Vector2.UP]]:
		var shape := WorldBoundaryShape2D.new()
		shape.normal = wall[1]
		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position = wall[0]
		body.add_child(collision)
	add_child(body)


func _build_town() -> void:
	# Palissades : derrière la voie et en bas de la ville.
	for x: float in range(24, SIZE_IN_TILES.x * TILE_SIZE, 46):
		_add_prop(PALISADE, Vector2(30, 53), Vector2(x, 46.0), Vector2.ZERO)
		_add_prop(PALISADE, Vector2(30, 53), Vector2(x, 268.0), Vector2(46, 8))
	_add_prop(STATION_HOUSE, Vector2(60, 94), Vector2(400, 214), Vector2(92, 22))
	_add_prop(CART, Vector2(40, 48), Vector2(212, 204), Vector2(40, 14))
	_add_prop(SHELTER, Vector2(32, 47), Vector2(560, 200), Vector2(44, 18))
	_add_prop(WORKBENCH, Vector2(22, 43), Vector2(428, 100), Vector2(30, 8))
	_add_person(MERCHANT_FRAMES, STATIONS[0][0], Color.WHITE)
	_add_person(PEOPLE_FRAMES, STATIONS[1][0], Color(0.85, 1.0, 0.9))
	_add_person(PEOPLE_FRAMES, STATIONS[2][0], Color(1.0, 0.85, 0.7))
	for station: Array in STATIONS:
		_add_station(station[0], station[1], station[2], station[3])


func _add_prop(texture: Texture2D, pivot: Vector2, at: Vector2, footprint: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = at
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.offset = -pivot
	body.add_child(sprite)
	if footprint != Vector2.ZERO:
		body.add_child(_box(Rect2(-footprint / 2.0 - Vector2(0.0, footprint.y / 2.0), footprint)))
	_world.add_child(body)


func _add_person(frames: SpriteFrames, at: Vector2, tint: Color) -> void:
	var body := StaticBody2D.new()
	body.position = at
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.centered = false
	sprite.offset = Vector2(-18, -36)
	sprite.modulate = tint
	sprite.play(&"idle_s")
	body.add_child(sprite)
	body.add_child(_box(Rect2(-5, -3, 10, 6)))
	_world.add_child(body)


func _add_station(at: Vector2, station: StringName, text: String, tab: int) -> void:
	var spot := Interactable.new()
	spot.name = "Station_" + String(station)
	spot.prompt = text
	spot.hold_time = 0.25
	spot.indicator_offset = Vector2(0.0, -44.0)
	spot.position = at
	spot.add_child(_box(Rect2(-14, -8, 28, 22)))
	spot.interacted.connect(func(_actor: Node2D) -> void: _open_menu(tab))
	_world.add_child(spot)


static func _box(rect: Rect2) -> CollisionShape2D:
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = rect.get_center()
	return collision


# --- Interaction --------------------------------------------------------------------

func _open_menu(tab: int) -> void:
	if _leaving:
		return
	_player.set_controls_enabled(false)
	_prompt.visible = false
	_menu.call(&"open", tab)


func _on_menu_closed() -> void:
	_player.set_controls_enabled(true)
	_refresh_prompt()


## On remonte à bord : le train repart vers l'arrêt suivant.
func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	_player.set_controls_enabled(false)
	_player.visible = false
	_prompt.visible = false
	_train.depart()
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(_fade, "color:a", 1.0, 0.4)
	tween.tween_callback(func() -> void:
		GameState.prepare_next_stop()
		get_tree().change_scene_to_file(JOURNEY_SCENE))


func _on_target_changed(target: Interactable) -> void:
	_target = target
	_refresh_prompt()


func _refresh_prompt() -> void:
	if _leaving:
		return
	_prompt.visible = is_instance_valid(_target)
	if _prompt.visible:
		_prompt.text = "Maintenir %s : %s" % [InputMode.label_for(&"interact"), _target.prompt]
