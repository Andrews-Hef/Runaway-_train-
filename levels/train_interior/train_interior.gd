extends Node2D
## Intérieur du train, vu de dessus (toit retiré), pendant le trajet entre deux arrêts.
##
## Même vue, même personnage et mêmes commandes que dehors. Le joueur passe de
## wagon en wagon par les portes : coffre (stock), établi (fabrication), casier
## (équipement), couchettes (équipage), levier de la cabine (arrêt suivant).
## Chaque meuble n'ouvre que son menu, tant que le plan Interphone n'est pas étudié.
## La voie et le sol défilent sous le train : on les voit entre les wagons et
## sur les bords de l'écran.
##
## Les voitures sont construites en code à partir de GameState.train (la
## composition) et de LAYOUTS (les meubles de chaque type de voiture). La cabine
## est en x = 0 ; les voitures construites s'attellent en queue, vers la gauche,
## donc celles qui existent déjà ne bougent pas.

const STOP_SCENE: String = "res://levels/stop_zone/stop_zone.tscn"
const REFUGE_SCENE: String = "res://levels/refuge/refuge.tscn"
const JOURNEY_SCENE: String = "res://levels/journey/journey.tscn"
const TrainMenu = preload("res://ui/train/train_menu.gd")
const RouteMenu = preload("res://ui/route/route_menu.gd")

const TILE_SIZE: int = 16
## Un wagon fait 8,5 m hors tout (136 px, parois comprises) ; entre deux wagons,
## une passerelle d'1 m au-dessus de la voie.
const WAGON_LENGTH: float = 136.0
const GAP: float = 16.0
const WAGON_SPACING: float = WAGON_LENGTH + GAP
## Épaisseur des parois d'extrémité : le plancher s'arrête avant.
const END_WALL: float = 4.0
## Le plancher va de -FLOOR_HALF_DEPTH à +FLOOR_HALF_DEPTH (5 m de large vus en 3/4).
const FLOOR_HALF_DEPTH: float = 18.0
## Demi-largeur des portes et passerelles entre les wagons.
const DOOR_HALF_WIDTH: float = 8.0
## Biseau devant chaque porte : le joueur glisse vers l'ouverture au lieu de buter.
const DOOR_FUNNEL: float = 6.0
## Rangée de tuiles d'une deuxième voie, au bas de l'écran.
const SIDE_TRACK_ROW: int = 2
## Grossissement de la caméra : on est à l'intérieur, on voit de plus près.
const ZOOM: float = 2.0
## Les lampes du train : part de la nuit effacée à l'intérieur.
const INTERIOR_LAMPS: float = 0.45
## Taille (à l'écran, avant zoom) des textes posés dans le monde du train.
const WORLD_FONT_SIZE: float = 8.0
## Hauteur fixe de la caméra : le train (paroi du fond comprise) est centré.
const CAMERA_Y: float = -17.0

const SHELL_TEXTURE: Texture2D = preload("res://assets/sprites/train/interior_top.png")
const SHELL_PIVOT: Vector2 = Vector2(74, 69)
const GAME_THEME: Theme = preload("res://ui/theme/game_theme.tres")
const SCENERY_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/props/dead_tree.png"),
	preload("res://assets/sprites/props/rock.png"),
	preload("res://assets/sprites/props/herb.png"),
]
const SCENERY_PIVOTS: Array[Vector2] = [Vector2(20, 51), Vector2(14, 16), Vector2(12, 18)]

