extends Node2D
## Gare refuge : une grande gare fortifiée sur la ligne, tous les GameState.REFUGE_EVERY arrêts.
##
## Zone sûre : pas d'infection, pas de chrono, le train attend. On y trouve :
## - le marchand (troc libre, équipements, plans) et le comptoir (offres fixes),
## - le bureau de quarantaine (recrues saines, contre des matériaux),
## - le mécanicien du dépôt (réparer le train, renforcer la locomotive).
## On repart en remontant à bord.
##
## Le plan, du nord au sud : rempart, voie, quai pavé sous sa marquise vitrée, bâtiment
## voyageurs (on le traverse par ses portes ou on le contourne par les allées), grande
## place (fontaine, étals, tente de la quarantaine), rempart sud et sa porte fortifiée.

const JOURNEY_SCENE: String = "res://levels/journey/journey.tscn"
const RefugeMenu = preload("res://ui/refuge/refuge_menu.gd")
const TILE_SIZE: int = ZoneGenerator.TILE_SIZE
const SIZE_IN_TILES: Vector2i = Vector2i(48, 31)

## Sols de l'atlas de la gare (tools/gen_refuge_ground.py).
enum Ground { LAWN_A, LAWN_B, COBBLE, FLAGSTONE, RAILS, EDGE, GRAVEL, FLOWERS }

const GRAND_STATION: Texture2D = preload("res://assets/sprites/props/grand_station.png")
const RAMPART: Texture2D = preload("res://assets/sprites/props/rampart.png")
const RAMPART_SIDE: Texture2D = preload("res://assets/sprites/props/rampart_side.png")
const WATCHTOWER: Texture2D = preload("res://assets/sprites/props/watchtower.png")
const CITY_GATE: Texture2D = preload("res://assets/sprites/props/city_gate.png")
const LAMP_POST: Texture2D = preload("res://assets/sprites/props/lamp_post.png")
const PLATFORM_CLOCK: Texture2D = preload("res://assets/sprites/props/platform_clock.png")
const BENCH: Texture2D = preload("res://assets/sprites/props/bench.png")
const LUGGAGE: Texture2D = preload("res://assets/sprites/props/luggage.png")
const CANOPY_COLUMN: Texture2D = preload("res://assets/sprites/props/canopy_column.png")
const CANOPY_ROOF: Texture2D = preload("res://assets/sprites/props/canopy_roof.png")
const WATER_CRANE: Texture2D = preload("res://assets/sprites/props/water_crane.png")
const STALL_RED: Texture2D = preload("res://assets/sprites/props/market_stall_red.png")
const STALL_GREEN: Texture2D = preload("res://assets/sprites/props/market_stall_green.png")
const STALL_BLUE: Texture2D = preload("res://assets/sprites/props/market_stall_blue.png")
const FOUNTAIN: Texture2D = preload("res://assets/sprites/props/fountain.png")
const SQUARE_TREE: Texture2D = preload("res://assets/sprites/props/square_tree.png")
const PLANTER: Texture2D = preload("res://assets/sprites/props/planter.png")
const QUARANTINE_TENT: Texture2D = preload("res://assets/sprites/props/quarantine_tent.png")
const WORKBENCH: Texture2D = preload("res://assets/sprites/interior/workbench.png")
const MERCHANT_FRAMES: SpriteFrames = preload("res://assets/sprites/merchant/merchant.tres")
const PEOPLE_FRAMES: SpriteFrames = preload("res://assets/sprites/refugee/refugee.tres")

## Pivots td2d (tools/sync_td2d.py) : la position d'un objet est sa base au sol.
const PIVOTS: Dictionary[Texture2D, Vector2] = {
	GRAND_STATION: Vector2(190, 170), RAMPART: Vector2(32, 56), RAMPART_SIDE: Vector2(20, 62),
	WATCHTOWER: Vector2(32, 142), CITY_GATE: Vector2(80, 112), LAMP_POST: Vector2(20, 60),
	PLATFORM_CLOCK: Vector2(16, 68), BENCH: Vector2(20, 28), LUGGAGE: Vector2(22, 30),
	CANOPY_COLUMN: Vector2(12, 60), WATER_CRANE: Vector2(50, 62), STALL_RED: Vector2(36, 63),
	STALL_GREEN: Vector2(36, 63), STALL_BLUE: Vector2(36, 63), FOUNTAIN: Vector2(36, 47),
	SQUARE_TREE: Vector2(28, 69), PLANTER: Vector2(18, 23), QUARANTINE_TENT: Vector2(36, 66),
	WORKBENCH: Vector2(22, 43),
}

