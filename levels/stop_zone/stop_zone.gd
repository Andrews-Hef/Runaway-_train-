extends Node2D
## Zone d'arrêt : le train s'arrête, le joueur sort récolter, puis remonte avant le départ.
##
## La zone est différente à chaque arrêt : GameState fournit le type de zone et
## la graine, ZoneGenerator produit le plan, et ce script l'applique (tuiles,
## objets, train) puis branche les systèmes entre eux. Les règles vivent dans
## les systèmes eux-mêmes : StopSession, ExposureComponent, Harvestable, Train.

const JOURNEY_SCENE: String = "res://levels/journey/journey.tscn"

## Scène à instancier pour chaque type d'objet du plan.
const SCENES: Dictionary[StringName, PackedScene] = {
	&"wreck": preload("res://props/wreck/wreck.tscn"),
	&"dead_tree": preload("res://props/dead_tree/dead_tree.tscn"),
	&"rock": preload("res://props/rock/rock.tscn"),
	&"herb": preload("res://props/plant/herb.tscn"),
	&"infected_herb": preload("res://props/plant/infected_herb.tscn"),
	&"house": preload("res://props/house_ruin/house_ruin.tscn"),
	&"cache": preload("res://props/cache/cache.tscn"),
	&"shelter": preload("res://props/shelter/shelter.tscn"),
	&"cart": preload("res://props/cart/cart.tscn"),
	&"refugee": preload("res://entities/npc/refugee.tscn"),
	&"merchant": preload("res://entities/npc/merchant.tscn"),
	&"backpack": preload("res://props/backpack/backpack.tscn"),
	&"locker": preload("res://props/locker/locker.tscn"),
}

const GROUND_SOURCE_ID: int = 0

## Pour tester un type de zone précis depuis l'éditeur (vide = celui de GameState).
@export var zone_override: ZoneProfile
## Graine forcée pour reproduire une zone (0 = celle de GameState).
@export var seed_override: int = 0

@onready var _ground: InfectionGround = $Ground
@onready var _world: Node2D = $World
@onready var _train: Train = $World/Train
@onready var _player: Player = $World/Player
@onready var _camera: Camera2D = $World/Player/Camera2D
@onready var _session: StopSession = $StopSession
@onready var _hud: CanvasLayer = $Hud
@onready var _result_screen: CanvasLayer = $ResultScreen
@onready var _dialog: CanvasLayer = $EncounterDialog

var layout: ZoneGenerator.Layout
var zone: ZoneProfile

## Hasard des rencontres (gains aléatoires, prénoms, infection cachée).
var _encounter_rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Rencontre en cours (null si aucune fenêtre ouverte).
var _active_spot: EncounterSpot


func _ready() -> void:
	zone = zone_override if zone_override else GameState.current_zone
	var zone_seed: int = seed_override if seed_override != 0 else GameState.current_seed
	var player_spawn: Vector2 = ZoneGenerator.TRAIN_POSITION + _train.door.position + Vector2(0.0, 40.0)
	layout = ZoneGenerator.generate(zone, zone_seed, [player_spawn])
	_encounter_rng.seed = zone_seed + 1
	_apply_layout()
	_build_bounds()
	_setup_camera()
	_wire_systems()
	_session.start(layout.stop_duration)


# --- Application du plan --------------------------------------------------------

func _apply_layout() -> void:
	var size: Vector2i = layout.size_in_tiles
	for y: int in size.y:
		for x: int in size.x:
			var cell := Vector2i(x, y)
			_ground.set_cell(cell, GROUND_SOURCE_ID, Vector2i(layout.tile_at(cell), 0))

	_train.position = layout.train_position
	_player.position = layout.train_position + _train.door.position + Vector2(0.0, 40.0)

	for spawn: ZoneGenerator.Spawn in layout.spawns:
		var node := SCENES[spawn.kind].instantiate() as Node2D
		node.position = spawn.position
		_world.add_child(node)
		if node is Harvestable:
			_connect_harvestable(node as Harvestable)
		elif node is EncounterSpot:
			var spot := node as EncounterSpot
			spot.encounter = EncounterLibrary.get_encounter(spawn.data)
			spot.encounter_requested.connect(_open_encounter)


## Quatre murs invisibles autour de la zone.
func _build_bounds() -> void:
	var size_px := Vector2(layout.size_in_pixels())
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
	var size_px: Vector2i = layout.size_in_pixels()
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
	_hud.call(&"bind", _session, _player, GameState.LOOT_TYPES)
	_hud.call(&"announce_zone", GameState.stop_number, zone.display_name)
	_dialog.connect(&"choice_selected", _on_choice_selected)
	_dialog.connect(&"closed", _on_dialog_closed)
	_result_screen.connect(&"continue_requested", _continue_journey)
	_result_screen.connect(&"new_run_requested", _new_run)


func _connect_harvestable(harvestable: Harvestable) -> void:
	harvestable.harvested.connect(func(loot: LootData, amount: int, exposure: float) -> void:
		_session.add_loot(loot, amount)
		_player.exposure.add(exposure)
	)


# --- Rencontres -------------------------------------------------------------------

func _open_encounter(spot: EncounterSpot) -> void:
	if not _session.is_running() or _dialog.call(&"is_open"):
		return
	_active_spot = spot
	_player.set_controls_enabled(false)
	_dialog.call(&"open", spot.encounter, _session.result)


func _on_choice_selected(choice: EncounterChoice) -> void:
	if _active_spot == null:
		return
	if choice.leave:
		_dialog.call(&"show_outcome", choice.outcome_text, {} as Dictionary[StringName, int], false)
		return
	var outcome := _session.resolve_choice(choice, _encounter_rng, GameState.crew_names())
	if outcome == null:
		return
	_player.exposure.add(outcome.exposure)
	var repeatable: bool = _active_spot.encounter.repeatable
	if not repeatable:
		_active_spot.mark_resolved(outcome.recruit != null)
	_dialog.call(&"show_outcome", outcome.text, outcome.gained, repeatable)


func _on_dialog_closed() -> void:
	_active_spot = null
	if _session.is_running():
		_player.set_controls_enabled(true)


# --- Fin de la sortie -------------------------------------------------------------

func _on_session_ended(result: ExpeditionResult) -> void:
	_dialog.call(&"close")
	_player.set_controls_enabled(false)
	GameState.record_expedition(result)
	if result.boarded:
		_player.visible = false
		_train.depart()
		await get_tree().create_timer(1.5).timeout
	else:
		await _train.depart().finished
	_result_screen.call(&"show_result", result, GameState.LOOT_TYPES)
	get_tree().paused = true


func _continue_journey() -> void:
	get_tree().paused = false
	GameState.prepare_next_stop()
	get_tree().change_scene_to_file(JOURNEY_SCENE)


func _new_run() -> void:
	get_tree().paused = false
	GameState.new_run()
	get_tree().change_scene_to_file(JOURNEY_SCENE)
