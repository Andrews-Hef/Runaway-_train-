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
	&"barrel": preload("res://props/barrel/barrel.tscn"),
}

const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
## Ce que le joueur jette de son sac (inventaire) : un tas qu'on peut ramasser.
const PILE_SCENE: PackedScene = preload("res://props/dropped_pile/dropped_pile.tscn")
## Où tombe ce qu'on jette : juste devant les pieds (visible, et toujours à portée).
const DROP_OFFSET: Vector2 = Vector2(0.0, 8.0)
## Biome des zones qui n'en déclarent pas (zone de test).
const DEFAULT_BIOME: BiomeData = preload("res://data/biomes/countryside.tres")
## Ce qui abrite de la pluie (nom de la scène -> rayon autour, en px).
const COVER_RADII: Dictionary[String, float] = {
	"house_ruin": 48.0,
	"building_ruin": 58.0,
	"shelter": 40.0,
	"cart": 34.0,
	"truck_wreck": 40.0,
	"container": 40.0,
}
## Abri du train : autour de la porte, sous l'auvent.
const TRAIN_COVER_RADIUS: float = 56.0
## La nuit : lanterne du joueur, lumière du train, lueur des plantes infectées.
const LANTERN_ENERGY: float = 1.1
const LANTERN_SCALE: float = 1.2
const LANTERN_COLOR: Color = Color(1.0, 0.86, 0.62)
const TRAIN_LIGHT_SCALE: float = 1.8
const GLOW_SCALE: float = 0.4
const GLOW_COLOR: Color = Color(0.72, 0.38, 1.0)
## Chance de trouver un plan en fouillant une caisse.
const CACHE_PLAN_CHANCE: float = 0.2
const GROUND_SOURCE_ID: int = 0

## Pour tester un type de zone précis depuis l'éditeur (vide = celui de GameState).
@export var zone_override: ZoneProfile
## Graine forcée pour reproduire une zone (0 = celle de GameState).
@export var seed_override: int = 0
## Événement forcé pour tester (pluie infectée...). Vide = celui de GameState.
@export var event_override: EventData
## Surprise forcée pour tester (horde). Vide = tirée à l'arrivée.
@export var surprise_override: EventData

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
var biome: BiomeData
## Règle du biome (eau, froid, flaques, alarmes).
var rules: BiomeRules
## Pluie infectée de cet arrêt (null s'il n'y en a pas).
var rain: InfectedRain
var _rain_weather: Weather
## Abris contre la pluie : position -> rayon (maisons, immeubles, abris, charrette...).
var _covers: Array[Vector3] = []
var _rain_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _rain_seconds_shown: int = -1
## Horde de cet arrêt (null s'il n'y en a pas).
var horde: Horde
var _horde_event: EventData
var _train_attacked: bool = false
var _train_broke_down: bool = false
## Heure à l'arrivée (minutes, voir DayClock) ; elle avance pendant l'arrêt.
var _start_minutes: int = 0
var _night: bool = false
var _clock_shown: int = -1
var _day_light: CanvasModulate
var _lantern: PointLight2D
var _train_light: PointLight2D
var _glows: Array[PointLight2D] = []

## Hasard des rencontres (gains aléatoires, prénoms, infection cachée).
var _encounter_rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Hasard du combat (vols), séparé de celui des rencontres.
var _combat_rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Armure du joueur pour cet arrêt (équipement + talents).
var _armor: int = 0
## Vitesse du joueur sans malus d'infection.
var _base_speed: float = 0.0
## Multiplicateurs de vitesse : palier d'infection et sol (eau du marais).
var _infection_speed: float = 1.0
var _terrain_speed: float = 1.0
var _base_acceleration: float = 0.0
var _base_friction: float = 0.0
var _infection_stage: int = -1
## Rencontre en cours (null si aucune fenêtre ouverte).
var _active_spot: EncounterSpot


func _ready() -> void:
	zone = zone_override if zone_override else GameState.current_zone
	biome = zone.biome if zone.biome else DEFAULT_BIOME
	var zone_seed: int = seed_override if seed_override != 0 else GameState.current_seed
	var player_spawn: Vector2 = ZoneGenerator.TRAIN_POSITION + _train.door.position + Vector2(0.0, 40.0)
	layout = ZoneGenerator.generate(zone, zone_seed, [player_spawn], GameState.stop_number)
	_encounter_rng.seed = zone_seed + 1
	_combat_rng.seed = zone_seed + 2
	_apply_biome()
	_apply_layout()
	_build_bounds()
	_setup_camera()
	_wire_systems()
	_start_minutes = GameState.clock_minutes
	_setup_lights()
	_setup_event()
	_setup_horde(zone_seed)
	# Train critique : il repart plus tôt.
	_session.start(roundf(layout.stop_duration * GameState.stop_time_factor()))