## Le bâtiment voyageurs : centre de sa base, et le passage de ses portes (on le traverse).
const STATION_AT: Vector2 = Vector2(448, 290)
const STATION_HALF_WIDTH: float = 180.0
const DOOR_HALF_WIDTH: float = 18.0
## Bas du quai : le bâtiment bloque de là jusqu'à sa façade (pas de recoin caché derrière).
const PLATFORM_BOTTOM: float = 128.0
## Rempart sud (avec la porte fortifiée) : sa base.
const SOUTH_WALL_Y: float = 488.0
## Marquise du quai : de x à x, une colonne tous les 64 px, hauteur des colonnes.
const CANOPY_FROM: float = 64.0
const CANOPY_TO: float = 704.0
const CANOPY_HEIGHT: float = 46.0
## Lampadaires : leur lanterne s'allume à la nuit tombée.
const LAMP_GLOW_OFFSET: Vector2 = Vector2(0.0, -46.0)
const LAMP_GLOW_COLOR: Color = Color(1.0, 0.82, 0.5)

## Postes de la gare : [position, poste, texte, onglet du menu].
const STATIONS: Array[Array] = [
	[Vector2(300, 388), &"market", "Marchand : troquer, acheter", RefugeMenu.Tab.MARKET],
	[Vector2(596, 388), &"trade", "Comptoir : bonnes affaires", RefugeMenu.Tab.TRADE],
	[Vector2(104, 388), &"recruit", "Bureau de quarantaine : recruter", RefugeMenu.Tab.RECRUIT],
	[Vector2(436, 116), &"depot", "Dépôt : réparer, renforcer la locomotive", RefugeMenu.Tab.DEPOT],
]
## Passants qui font le tour de la ville : [apparence d'équipier, chemin en boucle].
const WALKERS: Array[Array] = [
	[3, [Vector2(210, 150), Vector2(210, 300), Vector2(380, 336), Vector2(210, 300)]],
	[7, [Vector2(470, 336), Vector2(560, 420), Vector2(360, 424), Vector2(330, 336)]],
	[12, [Vector2(684, 150), Vector2(684, 336), Vector2(520, 336), Vector2(684, 336)]],
	[16, [Vector2(60, 104), Vector2(330, 108), Vector2(600, 110), Vector2(330, 108)]],
	[9, [Vector2(280, 428), Vector2(60, 428), Vector2(150, 404), Vector2(280, 428)]],
]
## Gens qui attendent : [apparence, position, direction du regard].
const IDLERS: Array[Array] = [
	[1, Vector2(150, 118), &"idle_n"], [5, Vector2(262, 122), &"idle_e"], [11, Vector2(560, 104), &"idle_s"],
	[14, Vector2(612, 120), &"idle_w"], [18, Vector2(404, 404), &"idle_e"], [20, Vector2(500, 350), &"idle_s"],
	[4, Vector2(672, 420), &"idle_w"],
]
## Vitesse de marche des passants (px/s).
const WALK_SPEED: float = 24.0

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
	Audio.play_music(&"train")
	# Point de reprise : rater le train plus loin ramènera ici.
	Campaign.reach_refuge()
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
	_subtitle.text = "Partie sauvegardée · Zone sûre, le train attend. Remonte à bord pour repartir."
	# Pas encore Lieutenant : c'est le capitaine qui passe au dépôt.
	if not GameState.can(&"build"):
		var note: String = CaptainDecisions.depot(GameState)
		if not note.is_empty():
			_subtitle.text += "\n" + note
	# L'heure d'arrivée : la gare est éclairée, la nuit y est plus douce que dehors.
	var light := CanvasModulate.new()
	light.name = "DayLight"
	light.color = DayClock.sky_color(GameState.clock_minutes).lerp(Color.WHITE, 0.35)
	add_child(light)
	# Équipement porté, en haut à gauche ; le bandeau d'infos se cale à sa droite.
	var equipment := EquipmentBar.make_panel()
	_fade.get_parent().add_child(equipment)
	EquipmentBar.dock_beside(equipment, $Ui/Root/Top)
	_fade.get_parent().move_child(_fade, -1)
	_fade.color.a = 1.0
	create_tween().tween_property(_fade, "color:a", 0.0, 0.4)


