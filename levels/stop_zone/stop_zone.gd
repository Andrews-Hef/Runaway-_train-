extends Node2D
## Zone d'arrêt : le train s'arrête, le joueur sort récolter, puis remonte avant le départ.
##
## Ce script assemble la zone (sol, voie ferrée, objets, train) et branche les
## systèmes entre eux. Les règles vivent dans les systèmes eux-mêmes :
## StopSession (temps, butin, fin), ExposureComponent, Harvestable, Train.

const ROCK_SCENE: PackedScene = preload("res://props/rock/rock.tscn")
const WRECK_SCENE: PackedScene = preload("res://props/wreck/wreck.tscn")
const DEAD_TREE_SCENE: PackedScene = preload("res://props/dead_tree/dead_tree.tscn")
const HERB_SCENE: PackedScene = preload("res://props/plant/herb.tscn")
const INFECTED_HERB_SCENE: PackedScene = preload("res://props/plant/infected_herb.tscn")

## Types de ressources affichés dans le HUD et le bilan, dans cet ordre.
const LOOT_TYPES: Array[LootData] = [
	preload("res://data/loot/scrap.tres"),
	preload("res://data/loot/wood.tres"),
	preload("res://data/loot/herb.tres"),
	preload("res://data/loot/infected_herb.tres"),
]

const TILE_SIZE: int = 16
const GROUND_SOURCE_ID: int = 0

## Index des tuiles dans assets/tiles/ground_placeholder.png
enum GroundTile { GRASS_A, GRASS_B, DIRT, INFECTED, RAILS }
## Où un objet a le droit d'apparaître.
enum Placement { ANYWHERE, HEALTHY, INFECTED }

@export var size_in_tiles: Vector2i = Vector2i(48, 28)
## Graine fixe : la zone est identique à chaque partie (utile pour régler l'équilibrage).
@export var random_seed: int = 42
## Ligne de tuiles occupée par la voie ferrée.
@export var rails_row: int = 4
## Zones infectées : x, y = centre en tuiles, z = rayon en tuiles.
@export var infected_patches: Array[Vector3] = [Vector3(34, 15, 6.0), Vector3(11, 22, 3.5)]

@export_group("Objets")
@export var wreck_count: int = 5
@export var tree_count: int = 8
@export var rock_count: int = 10
@export var herb_count: int = 10
@export var infected_herb_count: int = 9

@onready var _ground: InfectionGround = $Ground
@onready var _world: Node2D = $World
@onready var _train: Train = $World/Train
@onready var _player: Player = $World/Player
@onready var _camera: Camera2D = $World/Player/Camera2D
@onready var _session: StopSession = $StopSession
@onready var _hud: CanvasLayer = $Hud
@onready var _result_screen: CanvasLayer = $ResultScreen

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Positions déjà prises, pour espacer les objets.
var _occupied: Array[Vector2] = []


func _ready() -> void:
	_rng.seed = random_seed
	_paint_ground()
	_place_train_and_player()
	_scatter(WRECK_SCENE, wreck_count, Placement.HEALTHY, 44.0)
	_scatter(DEAD_TREE_SCENE, tree_count, Placement.HEALTHY, 26.0)
	_scatter(ROCK_SCENE, rock_count, Placement.ANYWHERE, 22.0)
	_scatter(HERB_SCENE, herb_count, Placement.HEALTHY, 18.0)
	_scatter(INFECTED_HERB_SCENE, infected_herb_count, Placement.INFECTED, 18.0)
	_build_bounds()
	_setup_camera()
	_wire_systems()


func get_size_in_pixels() -> Vector2i:
	return size_in_tiles * TILE_SIZE


# --- Construction de la zone ---------------------------------------------------

func _paint_ground() -> void:
	for x: int in size_in_tiles.x:
		for y: int in size_in_tiles.y:
			var cell := Vector2i(x, y)
			_ground.set_cell(cell, GROUND_SOURCE_ID, Vector2i(_pick_tile(cell), 0))