## Meubles : texture, pivot (base au sol) et taille au sol (pour bloquer le passage).
const FURNITURE: Dictionary[StringName, Array] = {
	&"bunk": [preload("res://assets/sprites/interior/bunk.png"), Vector2(22, 43), Vector2(30, 6)],
	&"workbench": [preload("res://assets/sprites/interior/workbench.png"), Vector2(22, 43), Vector2(30, 8)],
	&"locker": [preload("res://assets/sprites/interior/locker.png"), Vector2(16, 43), Vector2(14, 6)],
	&"chest": [preload("res://assets/sprites/interior/chest.png"), Vector2(32, 39), Vector2(52, 8)],
	&"engine": [preload("res://assets/sprites/interior/engine_panel.png"), Vector2(26, 54), Vector2(40, 12)],
	&"plan_table": [preload("res://assets/sprites/interior/plan_table.png"), Vector2(20, 38), Vector2(28, 6)],
	&"med_cabinet": [preload("res://assets/sprites/interior/med_cabinet.png"), Vector2(22, 42), Vector2(36, 8)],
	&"planter": [preload("res://assets/sprites/interior/planter.png"), Vector2(22, 36), Vector2(36, 8)],
	&"still": [preload("res://assets/sprites/interior/still.png"), Vector2(20, 44), Vector2(30, 8)],
	&"coal_bin": [preload("res://assets/sprites/interior/coal_bin.png"), Vector2(13, 16), Vector2(20, 6)],
}
## Les meubles sont contre le mur du fond.
const FURNITURE_Y: float = -12.0

## Meubles de chaque type de voiture (id de WagonData) : [type, x, poste, texte].
## Poste : onglet du menu à ouvrir, &"lever" pour descendre à l'arrêt, &"" pour rien.
const LAYOUTS: Dictionary[StringName, Array] = {
	&"dormitory": [[&"bunk", -40.0, &"crew", "Voir l'équipage"], [&"bunk", -4.0, &"", ""]],
	&"workshop": [[&"workbench", -36.0, &"workshop", "Fabriquer"], [&"plan_table", 4.0, &"plans", "Étudier les plans"],
		[&"locker", 40.0, &"equipment", "S'équiper"]],
	&"infirmary": [[&"med_cabinet", -20.0, &"infirmary", "Infirmerie : se soigner"], [&"bunk", 30.0, &"", ""]],
	&"greenhouse": [[&"planter", -30.0, &"machines", "Serre : voir la production"], [&"planter", 22.0, &"", ""]],
	&"laboratory": [[&"still", -26.0, &"machines", "Laboratoire : voir la production"], [&"planter", 28.0, &"", ""]],
	&"stock": [[&"chest", 0.0, &"stock", "Ouvrir le stock"]],
	&"cabin": [[&"plan_table", -36.0, &"train", "Plans du train"], [&"coal_bin", -6.0, &"boiler", "Charger la chaudière"],
		[&"engine", 28.0, &"lever", "Descendre au prochain arrêt"]],
}
## Meubles en plus quand une voiture est agrandie : type -> niveau -> meubles.
const LEVEL_EXTRAS: Dictionary[StringName, Dictionary] = {
	&"dormitory": {2: [[&"bunk", 32.0, &"", ""]], 3: [[&"locker", 54.0, &"", ""]]},
	&"stock": {2: [[&"locker", -46.0, &"", ""]], 3: [[&"locker", 46.0, &"", ""]]},
	&"infirmary": {2: [[&"locker", 54.0, &"", ""]]},
}
## Places des équipiers dans un dortoir (une par couchette).
const CREW_SPOTS: Array[Vector2] = [
	Vector2(-22, 6), Vector2(14, 4), Vector2(-50, 10), Vector2(-2, 13),
	Vector2(48, 6), Vector2(30, 13), Vector2(-36, 14), Vector2(56, 14),
]
## Équipiers en quarantaine : à l'infirmerie, autour de la couchette.
const QUARANTINE_OFFSET: float = 20.0
const QUARANTINE_SPOTS: int = 2
## Allure des équipiers : malade (verdâtre), épuisé (grisé).
const SICK_TINT: Color = Color(0.78, 0.95, 0.72)
const TIRED_TINT: Color = Color(0.72, 0.72, 0.78)
## Voiture où l'on apparaît (le stock : on range son butin en rentrant).
const START_WAGON_ID: StringName = &"stock"
const STATION_TABS: Dictionary[StringName, int] = {
	&"stock": TrainMenu.Tab.STOCK,
	&"workshop": TrainMenu.Tab.WORKSHOP,
	&"equipment": TrainMenu.Tab.EQUIPMENT,
	&"crew": TrainMenu.Tab.CREW,
	&"train": TrainMenu.Tab.TRAIN,
	&"plans": TrainMenu.Tab.PLANS,
	&"infirmary": TrainMenu.Tab.INFIRMARY,
	&"machines": TrainMenu.Tab.MACHINES,
	&"boiler": TrainMenu.Tab.BOILER,
}
## Animation du joueur à chaque poste : debout au travail (&"work") par défaut ;
## il fouille le coffre du stock et reste simplement debout devant les couchettes.
const STATION_ANIMATIONS: Dictionary[StringName, StringName] = {
	&"stock": &"harvest",
	&"crew": &"idle",
}