# --- Construction ------------------------------------------------------------------

## Du nord au sud : pelouse, voie, quai pavé, allées de gravier, grande place dallée.
func _paint_ground() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.current_seed
	for y: int in SIZE_IN_TILES.y:
		for x: int in SIZE_IN_TILES.x:
			_ground.set_cell(Vector2i(x, y), 0, Vector2i(_ground_at(x, y, rng), 0))


static func _ground_at(x: int, y: int, rng: RandomNumberGenerator) -> Ground:
	var lawn: Ground = Ground.LAWN_B if rng.randf() < 0.4 else Ground.LAWN_A
	if rng.randf() < 0.05:
		lawn = Ground.FLOWERS
	var rails: int = ZoneGenerator.RAILS_ROW
	if y < rails:
		return lawn
	if y == rails:
		return Ground.RAILS
	if y == rails + 1:
		return Ground.EDGE
	if y <= rails + 4:
		return Ground.COBBLE
	if y >= 19 and y <= SIZE_IN_TILES.y - 2 and x >= 1 and x <= SIZE_IN_TILES.x - 2:
		return Ground.FLAGSTONE # la grande place
	if x >= 17 and x <= 38 and y <= 18:
		return Ground.COBBLE # côté voie du bâtiment, sous son toit
	if (x >= 12 and x <= 14) or (x >= 41 and x <= 43):
		return Ground.GRAVEL # allées qui contournent le bâtiment
	return lawn


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
	_build_walls()
	_build_platform()
	_build_station()
	_build_square()
	_build_people()
	for station: Array in STATIONS:
		_add_station(station[0], station[1], station[2], station[3])


## Remparts : au nord derrière la voie, sur les côtés, au sud avec la porte et deux tours.
func _build_walls() -> void:
	var width: float = SIZE_IN_TILES.x * TILE_SIZE
	for x: float in range(24, int(width) + 24, 48):
		_add_prop(RAMPART, Vector2(x, 60.0), Vector2.ZERO)
		if absf(x - STATION_AT.x) > 70.0:
			_add_prop(RAMPART, Vector2(x, SOUTH_WALL_Y), Vector2.ZERO)
	_add_box(Rect2(0.0, 36.0, width, 24.0)) # derrière la voie
	_add_box(Rect2(0.0, SOUTH_WALL_Y - 16.0, width, 24.0))
	for y: float in range(160, int(SOUTH_WALL_Y) - 10, 24):
		_add_prop(RAMPART_SIDE, Vector2(10.0, y), Vector2.ZERO)
		_add_prop(RAMPART_SIDE, Vector2(width - 10.0, y), Vector2.ZERO)
	_add_box(Rect2(0.0, 140.0, 18.0, SOUTH_WALL_Y - 140.0))
	_add_box(Rect2(width - 18.0, 140.0, 18.0, SOUTH_WALL_Y - 140.0))
	_add_prop(CITY_GATE, Vector2(STATION_AT.x, SOUTH_WALL_Y + 2.0), Vector2.ZERO)
	_add_prop(WATCHTOWER, Vector2(26.0, SOUTH_WALL_Y + 4.0), Vector2.ZERO)
	_add_prop(WATCHTOWER, Vector2(width - 26.0, SOUTH_WALL_Y + 4.0), Vector2.ZERO)


## Le quai : marquise vitrée sur colonnes, lampadaires, bancs, malles, horloge, dépôt.
func _build_platform() -> void:
	for x: float in range(int(CANOPY_FROM) + 32, int(CANOPY_TO), 64):
		_add_prop(CANOPY_COLUMN, Vector2(x, PLATFORM_BOTTOM - 1.0), Vector2(4, 3))
	# Le toit vitré est au-dessus de tout (on voit le joueur et le train au travers).
	var canopy := Node2D.new()
	canopy.name = "Canopy"
	for x: float in range(int(CANOPY_FROM), int(CANOPY_TO), CANOPY_ROOF.get_width()):
		var roof := Sprite2D.new()
		roof.texture = CANOPY_ROOF
		roof.centered = false
		roof.position = Vector2(x, PLATFORM_BOTTOM - CANOPY_HEIGHT - CANOPY_ROOF.get_height() + 8.0)
		canopy.add_child(roof)
	add_child(canopy)
	move_child(canopy, _world.get_index() + 1)
	for x: float in [128.0, 320.0, 512.0, 672.0]:
		_add_lamp(Vector2(x, PLATFORM_BOTTOM + 4.0))
	_add_prop(PLATFORM_CLOCK, Vector2(364.0, 120.0), Vector2(6, 4))
	_add_prop(BENCH, Vector2(232.0, 124.0), Vector2(26, 6))
	_add_prop(BENCH, Vector2(584.0, 124.0), Vector2(26, 6))
	_add_prop(LUGGAGE, Vector2(176.0, 120.0), Vector2(20, 6))
	_add_prop(LUGGAGE, Vector2(640.0, 122.0), Vector2(20, 6))
	# Dépôt, au bout du quai devant la locomotive : grue à eau et établi du mécanicien.
	_add_prop(WATER_CRANE, Vector2(404.0, 96.0), Vector2(10, 6))
	_add_prop(WORKBENCH, Vector2(468.0, 104.0), Vector2(30, 8))


