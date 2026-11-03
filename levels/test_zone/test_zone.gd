extends Node2D
## Zone de test : sol généré, rochers, limites et caméra.
##
## Sert à valider le déplacement PC + mobile avant le vrai contenu.
## Le violet (tuile INFECTED) est purement visuel pour l'instant :
## la jauge d'exposition arrivera avec la récolte.

const ROCK_SCENE: PackedScene = preload("res://props/rock/rock.tscn")
const TILE_SIZE: int = 16
const GROUND_SOURCE_ID: int = 0

## Index des tuiles dans assets/tiles/ground_placeholder.png
enum GroundTile { GRASS_A, GRASS_B, DIRT, INFECTED }

@export var size_in_tiles: Vector2i = Vector2i(40, 24)
@export var rock_count: int = 14
## Graine fixe : la zone de test est identique à chaque lancement.
@export var random_seed: int = 42
@export var infected_center: Vector2i = Vector2i(30, 7)
@export var infected_radius: float = 5.0
## Distance minimale entre le point d'apparition et un rocher.
@export var spawn_clearance: float = 48.0

@onready var _ground: TileMapLayer = $Ground
@onready var _world: Node2D = $World
@onready var _player: Player = $World/Player
@onready var _camera: Camera2D = $World/Player/Camera2D

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = random_seed
	_player.position = Vector2(size_in_tiles * TILE_SIZE) / 2.0
	_paint_ground()
	_spawn_rocks()
	_build_bounds()
	_setup_camera()


func get_size_in_pixels() -> Vector2i:
	return size_in_tiles * TILE_SIZE


func _paint_ground() -> void:
	for x: int in size_in_tiles.x:
		for y: int in size_in_tiles.y:
			var cell := Vector2i(x, y)
			_ground.set_cell(cell, GROUND_SOURCE_ID, Vector2i(_pick_tile(cell), 0))


func _pick_tile(cell: Vector2i) -> int:
	var distance: float = Vector2(cell - infected_center).length()
	# Bord irrégulier : on mélange infecté / sain sur la lisière.
	if distance < infected_radius - 1.0 or (distance < infected_radius + 1.0 and _rng.randf() < 0.5):
		return GroundTile.INFECTED
	var roll: float = _rng.randf()
	if roll < 0.1:
		return GroundTile.DIRT
	if roll < 0.45:
		return GroundTile.GRASS_B
	return GroundTile.GRASS_A


func _spawn_rocks() -> void:
	var placed: int = 0
	var attempts: int = 0
	while placed < rock_count and attempts < rock_count * 20:
		attempts += 1
		var tile := Vector2(
			_rng.randf_range(2.0, size_in_tiles.x - 2.0),
			_rng.randf_range(2.0, size_in_tiles.y - 2.0)
		)
		var pos: Vector2 = (tile * TILE_SIZE).round()
		if pos.distance_to(_player.position) < spawn_clearance:
			continue
		var rock := ROCK_SCENE.instantiate() as Node2D
		rock.position = pos
		_world.add_child(rock)
		placed += 1


## Quatre murs invisibles autour de la zone.
func _build_bounds() -> void:
	var size_px := Vector2(get_size_in_pixels())
	var body := StaticBody2D.new()
	body.name = "Bounds"
	var walls: Array[Array] = [
		[Vector2(0.0, 0.0), Vector2.RIGHT],        # gauche
		[Vector2(size_px.x, 0.0), Vector2.LEFT],   # droite
		[Vector2(0.0, 0.0), Vector2.DOWN],         # haut
		[Vector2(0.0, size_px.y), Vector2.UP],     # bas
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