@onready var _ground: Parallax2D = $Ground
@onready var _ground_tiles: TileMapLayer = $Ground/Tiles
@onready var _ground_props: Node2D = $Ground/Props
@onready var _floors: Node2D = $Train/Floors
@onready var _world: Node2D = $Train/World
@onready var _walls: StaticBody2D = $Train/Walls
@onready var _player: Player = $Train/World/Player
@onready var _camera: Camera2D = $Camera2D
@onready var _menu: CanvasLayer = $TrainMenu
@onready var _destination: Label = %Destination
@onready var _summary: Label = %Summary
@onready var _order: Label = %Order
@onready var _prompt: Label = %Prompt
@onready var _fade: ColorRect = %Fade

var _target: Interactable
var _leaving: bool = false
## Aiguillage : choix de la voie au levier de la cabine.
var _route_menu: CanvasLayer


func _ready() -> void:
	BiomeData.apply_ground(_ground_tiles, GameState.region())
	# Dehors, l'heure du trajet ; dedans, les lampes du train adoucissent la nuit.
	var light := CanvasModulate.new()
	light.name = "DayLight"
	light.color = DayClock.sky_color(GameState.clock_minutes - DayClock.TRAVEL_MINUTES / 2).lerp(Color.WHITE, INTERIOR_LAMPS)
	add_child(light)
	_build_ground()
	_build_train()
	_route_menu = RouteMenu.new()
	_route_menu.name = "RouteMenu"
	add_child(_route_menu)
	_route_menu.connect(&"chosen", func(_index: int) -> void: _leave_for_stop())
	_route_menu.connect(&"closed", _on_menu_closed)
	_route_menu.connect(&"mission_chosen", _send_on_mission)
	_player.position = Vector2(_wagon_x(_start_wagon()) - 40.0, 2.0)
	_camera.zoom = Vector2(ZOOM, ZOOM)
	_camera.position = Vector2(_player.position.x, CAMERA_Y)
	_camera.reset_smoothing()
	_player.interactor.target_changed.connect(_on_target_changed)
	_menu.connect(&"closed", _on_menu_closed)
	for signal_name: StringName in [&"storage_changed", &"crew_changed", &"equipment_changed", &"train_changed", &"career_changed",
			&"infection_changed", &"condition_changed", &"energy_changed"]:
		GameState.connect(signal_name, _refresh_texts)
	GameState.train_changed.connect(_build_train)
	GameState.crew_changed.connect(_place_crew)
	InputMode.changed.connect(func(_device: int) -> void: _refresh_prompt())
	# Équipement porté, en haut à gauche.
	_fade.get_parent().add_child(EquipmentBar.make_panel())
	_fade.get_parent().move_child(_fade, -1)
	_refresh_texts()
	_fade.color.a = 1.0
	create_tween().tween_property(_fade, "color:a", 0.0, 0.4)


func _process(_delta: float) -> void:
	var half_view: float = get_viewport_rect().size.x / (2.0 * ZOOM)
	# La caméra s'arrête un peu après les bouts du train : on y voit la voie.
	var first: float = train_start() - 32.0 + half_view
	var last: float = train_end() + 32.0 - half_view
	var target_x: float = clampf(_player.position.x, first, maxf(first, last))
	_camera.position.x = lerpf(_camera.position.x, target_x, 0.15)


func train_length() -> float:
	return GameState.train.size() * WAGON_SPACING - GAP


## Bout arrière du train (queue), en x.
func train_start() -> float:
	return train_end() - train_length()


## Bout avant du train (cabine), en x.
func train_end() -> float:
	return WAGON_LENGTH / 2.0


## Centre de la voiture n° index (0 = queue). La cabine, en tête, est en x = 0.
func _wagon_x(index: int) -> float:
	return (index - (GameState.train.size() - 1)) * WAGON_SPACING


