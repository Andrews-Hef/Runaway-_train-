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
	&"heavy_wreck": preload("res://props/truck_wreck/truck_wreck.tscn"),
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

const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
## Chance de trouver un plan en fouillant une caisse.
const CACHE_PLAN_CHANCE: float = 0.2
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
## Hasard du combat (vols), séparé de celui des rencontres.
var _combat_rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Armure du joueur pour cet arrêt (équipement + talents).
var _armor: int = 0
## Vitesse du joueur sans malus d'infection.
var _base_speed: float = 0.0
var _infection_stage: int = -1
## Rencontre en cours (null si aucune fenêtre ouverte).
var _active_spot: EncounterSpot


func _ready() -> void:
	zone = zone_override if zone_override else GameState.current_zone
	var zone_seed: int = seed_override if seed_override != 0 else GameState.current_seed
	var player_spawn: Vector2 = ZoneGenerator.TRAIN_POSITION + _train.door.position + Vector2(0.0, 40.0)
	layout = ZoneGenerator.generate(zone, zone_seed, [player_spawn], GameState.stop_number)
	_encounter_rng.seed = zone_seed + 1
	_combat_rng.seed = zone_seed + 2
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

	_train.set_wagon_count(GameState.train.size() - 1)
	_train.position = layout.train_position
	_player.position = layout.train_position + _train.door.position + Vector2(0.0, 40.0)

	for spawn: ZoneGenerator.Spawn in layout.spawns:
		var enemy_data: EnemyData = EnemyCatalog.get_enemy(spawn.kind)
		if enemy_data:
			_spawn_enemy(enemy_data, spawn.position)
			continue
		var node := SCENES[spawn.kind].instantiate() as Node2D
		node.position = spawn.position
		_world.add_child(node)
		if node is Harvestable:
			_connect_harvestable(node as Harvestable)
		elif node is EncounterSpot:
			var spot := node as EncounterSpot
			spot.encounter = EncounterLibrary.get_encounter(spawn.data)
			spot.encounter_requested.connect(_open_encounter)


func _spawn_enemy(enemy_data: EnemyData, at: Vector2) -> void:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.data = enemy_data
	enemy.position = at
	enemy.name = String(enemy_data.id).to_pascal_case()
	_world.add_child(enemy, true)
	enemy.target = _player
	enemy.attack_landed.connect(_on_enemy_attack)
	enemy.shot_fired.connect(_on_enemy_shot)
	enemy.grabbed.connect(_on_enemy_grab)
	enemy.died.connect(_on_enemy_died)


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
	var loadout: Loadout = GameState.loadout
	_player.exposure.ground = _ground
	# L'infection continue celle des arrêts précédents : elle ne redescend pas toute seule.
	_player.exposure.value = GameState.infection
	_base_speed = _player.move_speed
	# Équipement + talents de la carrière.
	_player.exposure.protection = minf(loadout.protection() + GameState.perk_bonus(&"protection"), Loadout.MAX_PROTECTION)
	var harvest_bonus: float = 1.0 + GameState.perk_bonus(&"harvest_speed")
	_player.interactor.speed_for = func(target: Interactable) -> float:
		return loadout.harvest_speed_for((target as Harvestable).harvest_tag) * harvest_bonus if target is Harvestable else 1.0
	_player.interactor.block_reason_for = func(target: Interactable) -> String:
		if not target is Harvestable:
			return ""
		var needed: StringName = (target as Harvestable).required_tag
		if needed != &"" and not _tool_has_tag(needed):
			return "Il faut : " + _tool_name_for(needed)
		return "Sac plein !" if _session.is_bag_full() else ""
	_session.capacity = GameState.bag_capacity()
	_session.free_beds = GameState.free_beds()
	_session.plan_pool = GameState.unfound_plans()
	_player.attack_damage = maxi(loadout.damage(), 1) + int(GameState.perk_bonus(&"damage"))
	_player.mash_power = 1.0 + GameState.perk_bonus(&"mash_power")
	_player.health.reset(GameState.max_health())
	_on_infection_changed(_player.exposure.value)
	_player.exposure.changed.connect(_on_infection_changed)
	_armor = loadout.armor() + int(GameState.perk_bonus(&"armor"))
	_player.health.died.connect(_session.fall)
	_player.freed.connect(func(by: Node2D) -> void:
		if by is Enemy:
			(by as Enemy).release_grab())
	_session.exposure_source = _player.exposure
	_train.boarding_requested.connect(_session.board)
	_session.whistle_blown.connect(_train.whistle)
	_session.ended.connect(_on_session_ended)
	_hud.call(&"bind", _session, _player, GameState.LOOT_TYPES)
	_hud.call(&"show_order", GameState.current_order)
	_hud.call(&"announce_zone", GameState.stop_number, zone.display_name)
	_dialog.connect(&"choice_selected", _on_choice_selected)
	_dialog.connect(&"closed", _on_dialog_closed)
	_result_screen.connect(&"continue_requested", _continue_journey)
	_result_screen.connect(&"retry_requested", _retry)


