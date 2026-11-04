extends Node2D
## Intérieur du train, vu de dessus (toit retiré), pendant le trajet entre deux arrêts.
##
## Même vue, même personnage et mêmes commandes que dehors. Le joueur passe de
## wagon en wagon par les portes : coffre (stock), établi (fabrication), casier
## (équipement), couchettes (équipage), levier de la cabine (arrêt suivant).
## La voie et le sol défilent sous le train : on les voit entre les wagons et
## sur les bords de l'écran.
##
## Les voitures sont construites en code à partir de GameState.train (la
## composition) et de LAYOUTS (les meubles de chaque type de voiture). La cabine
## est en x = 0 ; les voitures construites s'attellent en queue, vers la gauche,
## donc celles qui existent déjà ne bougent pas.

const STOP_SCENE: String = "res://levels/stop_zone/stop_zone.tscn"
const REFUGE_SCENE: String = "res://levels/refuge/refuge.tscn"
const TrainMenu = preload("res://ui/train/train_menu.gd")

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
## Hauteur fixe de la caméra : le train (paroi du fond comprise) est centré.
const CAMERA_Y: float = -17.0

const SHELL_TEXTURE: Texture2D = preload("res://assets/sprites/train/interior_top.png")
const SHELL_PIVOT: Vector2 = Vector2(74, 69)
const CREW_FRAMES: SpriteFrames = preload("res://assets/sprites/refugee/refugee.tres")
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
}
## Les meubles sont contre le mur du fond.
const FURNITURE_Y: float = -12.0