# --- Application du plan --------------------------------------------------------

## Le biome : sol, lumière, ambiance (neige, brume).
func _apply_biome() -> void:
	BiomeData.apply_ground(_ground, biome)
	# Lumière du monde : teinte du biome le jour, bleu nuit la nuit (voir _update_daylight).
	_day_light = CanvasModulate.new()
	_day_light.name = "BiomeLight"
	_day_light.color = biome.ambient
	add_child(_day_light)
	var weather := Weather.make(biome.weather)
	if weather:
		add_child(weather)


func _physics_process(delta: float) -> void:
	if not _session.is_running():
		return
	if rules:
		rules.tick(delta, layout.is_hazard_at(_player.global_position))
	if rain:
		rain.tick(delta, is_sheltered(_player.global_position))
		_show_rain_time()
	if horde:
		horde.tick(delta)
	_update_daylight()


func _refresh_speed() -> void:
	_player.move_speed = _base_speed * _infection_speed * _terrain_speed


## Eau (plus lent), glace (on glisse : on accélère et on freine mal).
func _on_terrain_changed(speed: float, slippery: bool) -> void:
	_terrain_speed = speed
	_refresh_speed()
	var grip: float = BiomeRules.ICE_GRIP if slippery else 1.0
	_player.acceleration = _base_acceleration * grip
	_player.friction = _base_friction * grip


## Froid ou brûlure : des PV en moins (l'armure n'y fait rien).
func _on_biome_hurt(amount: int, message: String) -> void:
	_player.health.take_damage(amount, _player.global_position)
	if not message.is_empty():
		_hud.call(&"toast", message, true)


## Alarme de voiture : les ennemis proches accourent.
func _on_alarm(at: Vector2) -> void:
	_hud.call(&"toast", "Une alarme hurle ! Les ennemis accourent.", true)
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy and enemy.global_position.distance_to(at) <= BiomeRules.ALARM_RADIUS:
			enemy.alert(at)


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
		var scene: PackedScene = biome.scenes.get(spawn.kind, SCENES[spawn.kind])
		var node := scene.instantiate() as Node2D
		node.position = spawn.position
		_world.add_child(node)
		var cover: float = COVER_RADII.get(node.scene_file_path.get_file().get_basename(), 0.0)
		if cover > 0.0:
			_covers.append(Vector3(spawn.position.x, spawn.position.y, cover))
		if node is Harvestable:
			_connect_harvestable(node as Harvestable, spawn.kind)
		if spawn.kind == &"infected_herb":
			_add_glow(node)
		elif node is EncounterSpot:
			var spot := node as EncounterSpot
			spot.encounter = EncounterLibrary.get_encounter(spawn.data)
			spot.encounter_requested.connect(_open_encounter)


func _spawn_enemy(enemy_data: EnemyData, at: Vector2) -> Enemy:
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
	enemy.set_night(_night)
	return enemy


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


# --- Pluie infectée -----------------------------------------------------------------

func _setup_event() -> void:
	var event: EventData = event_override if event_override else GameState.current_event
	if event == null or event.id != &"infected_rain":
		return
	_rain_rng.seed = (seed_override if seed_override != 0 else GameState.current_seed) + 21
	rain = InfectedRain.new()
	rain.name = "InfectedRain"
	add_child(rain)
	rain.setup(event, layout.stop_duration, _rain_rng)
	_rain_weather = Weather.make(&"infected_rain")
	add_child(_rain_weather)
	rain.warned.connect(_on_rain_warned)
	rain.started.connect(_on_rain_started)
	rain.ended.connect(_on_rain_ended)
	rain.exposed.connect(func(amount: float) -> void: _player.exposure.add(amount))
	rain.shelter_changed.connect(func(_sheltered: bool) -> void: _show_rain_time(true))


## À l'abri de la pluie ? Contre un bâtiment, un abri, la charrette, un conteneur, le train.
func is_sheltered(at: Vector2) -> bool:
	if at.distance_to(_train.global_position + _train.door.position) <= TRAIN_COVER_RADIUS:
		return true
	for cover: Vector3 in _covers:
		if at.distance_to(Vector2(cover.x, cover.y)) <= cover.z:
			return true
	return false


func _on_rain_warned(seconds: float) -> void:
	_rain_weather.set_rain(0.4, 3.0)
	_hud.call(&"toast", "Le ciel se couvre : une pluie infectée arrive ! Trouve un abri.", true)
	_show_rain_time(true)