## Le bâtiment voyageurs, qu'on traverse par ses portes, et ses jardinières.
func _build_station() -> void:
	_add_prop(GRAND_STATION, STATION_AT, Vector2.ZERO)
	# Il bloque du quai jusqu'à sa façade, sauf le passage des portes.
	var top: float = PLATFORM_BOTTOM + 4.0
	var bottom: float = STATION_AT.y + 16.0
	var left: float = STATION_AT.x - STATION_HALF_WIDTH
	_add_box(Rect2(left, top, STATION_HALF_WIDTH - DOOR_HALF_WIDTH, bottom - top))
	_add_box(Rect2(STATION_AT.x + DOOR_HALF_WIDTH, top, STATION_HALF_WIDTH - DOOR_HALF_WIDTH, bottom - top))
	for dx: float in [-64.0, 64.0]:
		_add_prop(PLANTER, Vector2(STATION_AT.x + dx, STATION_AT.y + 34.0), Vector2(22, 8))


## La place : fontaine, étals, tente de la quarantaine, arbres et lampadaires.
func _build_square() -> void:
	_add_prop(FOUNTAIN, Vector2(STATION_AT.x, 386.0), Vector2(54, 20))
	_add_prop(STALL_RED, Vector2(300.0, 372.0), Vector2(46, 14))
	_add_prop(STALL_BLUE, Vector2(596.0, 372.0), Vector2(46, 14))
	_add_prop(STALL_GREEN, Vector2(204.0, 424.0), Vector2(46, 14))
	_add_prop(QUARANTINE_TENT, Vector2(104.0, 372.0), Vector2(50, 22))
	for at: Vector2 in [Vector2(56, 200), Vector2(240, 236), Vector2(664, 214), Vector2(736, 286), Vector2(690, 420)]:
		_add_prop(SQUARE_TREE, at, Vector2(10, 6))
	for at: Vector2 in [Vector2(330, 436), Vector2(566, 436), Vector2(248, 336), Vector2(648, 336)]:
		_add_lamp(at)
	_add_prop(BENCH, Vector2(364.0, 424.0), Vector2(26, 6))
	_add_prop(BENCH, Vector2(532.0, 424.0), Vector2(26, 6))


## Les gens de la ville : marchands à leurs étals, mécanicien, voyageurs, passants.
func _build_people() -> void:
	# Chaque marchand se tient à côté de son étal (derrière, le comptoir le cacherait).
	_add_person(MERCHANT_FRAMES, Vector2(338.0, 378.0), Color.WHITE)
	_add_person(PEOPLE_FRAMES, Vector2(634.0, 378.0), Color(1.0, 0.92, 0.8))
	_add_person(PEOPLE_FRAMES, Vector2(242.0, 428.0), Color(0.85, 0.95, 1.0))
	_add_person(PEOPLE_FRAMES, Vector2(134.0, 384.0), Color(0.85, 1.0, 0.9))
	_add_person(PEOPLE_FRAMES, Vector2(436.0, 104.0), Color(1.0, 0.85, 0.7))
	for idler: Array in IDLERS:
		var sprite := _person_sprite(CrewLooks.frames(idler[0]), idler[2])
		var body := StaticBody2D.new()
		body.position = idler[1]
		body.add_child(sprite)
		body.add_child(_box(Rect2(-5, -3, 10, 6)))
		_world.add_child(body)
	for walker: Array in WALKERS:
		_add_walker(walker[0], walker[1])