# --- Combat ------------------------------------------------------------------------

## Un ennemi a porté son coup (ou mord en tenant le joueur) : dégâts, puis
## exposition (infectés) ou vol (pilleurs).
func _on_enemy_attack(enemy: Enemy) -> void:
	if not _session.is_running():
		return
	_apply_hit(enemy.data, enemy.global_position, enemy)


## Un tireur a tiré : le projectile part dans le monde.
func _on_enemy_shot(_enemy: Enemy, projectile: Projectile) -> void:
	_world.add_child(projectile)
	projectile.hit.connect(func(shot: Projectile) -> void:
		if _session.is_running():
			_apply_hit(shot.source, shot.global_position, null))


## Un rampant plaque le joueur au sol.
func _on_enemy_grab(enemy: Enemy) -> void:
	if not _session.is_running() or _player.is_pinned():
		enemy.release_grab()
		return
	_player.pin(enemy, enemy.data.mash_needed)
	_hud.call(&"toast", "%s t'a plaqué au sol !" % enemy.data.display_name, true)


func _apply_hit(enemy_data: EnemyData, from: Vector2, enemy: Enemy) -> void:
	var damage: int = Loadout.damage_after_armor(enemy_data.damage, _armor)
	if _player.health.take_damage(damage, from) == 0:
		return # invincible juste après un coup
	_player.knock_back(from, enemy_data.hit_knockback)
	_player.exposure.add(enemy_data.exposure_on_hit)
	if enemy == null:
		return
	if enemy_data.steal_amount > 0:
		var stolen := _session.steal(enemy_data.steal_amount, _combat_rng)
		for id: StringName in stolen:
			enemy.carried[id] = enemy.carried.get(id, 0) + stolen[id]
		if not stolen.is_empty():
			_hud.call(&"toast", "%s t'a volé %s !" % [enemy_data.display_name, MenuKit.describe_amounts(stolen)], true)


## Un ennemi est tombé : il lâche ce qu'il a volé et son butin (dans la limite du sac).
func _on_enemy_died(enemy: Enemy) -> void:
	if _player.pinned_by == enemy:
		_player.release()
	_session.record_kill(enemy.data)
	var dropped: Dictionary[StringName, int] = enemy.carried.duplicate()
	for id: StringName in enemy.data.drop:
		dropped[id] = dropped.get(id, 0) + enemy.data.drop[id]
	var gained: Dictionary[StringName, int] = {}
	for id: StringName in dropped:
		var taken: int = _session.add_loot(_loot_type(id), dropped[id])
		if taken > 0:
			gained[id] = taken
	if not gained.is_empty():
		_hud.call(&"toast", "Récupéré : " + MenuKit.describe_amounts(gained), false)
	elif not dropped.is_empty():
		_hud.call(&"toast", "Sac plein : tu n'as rien pu ramasser.", true)


func _end_combat() -> void:
	_set_enemies_active(false)
	_player.release()


func _set_enemies_active(value: bool) -> void:
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		(node as Enemy).active = value


static func _loot_type(id: StringName) -> LootData:
	for loot: LootData in GameState.LOOT_TYPES:
		if loot.id == id:
			return loot
	return null