func _on_rain_started(_duration: float) -> void:
	_rain_weather.set_rain(1.0, 1.0)
	_spawn_rain_infected()
	_show_rain_time(true)


func _on_rain_ended() -> void:
	_rain_weather.set_rain(0.0, 3.0)
	var grown: int = _grow_sprouts()
	_hud.call(&"set_weather", "", false)
	if grown > 0:
		_hud.call(&"toast", "La pluie cesse. Des plantes infectées ont poussé.", false)


## Compte à rebours du HUD : « Pluie dans 8 s », puis « Pluie 0:35 · à découvert ! ».
func _show_rain_time(force: bool = false) -> void:
	if rain == null:
		return
	var seconds: int = ceili(rain.time_left)
	if seconds == _rain_seconds_shown and not force:
		return
	_rain_seconds_shown = seconds
	match rain.phase:
		InfectedRain.Phase.WARNING:
			_hud.call(&"set_weather", "Pluie dans %d s" % seconds, true)
		InfectedRain.Phase.RAINING:
			var sheltered: bool = is_sheltered(_player.global_position)
			_hud.call(&"set_weather", "Pluie %d:%02d · %s" % [seconds / 60, seconds % 60,
				"à l'abri" if sheltered else "à découvert !"], not sheltered)


## Des infectés sortent sous la pluie, dans les zones violettes, loin du joueur.
func _spawn_rain_infected() -> void:
	var infected: EnemyData = EnemyCatalog.get_enemy(&"infected")
	var count: int = _rain_rng.randi_range(rain.event.extra_infected.x, rain.event.extra_infected.y)
	for at: Vector2 in _infected_spots(count, ZoneGenerator.ENEMY_SAFE_RADIUS):
		_spawn_enemy(infected, at)


## La pluie fait pousser des plantes infectées. Renvoie combien ont poussé.
func _grow_sprouts() -> int:
	var count: int = _rain_rng.randi_range(rain.event.sprouts.x, rain.event.sprouts.y)
	var spots: Array[Vector2] = _infected_spots(count, 24.0)
	for at: Vector2 in spots:
		var herb := SCENES[&"infected_herb"].instantiate() as Node2D
		herb.position = at
		_world.add_child(herb)
		if herb is Harvestable:
			_connect_harvestable(herb as Harvestable, &"infected_herb")
		_add_glow(herb)
	_update_daylight(true)
	return spots.size()


## Jusqu'à `count` points au centre de tuiles infectées, à `min_distance` px au moins
## du joueur et à 18 px des autres objets.
func _infected_spots(count: int, min_distance: float) -> Array[Vector2]:
	var cells: Array[Vector2] = []
	var size: Vector2i = layout.size_in_tiles
	for y: int in size.y:
		for x: int in size.x:
			if layout.tile_at(Vector2i(x, y)) == ZoneGenerator.Tile.INFECTED:
				cells.append((Vector2(x, y) + Vector2(0.5, 0.5)) * ZoneGenerator.TILE_SIZE)
	var taken: Array[Vector2] = []
	for child: Node in _world.get_children():
		if child is Node2D:
			taken.append((child as Node2D).global_position)
	var spots: Array[Vector2] = []
	var attempts: int = 0
	while spots.size() < count and attempts < 200 and not cells.is_empty():
		attempts += 1
		var at: Vector2 = cells[_rain_rng.randi_range(0, cells.size() - 1)]
		if at.distance_to(_player.global_position) < min_distance:
			continue
		var free: bool = true
		for other: Vector2 in taken:
			if at.distance_to(other) < 18.0:
				free = false
				break
		if free:
			spots.append(at)
			taken.append(at)
	return spots


# --- Jour et nuit -------------------------------------------------------------------

## Heure actuelle (minutes) : celle de l'arrivée, plus le temps passé à l'arrêt.
func clock_now() -> int:
	return _start_minutes + int((_session.duration - _session.remaining) * DayClock.MINUTES_PER_SECOND)


func _setup_lights() -> void:
	_lantern = _make_light(LANTERN_SCALE, LANTERN_COLOR)
	_lantern.name = "Lantern"
	_player.add_child(_lantern)
	_train_light = _make_light(TRAIN_LIGHT_SCALE, LANTERN_COLOR)
	_train_light.name = "TrainLight"
	_train_light.position = _train.door.position + Vector2(0.0, 6.0)
	_train.add_child(_train_light)
	_update_daylight(true)