## La voiture de départ : le stock le plus proche de la tête.
func _start_wagon() -> int:
	for i: int in range(GameState.train.size() - 1, -1, -1):
		if GameState.train[i].id == START_WAGON_ID:
			return i
	return GameState.train.size() - 1


# --- Construction -------------------------------------------------------------------

## Sol et voies qui défilent : la nôtre sous le train (visible entre les wagons et
## aux deux bouts), une voie parallèle au bas de l'écran, arbres et rochers derrière.
func _build_ground() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.current_seed
	var strip_tiles: int = int(_ground.repeat_size.x / TILE_SIZE)
	for x: int in strip_tiles:
		for y: int in range(-7, 7):
			var tile: int = ZoneGenerator.Tile.RAILS if y == 0 or y == SIDE_TRACK_ROW else _grass(rng)
			_ground_tiles.set_cell(Vector2i(x, y), 0, Vector2i(tile, 0))
	# Le décor se tient juste derrière le train : il dépasse au-dessus de la paroi du fond.
	for i: int in 14:
		var index: int = rng.randi_range(0, SCENERY_TEXTURES.size() - 1)
		var sprite := Sprite2D.new()
		sprite.texture = SCENERY_TEXTURES[index]
		sprite.centered = false
		sprite.offset = -SCENERY_PIVOTS[index]
		sprite.position = Vector2(rng.randf_range(0.0, _ground.repeat_size.x), rng.randf_range(-64.0, -57.0)).round()
		_ground_props.add_child(sprite)


static func _grass(rng: RandomNumberGenerator) -> int:
	var roll: float = rng.randf()
	if roll < 0.1:
		return ZoneGenerator.Tile.DIRT
	return ZoneGenerator.Tile.GRASS_B if roll < 0.45 else ZoneGenerator.Tile.GRASS_A


## (Re)construit les voitures, leurs meubles, l'équipage et les murs. Appelé au
## départ et à chaque changement de composition (voiture construite).
func _build_train() -> void:
	for container: Node in [_floors, _walls]:
		for child: Node in container.get_children():
			container.remove_child(child)
			child.queue_free()
	for child: Node in _world.get_children():
		if child != _player:
			_world.remove_child(child)
			child.queue_free()
	for i: int in GameState.train.size():
		var wagon: WagonData = GameState.train[i]
		var x: float = _wagon_x(i)
		var shell := Sprite2D.new()
		shell.texture = SHELL_TEXTURE
		shell.centered = false
		shell.offset = -SHELL_PIVOT
		shell.position = Vector2(x, 0.0)
		_floors.add_child(shell)
		var level: int = GameState.wagon_level(wagon.id)
		_floors.add_child(_sign(wagon.display_name + (" niv. %d" % level if level > 1 else ""), x))
		for entry: Array in LAYOUTS.get(wagon.id, []):
			_add_furniture(x, entry)
		var extras: Dictionary = LEVEL_EXTRAS.get(wagon.id, {})
		for extra_level: int in range(2, level + 1):
			for entry: Array in extras.get(extra_level, []):
				_add_furniture(x, entry)
		if i < GameState.train.size() - 1:
			_floors.add_child(_gangway(x + WAGON_LENGTH / 2.0))
	_place_crew()
	_build_walls()


## L'équipage remplit les dortoirs en partant de la tête : un dortoir construit
## en queue reste vide jusqu'aux prochaines recrues. Les équipiers en quarantaine
## sont à l'infirmerie. Refait à chaque changement de l'équipage (soins, repos...).
func _place_crew() -> void:
	for child: Node in _world.get_children():
		if child.name.begins_with("Crew_"):
			_world.remove_child(child)
			child.queue_free()
	var in_dorms: Array[CrewMember] = []
	var isolated: Array[CrewMember] = []
	for member: CrewMember in GameState.crew:
		(isolated if member.quarantined else in_dorms).append(member)
	var crew_index: int = 0
	for i: int in range(GameState.train.size() - 1, -1, -1):
		var beds: int = GameState.train[i].beds_at(GameState.wagon_level(GameState.train[i].id))
		if beds > 0:
			crew_index = _add_crew(_wagon_x(i), in_dorms, crew_index, mini(beds, CREW_SPOTS.size()))
		elif GameState.train[i].id == &"infirmary" and not isolated.is_empty():
			_add_crew(_wagon_x(i) + QUARANTINE_OFFSET, isolated, 0, QUARANTINE_SPOTS)