func _connect_harvestable(harvestable: Harvestable) -> void:
	harvestable.harvested.connect(func(loot: LootData, amount: int, exposure: float) -> void:
		_session.add_loot(loot, amount)
		_player.exposure.add(exposure)
		_extract_with_tool(loot)
		if harvestable.harvest_tag == &"cache" and _combat_rng.randf() < CACHE_PLAN_CHANCE:
			var plan: StringName = _session.find_plan(_combat_rng)
			if plan != &"":
				_hud.call(&"toast", "Plan trouvé : %s !" % BlueprintCatalog.get_plan(plan).display_name, false)
	)


## Outil d'extraction (kit de chimie) : une ressource en plus en récoltant la bonne chose.
func _extract_with_tool(loot: LootData) -> void:
	var tool: ItemData = GameState.loadout.get_item(ItemData.Slot.TOOL)
	if tool == null or loot == null or tool.extra_from != loot.id:
		return
	for id: StringName in tool.extra_loot:
		_session.add_loot(_loot_type(id), tool.extra_loot[id])


func _tool_has_tag(tag: StringName) -> bool:
	var tool: ItemData = GameState.loadout.get_item(ItemData.Slot.TOOL)
	return tool != null and tag in tool.harvest_tags


static func _tool_name_for(tag: StringName) -> String:
	for item: ItemData in ItemCatalog.ALL:
		if tag in item.harvest_tags:
			return item.display_name.to_lower()
	return "un outil"


## L'infection change pendant l'arrêt : paliers (PV, vitesse) et, à 100 %, la ruche.
func _on_infection_changed(value: float) -> void:
	var stage: int = Infection.stage_for(value)
	if stage == Infection.Stage.TURNED:
		if _session.is_running():
			_session.turn()
		return
	if stage == _infection_stage:
		return
	var worse: bool = _infection_stage >= 0 and stage > _infection_stage
	_infection_stage = stage
	var max_health: int = maxi(GameState.BASE_HEALTH + int(GameState.perk_bonus(&"max_health")) - Infection.health_malus(value), 1)
	_player.health.set_max(max_health)
	_player.move_speed = _base_speed * Infection.speed_factor(value)
	if worse:
		_hud.call(&"toast", "Infection : %s" % Infection.describe(value), true)


# --- Rencontres -------------------------------------------------------------------

func _open_encounter(spot: EncounterSpot) -> void:
	if not _session.is_running() or _dialog.call(&"is_open"):
		return
	_active_spot = spot
	_player.set_controls_enabled(false)
	_set_enemies_active(false) # pas de coup dans le dos pendant un dialogue
	_dialog.call(&"open", spot.encounter, _session.result, _session.capacity, _session.free_beds)


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
	_dialog.call(&"show_outcome", outcome.text, outcome.gained, repeatable, outcome.item, outcome.plan)


func _on_dialog_closed() -> void:
	_active_spot = null
	if _session.is_running():
		_player.set_controls_enabled(true)
		_set_enemies_active(true)


# --- Fin de la sortie -------------------------------------------------------------

func _on_session_ended(result: ExpeditionResult) -> void:
	_end_combat()
	_dialog.call(&"close")
	if result.turned:
		# Les spores ont gagné.
		create_tween().tween_property(_player, "modulate", Color(0.75, 0.42, 1.0), 0.8)
	elif result.fell:
		# Le joueur s'effondre.
		var fall := create_tween()
		fall.tween_property(_player, "rotation", PI / 2.0, 0.4)
		fall.parallel().tween_property(_player, "modulate", Color(0.6, 0.6, 0.6, 0.8), 0.4)
	_player.set_controls_enabled(false)
	GameState.record_expedition(result)
	if not result.boarded:
		Campaign.train_missed()
	if result.boarded:
		_player.visible = false
		_train.depart()
		await get_tree().create_timer(1.5, false).timeout
	else:
		await _train.depart().finished
	_result_screen.call(&"show_result", result, GameState.LOOT_TYPES)
	get_tree().paused = true


func _continue_journey() -> void:
	get_tree().paused = false
	GameState.prepare_next_stop()
	get_tree().change_scene_to_file(JOURNEY_SCENE)


## Train raté : on reprend à la dernière gare refuge (ou au départ du train).
func _retry() -> void:
	get_tree().paused = false
	Campaign.retry(get_tree())