## Les plantes infectées luisent la nuit (violet : la couleur de l'infection).
func _add_glow(node: Node) -> void:
	var glow := _make_light(GLOW_SCALE, GLOW_COLOR)
	glow.name = "Glow"
	glow.position = Vector2(0.0, -8.0)
	node.add_child(glow)
	_glows.append(glow)


static func _make_light(scale: float, color: Color) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = _light_texture()
	light.texture_scale = scale
	light.color = color
	light.energy = 0.0
	return light


static var _cached_light_texture: GradientTexture2D

## Halo rond : blanc au centre, transparent au bord.
static func _light_texture() -> GradientTexture2D:
	if _cached_light_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
		gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		gradient.add_point(0.55, Color(1.0, 1.0, 1.0, 0.55))
		_cached_light_texture = GradientTexture2D.new()
		_cached_light_texture.gradient = gradient
		_cached_light_texture.fill = GradientTexture2D.FILL_RADIAL
		_cached_light_texture.fill_from = Vector2(0.5, 0.5)
		_cached_light_texture.fill_to = Vector2(1.0, 0.5)
		_cached_light_texture.width = 128
		_cached_light_texture.height = 128
	return _cached_light_texture


## Lumière selon l'heure ; à la tombée de la nuit (ou au lever du jour), les ennemis changent.
func _update_daylight(force: bool = false) -> void:
	if _day_light == null or _lantern == null:
		return
	var now: int = clock_now()
	var dark: float = 1.0 - DayClock.daylight(now)
	_day_light.color = DayClock.sky_color(now, biome.ambient)
	_lantern.energy = LANTERN_ENERGY * dark
	_train_light.energy = LANTERN_ENERGY * dark
	for glow: PointLight2D in _glows:
		if is_instance_valid(glow):
			glow.energy = dark
	var night: bool = DayClock.is_night(now)
	if night != _night or force:
		var changed: bool = night != _night
		_night = night
		for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
			(node as Enemy).set_night(night)
		if changed and not force:
			_hud.call(&"toast", "La nuit tombe : la ruche chasse, les pilleurs somnolent." if night else "Le jour se lève.", night)
	var minute: int = now
	if minute != _clock_shown:
		_clock_shown = minute
		_hud.call(&"set_clock", DayClock.describe(now), night)


# --- Horde --------------------------------------------------------------------------

## Une horde peut surgir peu après l'arrivée : jamais annoncée, tirée de la graine de l'arrêt.
func _setup_horde(zone_seed: int) -> void:
	_horde_event = surprise_override if surprise_override else GameState.roll_surprise(biome, GameState.stop_number, zone_seed,
		DayClock.is_night(_start_minutes))
	if _horde_event == null or _horde_event.id != &"horde":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = zone_seed + 31
	horde = Horde.new()
	horde.name = "Horde"
	add_child(horde)
	horde.setup(_horde_event, GameState.stop_number, rng)
	horde.arrived.connect(_on_horde_arrived)
	horde.repelled.connect(_on_horde_repelled)


## La horde sort du bas de la carte et fonce sur le train, chacun vers un point du flanc.
func _on_horde_arrived(members: Array[EnemyData]) -> void:
	if not _session.is_running():
		return
	_hud.call(&"toast", "Une horde ! Elle fonce sur le train : défends-le !", true)
	_hud.call(&"set_train_condition", GameState.train_condition)
	var size_px := Vector2(layout.size_in_pixels())
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.current_seed + 37
	var bottom: float = size_px.y - (ZoneGenerator.BORDER + 1) * ZoneGenerator.TILE_SIZE
	for i: int in members.size():
		var at := Vector2(size_px.x * (i + 0.5) / members.size() + rng.randf_range(-20.0, 20.0), bottom - rng.randf_range(0.0, 24.0))
		var enemy: Enemy = _spawn_enemy(members[i], at.clamp(Vector2(16.0, 16.0), size_px - Vector2(16.0, 16.0)))
		enemy.join_siege(_train.flank_point(rng.randf()))
		enemy.train_hit.connect(_on_train_hit)
		enemy.died.connect(func(_enemy: Enemy) -> void: horde.member_died())


func _on_train_hit(enemy: Enemy) -> void:
	if not _session.is_running() or _train_broke_down:
		return
	var left: float = GameState.damage_train(enemy.data.damage * _horde_event.train_damage_per_hit)
	_train.hit_flash()
	_hud.call(&"set_train_condition", left)
	if not _train_attacked:
		_train_attacked = true
		_hud.call(&"toast", "La horde frappe le train !", true)
	if left <= 0.0:
		_train_broke_down = true
		_hud.call(&"toast", "Le train est à bout : il démarre en catastrophe ! Remonte vite !", true)
		_session.remaining = minf(_session.remaining, _session.whistle_time)