func _add_furniture(wagon_x: float, entry: Array) -> void:
	var kind: StringName = entry[0]
	var station: StringName = entry[2]
	var texture: Texture2D = FURNITURE[kind][0]
	var pivot: Vector2 = FURNITURE[kind][1]
	var footprint: Vector2 = FURNITURE[kind][2]
	var position_: Vector2 = Vector2(wagon_x + entry[1], FURNITURE_Y)

	var body := StaticBody2D.new()
	body.position = position_
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.offset = -pivot
	body.add_child(sprite)
	body.add_child(_box_collision(Rect2(-footprint / 2.0, footprint)))
	_world.add_child(body)
	if station == &"":
		return

	var spot := Interactable.new()
	spot.name = "Station_" + String(station)
	spot.prompt = entry[3]
	if station == &"lever" and GameState.is_incident_stop():
		spot.prompt = "Descendre : le train est en panne"
	elif station == &"lever" and GameState.is_refuge_stop():
		spot.prompt = "Descendre à la gare refuge"
	elif station == &"lever" and GameState.has_route_choice():
		spot.prompt = "Aiguillage : choisir le prochain arrêt"
	# Pas d'équipier de sortie en gare refuge (on n'y fouille pas).
	var partner: CrewMember = GameState.companion_for_stop()
	if station == &"lever" and partner and not GameState.is_refuge_stop() and not GameState.has_route_choice():
		spot.prompt += " (avec %s)" % partner.display_name
	spot.hold_time = 0.7 if station == &"lever" else 0.25
	spot.animation = STATION_ANIMATIONS.get(station, &"work")
	spot.indicator_offset = Vector2(0.0, -40.0)
	spot.position = position_ + Vector2(0.0, 8.0)
	spot.add_child(_box_collision(Rect2(-footprint.x / 2.0 - 4.0, -6.0, footprint.x + 8.0, 14.0)))
	spot.interacted.connect(func(_actor: Node2D) -> void: _use_station(station, spot))
	_world.add_child(spot, true) # noms lisibles : Station_stock, Station_stock2...


## Place les équipiers n° first à first + places - 1 de `members` dans cette voiture.
## Renvoie le suivant. Leur allure dit leur état : malade, épuisé, au repos.
func _add_crew(wagon_x: float, members: Array[CrewMember], first: int, places: int) -> int:
	var last: int = mini(first + places, members.size())
	for i: int in range(first, last):
		var member: CrewMember = members[i]
		var sprite := AnimatedSprite2D.new()
		sprite.name = "Crew_" + member.display_name
		sprite.sprite_frames = CrewLooks.frames(member.look)
		sprite.centered = false
		sprite.offset = -CrewLooks.PIVOT
		sprite.position = Vector2(wagon_x, 0.0) + CREW_SPOTS[i - first]
		sprite.play(&"idle_s")
		sprite.frame = i * 3 % 10 # pas tous la même respiration
		_world.add_child(sprite)
		if member.infection_known and member.infection >= CrewLife.SYMPTOMS:
			sprite.self_modulate = SICK_TINT
		elif member.fatigue >= CrewLife.EXHAUSTED:
			sprite.self_modulate = TIRED_TINT
		var name_color: Color = Color(1.0, 0.82, 0.35)
		if CrewLife.is_suspicious(member):
			name_color = Color(1.0, 0.5, 0.4)
		sprite.add_child(_world_label(member.display_name + (" (Zz)" if member.resting else ""),
				Vector2(0.0, -44.0), 60.0, name_color))
	return last


## Passerelle entre deux wagons : des planches à claire-voie (on voit la voie
## défiler entre elles) et deux garde-corps.
func _gangway(gap_start: float) -> Node2D:
	var gangway := Node2D.new()
	for board_x: float in [1.0, 6.0, 11.0]:
		var board := ColorRect.new()
		board.position = Vector2(gap_start + board_x, -DOOR_HALF_WIDTH)
		board.size = Vector2(3.0, DOOR_HALF_WIDTH * 2.0)
		board.color = Color(0.35, 0.27, 0.19)
		board.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gangway.add_child(board)
	for rail_y: float in [-DOOR_HALF_WIDTH - 1.0, DOOR_HALF_WIDTH]:
		var rail := ColorRect.new()
		rail.position = Vector2(gap_start, rail_y)
		rail.size = Vector2(GAP, 1.0)
		rail.color = Color(0.1, 0.1, 0.12)
		rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gangway.add_child(rail)
	return gangway