func _pick_tile(cell: Vector2i) -> int:
	if cell.y == rails_row:
		return GroundTile.RAILS
	for patch: Vector3 in infected_patches:
		var distance: float = Vector2(cell).distance_to(Vector2(patch.x, patch.y))
		# Lisière irrégulière : on mélange infecté et sain sur le bord.
		if distance < patch.z - 1.0 or (distance < patch.z + 1.0 and _rng.randf() < 0.5):
			return GroundTile.INFECTED
	var roll: float = _rng.randf()
	if roll < 0.1:
		return GroundTile.DIRT
	if roll < 0.45:
		return GroundTile.GRASS_B
	return GroundTile.GRASS_A


func _place_train_and_player() -> void:
	var rails_y: float = (rails_row + 0.5) * TILE_SIZE
	_train.position = Vector2(3.0 * TILE_SIZE, rails_y)
	_player.position = _train.position + _train.door.position + Vector2(0.0, 40.0)
	_occupied.append(_player.position)


## Place `count` objets au hasard, espacés d'au moins `spacing` pixels.
func _scatter(scene: PackedScene, count: int, placement: Placement, spacing: float) -> void:
	var placed: int = 0
	var attempts: int = 0
	var min_y: float = (rails_row + 3) * TILE_SIZE
	var size_px := Vector2(get_size_in_pixels())
	while placed < count and attempts < count * 40:
		attempts += 1
		var pos := Vector2(
			_rng.randf_range(2.0 * TILE_SIZE, size_px.x - 2.0 * TILE_SIZE),
			_rng.randf_range(min_y, size_px.y - 2.0 * TILE_SIZE)
		).round()
		if not _placement_allows(placement, pos) or not _is_free(pos, spacing):
			continue
		var node := scene.instantiate() as Node2D
		node.position = pos
		_world.add_child(node)
		_occupied.append(pos)
		if node is Harvestable:
			_connect_harvestable(node as Harvestable)
		placed += 1


func _placement_allows(placement: Placement, pos: Vector2) -> bool:
	var infected: bool = _ground.get_infection_at(pos) > 0.0
	match placement:
		Placement.HEALTHY:
			return not infected
		Placement.INFECTED:
			return infected
		_:
			return true


func _is_free(pos: Vector2, spacing: float) -> bool:
	for other: Vector2 in _occupied:
		if pos.distance_to(other) < spacing:
			return false
	return true


## Quatre murs invisibles autour de la zone.
func _build_bounds() -> void:
	var size_px := Vector2(get_size_in_pixels())
	var body := StaticBody2D.new()
	body.name = "Bounds"
	var walls: Array[Array] = [
		[Vector2(0.0, 0.0), Vector2.RIGHT],
		[Vector2(size_px.x, 0.0), Vector2.LEFT],
		[Vector2(0.0, 0.0), Vector2.DOWN],
		[Vector2(0.0, size_px.y), Vector2.UP],
	]
	for wall: Array in walls:
		var shape := WorldBoundaryShape2D.new()
		shape.normal = wall[1]
		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position = wall[0]
		body.add_child(collision)
	add_child(body)


func _setup_camera() -> void:
	var size_px: Vector2i = get_size_in_pixels()
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = size_px.x
	_camera.limit_bottom = size_px.y
	_camera.reset_smoothing()


# --- Branchement des systèmes ----------------------------------------------------

func _wire_systems() -> void:
	_player.exposure.ground = _ground
	_session.exposure_source = _player.exposure
	_train.boarding_requested.connect(_session.board)
	_session.whistle_blown.connect(_train.whistle)
	_session.ended.connect(_on_session_ended)
	_hud.call(&"bind", _session, _player, LOOT_TYPES)
	_result_screen.connect(&"restart_requested", _restart)


func _connect_harvestable(harvestable: Harvestable) -> void:
	harvestable.harvested.connect(func(loot: LootData, amount: int, exposure: float) -> void:
		_session.add_loot(loot, amount)
		_player.exposure.add(exposure)
	)


func _on_session_ended(result: ExpeditionResult) -> void:
	_player.set_controls_enabled(false)
	if result.boarded:
		_player.visible = false
		_train.depart()
		await get_tree().create_timer(1.5).timeout
	else:
		await _train.depart().finished
	_result_screen.call(&"show_result", result, LOOT_TYPES)
	get_tree().paused = true


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