## Meubles de chaque type de voiture (id de WagonData) : [type, x, poste, texte].
## Poste : onglet du menu à ouvrir, &"lever" pour descendre à l'arrêt, &"" pour rien.
const LAYOUTS: Dictionary[StringName, Array] = {
	&"dormitory": [[&"bunk", -34.0, &"crew", "Voir l'équipage"], [&"bunk", 14.0, &"", ""]],
	&"workshop": [[&"workbench", -28.0, &"workshop", "Fabriquer"], [&"locker", 30.0, &"equipment", "S'équiper"]],
	&"stock": [[&"chest", 0.0, &"stock", "Ouvrir le stock"]],
	&"cabin": [[&"plan_table", -30.0, &"train", "Plans du train"], [&"engine", 24.0, &"lever", "Descendre au prochain arrêt"]],
}
## Places des équipiers dans un dortoir (une par couchette).
const CREW_SPOTS: Array[Vector2] = [Vector2(-10, 6), Vector2(36, 2), Vector2(-48, 10), Vector2(52, 12)]
## Voiture où l'on apparaît (le stock : on range son butin en rentrant).
const START_WAGON_ID: StringName = &"stock"
const STATION_TABS: Dictionary[StringName, int] = {
	&"stock": TrainMenu.Tab.STOCK,
	&"workshop": TrainMenu.Tab.WORKSHOP,
	&"equipment": TrainMenu.Tab.EQUIPMENT,
	&"crew": TrainMenu.Tab.CREW,
	&"train": TrainMenu.Tab.TRAIN,
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


func _ready() -> void:
	_build_ground()
	_build_train()
	_player.position = Vector2(_wagon_x(_start_wagon()) - 40.0, 2.0)
	_camera.zoom = Vector2(ZOOM, ZOOM)
	_camera.position = Vector2(_player.position.x, CAMERA_Y)
	_camera.reset_smoothing()
	_player.interactor.target_changed.connect(_on_target_changed)
	_menu.connect(&"closed", _on_menu_closed)
	for signal_name: StringName in [&"storage_changed", &"crew_changed", &"equipment_changed", &"train_changed", &"career_changed"]:
		GameState.connect(signal_name, _refresh_texts)
	GameState.train_changed.connect(_build_train)
	InputMode.changed.connect(func(_device: int) -> void: _refresh_prompt())
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
		_floors.add_child(_sign(wagon.display_name, x))
		for entry: Array in LAYOUTS.get(wagon.id, []):
			_add_furniture(x, entry)
		if i < GameState.train.size() - 1:
			_floors.add_child(_gangway(x + WAGON_LENGTH / 2.0))
	# L'équipage remplit les dortoirs en partant de la tête : un dortoir construit
	# en queue reste vide jusqu'aux prochaines recrues.
	var crew_index: int = 0
	for i: int in range(GameState.train.size() - 1, -1, -1):
		var beds: int = GameState.train[i].beds
		if beds > 0:
			crew_index = _add_crew(_wagon_x(i), crew_index, mini(beds, CREW_SPOTS.size()))
	_build_walls()


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
	if station == &"lever" and GameState.is_refuge_stop():
		spot.prompt = "Descendre à la gare refuge"
	spot.hold_time = 0.7 if station == &"lever" else 0.25
	spot.indicator_offset = Vector2(0.0, -40.0)
	spot.position = position_ + Vector2(0.0, 8.0)
	spot.add_child(_box_collision(Rect2(-footprint.x / 2.0 - 4.0, -6.0, footprint.x + 8.0, 14.0)))
	spot.interacted.connect(func(_actor: Node2D) -> void: _use_station(station))
	_world.add_child(spot, true) # noms lisibles : Station_stock, Station_stock2...


## Place les équipiers n° first à first + places - 1 dans ce dortoir. Renvoie le suivant.
func _add_crew(wagon_x: float, first: int, places: int) -> int:
	var last: int = mini(first + places, GameState.crew.size())
	for i: int in range(first, last):
		var member: CrewMember = GameState.crew[i]
		var sprite := AnimatedSprite2D.new()
		sprite.name = "Crew_" + member.display_name
		sprite.sprite_frames = CREW_FRAMES
		sprite.centered = false
		sprite.offset = Vector2(-18, -36)
		sprite.position = Vector2(wagon_x, 0.0) + CREW_SPOTS[i - first]
		sprite.play(&"idle_s")
		sprite.frame = i * 3 % 10 # pas tous la même respiration
		_world.add_child(sprite)
		var label := Label.new()
		label.theme = GAME_THEME
		label.text = member.display_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(-30.0, -44.0)
		label.size = Vector2(60.0, 10.0)
		label.add_theme_color_override(&"font_color", Color(1.0, 0.82, 0.35))
		label.add_theme_color_override(&"font_outline_color", Color(0.08, 0.06, 0.06))
		label.add_theme_constant_override(&"outline_size", 3)
		sprite.add_child(label)
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
	var label := Label.new()
	label.theme = GAME_THEME
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(x - 40.0, -64.0)
	label.size = Vector2(80.0, 10.0)
	label.add_theme_color_override(&"font_color", Color(0.9, 0.8, 0.55))
	label.add_theme_color_override(&"font_outline_color", Color(0.08, 0.06, 0.06))
	label.add_theme_constant_override(&"outline_size", 3)
	return label


# --- Postes ---------------------------------------------------------------------------

func _use_station(station: StringName) -> void:
	if _leaving:
		return
	if station == &"lever":
		_leave_for_stop()
		return
	_player.set_controls_enabled(false)
	_prompt.visible = false
	_menu.call(&"open", STATION_TABS[station])


func _on_menu_closed() -> void:
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


## Scène de l'arrêt à venir : gare refuge ou zone à fouiller.
func next_scene() -> String:
	return REFUGE_SCENE if GameState.is_refuge_stop() else STOP_SCENE


# --- Interface -------------------------------------------------------------------------

func _refresh_texts() -> void:
	_destination.text = "En route vers l'arrêt n°%d : %s" % [GameState.stop_number, GameState.stop_name()]
	var order: CaptainOrders.Order = GameState.current_order
	_order.text = "%s · %s" % [GameState.grade().display_name,
		("Ordre du capitaine : " + order.text()) if order else "Pas d'ordre en gare"]
	if not GameState.pending_promotions.is_empty():
		_order.text += " · Talent à choisir (onglet Grade)"
	_summary.text = "Stock : %d/%d · Équipage : %d/%d · Voitures : %d/%d" % [
		GameState.storage_total(), GameState.storage_capacity(), GameState.crew.size(), GameState.beds(),
		GameState.train.size(), GameState.max_cars()]


func _on_target_changed(target: Interactable) -> void:
	_target = target
	_refresh_prompt()


func _refresh_prompt() -> void:
	if _leaving:
		return
	_prompt.visible = is_instance_valid(_target)
	if _prompt.visible:
		_prompt.text = "Maintenir %s : %s" % [InputMode.label_for(&"interact"), _target.prompt]