## Murs invisibles : on reste sur le plancher et on passe d'un wagon à l'autre par les portes.
func _build_walls() -> void:
	var start: float = train_start() + END_WALL
	var end: float = train_end() - END_WALL
	var thickness: float = 8.0
	_walls.add_child(_box_collision(Rect2(start - thickness, -FLOOR_HALF_DEPTH - thickness, end - start + thickness * 2.0, thickness)))
	_walls.add_child(_box_collision(Rect2(start - thickness, FLOOR_HALF_DEPTH, end - start + thickness * 2.0, thickness)))
	_walls.add_child(_box_collision(Rect2(start - thickness, -FLOOR_HALF_DEPTH, thickness, FLOOR_HALF_DEPTH * 2.0)))
	_walls.add_child(_box_collision(Rect2(end, -FLOOR_HALF_DEPTH, thickness, FLOOR_HALF_DEPTH * 2.0)))
	for i: int in GameState.train.size() - 1:
		# Entre le plancher d'une voiture et celui de la suivante : parois + passerelle.
		var a: float = _wagon_x(i) + WAGON_LENGTH / 2.0 - END_WALL
		var b: float = _wagon_x(i + 1) - WAGON_LENGTH / 2.0 + END_WALL
		for side: float in [-1.0, 1.0]:
			var polygon := CollisionPolygon2D.new()
			polygon.polygon = PackedVector2Array([
				Vector2(a - DOOR_FUNNEL, side * FLOOR_HALF_DEPTH),
				Vector2(a, side * DOOR_HALF_WIDTH),
				Vector2(b, side * DOOR_HALF_WIDTH),
				Vector2(b + DOOR_FUNNEL, side * FLOOR_HALF_DEPTH),
			])
			_walls.add_child(polygon)


static func _box_collision(rect: Rect2) -> CollisionShape2D:
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = rect.get_center()
	return collision


func _sign(title: String, x: float) -> Label:
	return _world_label(title, Vector2(x, -64.0), 80.0, Color(0.9, 0.8, 0.55))


## Texte posé dans le monde du train. La caméra zoome ×ZOOM : un texte de 8 px
## serait rendu petit puis agrandi (flou, pixelisé). On le rend donc ZOOM fois
## plus grand et on le réduit d'autant : à l'écran il a la même taille, mais net.
## `top_center` : milieu du bord haut, en coordonnées du monde.
func _world_label(text: String, top_center: Vector2, width: float, color: Color) -> Label:
	var label := Label.new()
	label.theme = GAME_THEME
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(width * ZOOM, 10.0 * ZOOM)
	label.scale = Vector2.ONE / ZOOM
	label.position = top_center - Vector2(width * 0.5, 0.0)
	label.add_theme_font_size_override(&"font_size", roundi(WORLD_FONT_SIZE * ZOOM))
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", Color(0.08, 0.06, 0.06))
	label.add_theme_constant_override(&"outline_size", roundi(3.0 * ZOOM))
	return label


# --- Postes ---------------------------------------------------------------------------

func _use_station(station: StringName, spot: Interactable = null) -> void:
	if _leaving:
		return
	if station == &"lever":
		if GameState.has_route_choice():
			_player.set_controls_enabled(false)
			_prompt.visible = false
			if spot:
				_player.hold_pose(spot.animation, spot.global_position)
			_route_menu.call(&"open")
		else:
			_leave_for_stop()
		return
	_player.set_controls_enabled(false)
	if spot:
		# Il reste au poste, au travail, tant que le menu est ouvert.
		_player.hold_pose(spot.animation, spot.global_position)
	_prompt.visible = false
	if station == &"equipment":
		# Le casier ouvre l'inventaire : c'est là qu'on s'équipe.
		GameMenu.closed.connect(_on_menu_closed, CONNECT_ONE_SHOT)
		GameMenu.open_inventory()
		return
	_menu.call(&"open", STATION_TABS[station])