## Un lampadaire. La nuit, sa lanterne fait un halo et une flaque de lumière au sol :
## des sprites en mélange additif sur leur propre calque (pas touchés par la pénombre),
## bien moins chers qu'une vraie lumière 2D (×1,5 sur le temps d'image en rendu logiciel).
func _add_lamp(at: Vector2) -> void:
	var lamp := _add_prop(LAMP_POST, at, Vector2(6, 4))
	lamp.add_to_group(&"refuge_lamps")
	var darkness: float = 1.0 - DayClock.daylight(GameState.clock_minutes)
	if darkness <= 0.05:
		return
	var glow := Node2D.new()
	glow.name = "Glow"
	glow.position = at
	glow.modulate.a = darkness
	for part: Array in [[LAMP_GLOW_OFFSET, Vector2(0.9, 0.9), 0.55], [Vector2(0.0, -2.0), Vector2(1.3, 0.6), 0.35]]:
		var halo := Sprite2D.new()
		halo.texture = _glow_texture()
		halo.material = _additive()
		halo.position = part[0]
		halo.scale = part[1]
		halo.self_modulate = Color(LAMP_GLOW_COLOR, part[2])
		glow.add_child(halo)
	_glow_layer().add_child(glow)
	lamp.set_meta(&"glow", glow)


var _glows: CanvasLayer

## Le calque des halos : suit la caméra, au-dessus du monde, sous l'interface.
func _glow_layer() -> CanvasLayer:
	if _glows == null:
		_glows = CanvasLayer.new()
		_glows.name = "Glows"
		_glows.layer = 1
		_glows.follow_viewport_enabled = true
		add_child(_glows)
	return _glows


static var _cached_glow: GradientTexture2D
static var _cached_additive: CanvasItemMaterial

static func _glow_texture() -> GradientTexture2D:
	if _cached_glow == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
		gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		gradient.add_point(0.35, Color(1.0, 1.0, 1.0, 0.6))
		_cached_glow = GradientTexture2D.new()
		_cached_glow.gradient = gradient
		_cached_glow.fill = GradientTexture2D.FILL_RADIAL
		_cached_glow.fill_from = Vector2(0.5, 0.5)
		_cached_glow.fill_to = Vector2(1.0, 0.5)
		_cached_glow.width = 80
		_cached_glow.height = 80
	return _cached_glow


static func _additive() -> CanvasItemMaterial:
	if _cached_additive == null:
		_cached_additive = CanvasItemMaterial.new()
		_cached_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _cached_additive


## Un passant fait le tour de son chemin, en boucle, à pied.
func _add_walker(look: int, path: Array) -> void:
	var sprite := _person_sprite(CrewLooks.frames(look), &"walk_s")
	var walker := Node2D.new()
	walker.name = "Walker%d" % look
	walker.position = path[0]
	walker.add_child(sprite)
	_world.add_child(walker)
	var tween := walker.create_tween().set_loops()
	for i: int in path.size():
		var from: Vector2 = path[i]
		var to: Vector2 = path[(i + 1) % path.size()]
		tween.tween_callback(sprite.play.bind(_walk_animation(to - from)))
		tween.tween_property(walker, "position", to, from.distance_to(to) / WALK_SPEED)
		tween.tween_callback(sprite.play.bind(&"idle_s"))
		tween.tween_interval(0.8 + 0.4 * (i % 3))


static func _walk_animation(direction: Vector2) -> StringName:
	if absf(direction.x) > absf(direction.y):
		return &"walk_e" if direction.x > 0.0 else &"walk_w"
	return &"walk_s" if direction.y > 0.0 else &"walk_n"


static func _person_sprite(frames: SpriteFrames, animation: StringName) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.centered = false
	sprite.offset = -CrewLooks.PIVOT
	sprite.play(animation if frames.has_animation(animation) else &"idle_s")
	return sprite


## Un mur invisible (rempart, bâtiment).
func _add_box(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.add_child(_box(rect))
	_world.add_child(body)


## Un objet posé au sol (pivot td2d) ; `footprint` : sa base qui bloque (zéro = rien).
func _add_prop(texture: Texture2D, at: Vector2, footprint: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.offset = -PIVOTS.get(texture, Vector2(texture.get_width() / 2.0, texture.get_height()))
	body.add_child(sprite)
	if footprint != Vector2.ZERO:
		body.add_child(_box(Rect2(-footprint / 2.0 - Vector2(0.0, footprint.y / 2.0), footprint)))
	_world.add_child(body)
	return body


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