func _on_horde_repelled() -> void:
	_session.result.horde_repelled = true
	_hud.call(&"toast", "Horde repoussée ! +%d mérite au retour." % GameState.HORDE_MERIT, false)


# --- Branchement des systèmes ----------------------------------------------------

func _wire_systems() -> void:
	var loadout: Loadout = GameState.loadout
	_player.exposure.ground = _ground
	# L'infection continue celle des arrêts précédents : elle ne redescend pas toute seule.
	_player.exposure.value = GameState.infection
	_base_speed = _player.move_speed
	_base_acceleration = _player.acceleration
	_base_friction = _player.friction
	rules = BiomeRules.new()
	rules.name = "BiomeRules"
	add_child(rules)
	rules.setup(biome, loadout)
	rules.terrain_changed.connect(_on_terrain_changed)
	rules.hurt.connect(_on_biome_hurt)
	rules.alarm_raised.connect(_on_alarm)
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
		var harvest := target as Harvestable
		if harvest.loot != null and _session.room_for(harvest.loot.id) <= 0:
			return "Sac plein !"
		return "Sac plein !" if harvest.loot == null and _session.is_bag_full() else ""
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
	_session.dropped.connect(_on_bag_dropped)
	_hud.call(&"bind", _session, _player, GameState.LOOT_TYPES)
	_hud.call(&"show_order", GameState.current_order)
	var subtitle: String = "%s · %s" % [biome.display_name, biome.rule_text] if not biome.rule_text.is_empty() else ""
	var event: EventData = event_override if event_override else GameState.current_event
	if event:
		subtitle = (subtitle + " · " if not subtitle.is_empty() else "") + event.forecast_text
	_hud.call(&"announce_zone", GameState.stop_number, zone.display_name, subtitle)
	_dialog.connect(&"choice_selected", _on_choice_selected)
	_dialog.connect(&"closed", _on_dialog_closed)
	_result_screen.connect(&"continue_requested", _continue_journey)
	_result_screen.connect(&"retry_requested", _retry)


# --- Sac : jeter et ramasser --------------------------------------------------------

## Le joueur a jeté des ressources depuis l'inventaire : elles tombent à ses pieds, dans
## le tas tout proche s'il y en a un.
func _on_bag_dropped(id: StringName, amount: int) -> void:
	var at: Vector2 = _player.global_position + DROP_OFFSET
	var pile := DroppedPile.nearest(get_tree(), at)
	if pile == null:
		pile = PILE_SCENE.instantiate() as DroppedPile
		_world.add_child(pile)
		pile.global_position = at
		pile.pick_requested.connect(_pick_up_pile)
	pile.add(id, amount)


## Ramasser un tas : ce qui rentre revient dans le sac, le reste reste au sol.
func _pick_up_pile(pile: DroppedPile) -> void:
	var gained: Dictionary[StringName, int] = {}
	for id: StringName in pile.contents.keys():
		var taken: int = _session.add_loot(_loot_type(id), pile.contents[id])
		if taken > 0:
			pile.take(id, taken)
			gained[id] = taken
	if not pile.contents.is_empty():
		_hud.call(&"toast", "Sac plein : le reste du tas reste au sol.", true)
	elif not gained.is_empty():
		_hud.call(&"toast", "Ramassé : " + MenuKit.describe_amounts(gained), false)


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


func _connect_harvestable(harvestable: Harvestable, kind: StringName = &"") -> void:
	harvestable.harvested.connect(func(loot: LootData, amount: int, exposure: float) -> void:
		_session.add_loot(loot, amount)
		_player.exposure.add(exposure)
		_extract_with_tool(loot)
		if kind == &"wreck":
			rules.car_searched(harvestable.global_position, _combat_rng)
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
	_infection_speed = Infection.speed_factor(value)
	_refresh_speed()
	if worse:
		_hud.call(&"toast", "Infection : %s" % Infection.describe(value), true)


# --- Rencontres -------------------------------------------------------------------

func _open_encounter(spot: EncounterSpot) -> void:
	if not _session.is_running() or _dialog.call(&"is_open"):
		return
	_active_spot = spot
	_player.set_controls_enabled(false)
	_set_enemies_active(false) # pas de coup dans le dos pendant un dialogue
	_dialog.call(&"open", spot.encounter, _session.result, _session.capacity, _session.free_beds, GameState.can(&"recruit"))


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
	# Le temps passé à l'arrêt compte pour la suite.
	GameState.clock_minutes = clock_now()
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