func _on_menu_closed() -> void:
	_player.hold_pose(&"")
	_player.set_controls_enabled(true)
	_refresh_prompt()


func _leave_for_stop() -> void:
	_leaving = true
	_player.set_controls_enabled(false)
	_prompt.text = "Le train ralentit..."
	var slow := create_tween()
	slow.tween_property(_ground, "autoscroll:x", 0.0, 1.0).set_ease(Tween.EASE_OUT)
	slow.tween_property(_fade, "color:a", 1.0, 0.4)
	slow.tween_callback(func() -> void: get_tree().change_scene_to_file(next_scene()))


## Grade Capitaine : un équipier part seul ; le joueur reste à bord et le train repart.
func _send_on_mission(_index: int, member: CrewMember) -> void:
	_leaving = true
	_player.set_controls_enabled(false)
	_prompt.text = "%s descend seul..." % member.display_name
	# Tout est appliqué avant le fondu : une sauvegarde pendant le fondu (app mise en
	# arrière-plan) ne doit pas permettre de rejouer l'arrêt.
	GameState.run_mission(member)
	GameState.prepare_next_stop()
	var slow := create_tween()
	slow.tween_property(_fade, "color:a", 1.0, 0.6)
	slow.tween_callback(get_tree().change_scene_to_file.bind(JOURNEY_SCENE))


## Scène de l'arrêt à venir : gare refuge ou zone à fouiller.
func next_scene() -> String:
	return REFUGE_SCENE if GameState.is_refuge_stop() else STOP_SCENE


# --- Interface -------------------------------------------------------------------------

func _refresh_texts() -> void:
	var order: CaptainOrders.Order = GameState.current_order
	if GameState.is_incident_stop():
		_destination.text = "%s · %s : rapporte ce qu'il faut à la locomotive" % [
			"Panne sèche" if GameState.incident == EngineRules.DRY else "Panne moteur", GameState.stop_name()]
		_order.text = "%s · Pas d'ordre : il faut repartir" % GameState.grade().display_name
	elif GameState.has_route_choice():
		_destination.text = "%s · aiguillage avant l'arrêt n°%d : choisis ta voie au levier de la cabine" % [
			GameState.region().display_name, GameState.stop_number]
		_order.text = "%s · Ordre du capitaine : selon la voie choisie" % GameState.grade().display_name
	elif GameState.route_by_captain:
		_destination.text = "Arrêt n°%d : %s · voie choisie par le capitaine (%s requis pour choisir)" % [
			GameState.stop_number, GameState.stop_name(), Career.required_grade(&"route")]
		_order.text = "%s · %s" % [GameState.grade().display_name,
			("Ordre du capitaine : " + order.text()) if order else "Pas d'ordre en gare"]
	else:
		_destination.text = "En route vers l'arrêt n°%d : %s" % [GameState.stop_number, GameState.stop_name()]
		_order.text = "%s · %s" % [GameState.grade().display_name,
			("Ordre du capitaine : " + order.text()) if order else "Pas d'ordre en gare"]
	if not GameState.pending_promotions.is_empty():
		_order.text += " · Talent à choisir (%s : inventaire)" % InputMode.label_for(&"inventory")
	_summary.text = "Arrivée %s · Infection %d %% · Stock %d/%d · Équipage %d/%d · Voitures %d/%d · Train %d %% · Énergie %d/%d (%d trajet(s))" % [
		DayClock.time_text(GameState.clock_minutes),
		roundi(GameState.infection * 100.0), GameState.storage_total(), GameState.storage_capacity(),
		GameState.crew.size(), GameState.beds(), GameState.train.size(), GameState.max_cars(),
		roundi(GameState.train_condition * 100.0), GameState.energy, GameState.energy_capacity(), GameState.trips_left()]


func _on_target_changed(target: Interactable) -> void:
	_target = target
	_refresh_prompt()


func _refresh_prompt() -> void:
	if _leaving:
		return
	_prompt.visible = is_instance_valid(_target)
	if _prompt.visible:
		_prompt.text = "Maintenir %s : %s" % [InputMode.label_for(&"interact"), _target.prompt]
