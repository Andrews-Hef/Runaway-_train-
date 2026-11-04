extends Node2D
## Intérieur du train, en coupe, pendant le trajet entre deux arrêts.
##
## Le joueur marche de wagon en wagon : coffre (stock), établi (fabrication),
## casier (équipement), couchettes (équipage), levier de la cabine (arrêt suivant).
## Les wagons sont construits en code à partir de WAGONS : ajouter un wagon,
## c'est ajouter une entrée.

const STOP_SCENE: String = "res://levels/stop_zone/stop_zone.tscn"
const TrainMenu = preload("res://ui/train/train_menu.gd")

## Écart entre deux wagons (la coque fait 256 px de long, 32 px = 1 m).
const WAGON_SPACING: float = 264.0
const WAGON_HALF_LENGTH: float = 128.0
## Hauteur du plancher au-dessus du pivot de la coque.
const FLOOR_Y: float = -10.0
const SHELL_TEXTURE: Texture2D = preload("res://assets/sprites/train/interior_shell.png")
const SHELL_PIVOT: Vector2 = Vector2(136, 110)
const CREW_FRAMES: SpriteFrames = preload("res://assets/sprites/crew_side/crew-side.tres")
const GAME_THEME: Theme = preload("res://ui/theme/game_theme.tres")

## Meubles : texture et pivot (base au sol), voir tools/sync_td2d.py.
const FURNITURE: Dictionary[StringName, Array] = {
	&"bunk": [preload("res://assets/sprites/interior/bunk.png"), Vector2(48, 86)],
	&"workbench": [preload("res://assets/sprites/interior/workbench.png"), Vector2(48, 78)],
	&"locker": [preload("res://assets/sprites/interior/locker.png"), Vector2(28, 86)],
	&"chest": [preload("res://assets/sprites/interior/chest.png"), Vector2(48, 61)],
	&"engine": [preload("res://assets/sprites/interior/engine_panel.png"), Vector2(56, 94)],
}

## Plan du train, de la queue à la tête : nom, meubles [type, x, poste, texte].
## Poste : onglet du menu à ouvrir, ou &"lever" pour descendre à l'arrêt.
const WAGONS: Array[Dictionary] = [
	{"title": "Dortoir", "furniture": [[&"bunk", -70.0, &"crew", "Voir l'équipage"], [&"bunk", 62.0, &"", ""]]},
	{"title": "Atelier", "furniture": [[&"workbench", -50.0, &"workshop", "Fabriquer"], [&"locker", 70.0, &"equipment", "S'équiper"]]},
	{"title": "Stock", "furniture": [[&"chest", 0.0, &"stock", "Ouvrir le stock"]]},
	{"title": "Cabine", "furniture": [[&"engine", 40.0, &"lever", "Descendre au prochain arrêt"]]},
]
## Wagon où l'on apparaît (le stock : on range son butin en rentrant).
const START_WAGON: int = 2
const STATION_TABS: Dictionary[StringName, int] = {
	&"stock": TrainMenu.Tab.STOCK,
	&"workshop": TrainMenu.Tab.WORKSHOP,
	&"equipment": TrainMenu.Tab.EQUIPMENT,
	&"crew": TrainMenu.Tab.CREW,
}

@onready var _wagons: Node2D = $Train/Wagons
@onready var _wheels: Node2D = $Train/Wheels
@onready var _player: InteriorPlayer = $Train/InteriorPlayer
@onready var _camera: Camera2D = $Camera2D
@onready var _menu: CanvasLayer = $TrainMenu
@onready var _destination: Label = %Destination
@onready var _summary: Label = %Summary
@onready var _prompt: Label = %Prompt
@onready var _fade: ColorRect = %Fade
@onready var _scenery: Parallax2D = $NearScenery
@onready var _scenery_ground: TileMapLayer = $NearScenery/Ground
@onready var _scenery_props: Node2D = $NearScenery/Props

var _target: Interactable
var _leaving: bool = false


func _ready() -> void:
	_build_wagons()
	_build_scenery()
	var first_x: float = -WAGON_HALF_LENGTH + 18.0
	var last_x: float = (WAGONS.size() - 1) * WAGON_SPACING + WAGON_HALF_LENGTH - 18.0
	_player.min_x = first_x
	_player.max_x = last_x
	_player.position = Vector2(START_WAGON * WAGON_SPACING - 70.0, FLOOR_Y)
	_camera.position = Vector2(_player.position.x, -52.0)
	_camera.reset_smoothing()
	_player.interactor.target_changed.connect(_on_target_changed)
	_menu.connect(&"closed", _on_menu_closed)
	for signal_name: StringName in [&"storage_changed", &"crew_changed", &"equipment_changed"]:
		GameState.connect(signal_name, _refresh_texts)
	InputMode.changed.connect(func(_device: int) -> void: _refresh_prompt())
	_refresh_texts()
	_fade.color.a = 1.0
	create_tween().tween_property(_fade, "color:a", 0.0, 0.4)


func _process(_delta: float) -> void:
	var half_view: float = get_viewport_rect().size.x / 2.0
	var min_cam: float = -WAGON_HALF_LENGTH - 20.0 + half_view
	var max_cam: float = (WAGONS.size() - 1) * WAGON_SPACING + WAGON_HALF_LENGTH + 20.0 - half_view
	var target_x: float = clampf(_player.position.x, min_cam, maxf(min_cam, max_cam))
	_camera.position.x = lerpf(_camera.position.x, target_x, 0.15)


# --- Construction -------------------------------------------------------------------

func _build_wagons() -> void:
	var wheel_x := PackedFloat32Array()
	for i: int in WAGONS.size():
		var plan: Dictionary = WAGONS[i]
		var wagon := Node2D.new()
		wagon.name = "Wagon%d" % i
		wagon.position = Vector2(i * WAGON_SPACING, 0.0)
		_wagons.add_child(wagon)
		wagon.add_child(_rect(Rect2(-WAGON_HALF_LENGTH - 4.0, -118.0, WAGON_HALF_LENGTH * 2.0 + 8.0, 9.0), Color(0.16, 0.16, 0.19)))
		wagon.add_child(_rect(Rect2(-WAGON_HALF_LENGTH, 0.0, WAGON_HALF_LENGTH * 2.0, 8.0), Color(0.1, 0.1, 0.12)))
		var shell := Sprite2D.new()
		shell.texture = SHELL_TEXTURE
		shell.centered = false
		shell.offset = -SHELL_PIVOT
		wagon.add_child(shell)
		wagon.add_child(_sign(plan["title"]))
		for entry: Array in plan["furniture"]:
			_add_furniture(wagon, entry)
		if plan["title"] == "Dortoir":
			_add_crew(wagon)
		for offset: float in [-92.0, -62.0, 62.0, 92.0]:
			wheel_x.append(i * WAGON_SPACING + offset)
		if i < WAGONS.size() - 1:
			wagon.add_child(_rect(Rect2(WAGON_HALF_LENGTH, -6.0, WAGON_SPACING - WAGON_HALF_LENGTH * 2.0, 4.0), Color(0.2, 0.2, 0.23)))
	_wheels.set(&"wheel_x", wheel_x)


func _add_furniture(wagon: Node2D, entry: Array) -> void:
	var kind: StringName = entry[0]
	var x: float = entry[1]
	var station: StringName = entry[2]
	var texture: Texture2D = FURNITURE[kind][0]
	var pivot: Vector2 = FURNITURE[kind][1]
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.offset = -pivot
	sprite.position = Vector2(x, FLOOR_Y)
	wagon.add_child(sprite)
	if station == &"":
		return
	var spot := Interactable.new()
	spot.name = "Station_" + String(station)
	spot.prompt = entry[3]
	spot.hold_time = 0.7 if station == &"lever" else 0.25
	spot.indicator_offset = Vector2(0.0, -pivot.y - 6.0)
	spot.position = Vector2(x, FLOOR_Y)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(maxf(texture.get_width() - 16.0, 24.0), 40.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, -20.0)
	spot.add_child(collision)
	spot.interacted.connect(func(_actor: Node2D) -> void: _use_station(station))
	wagon.add_child(spot)


func _add_crew(wagon: Node2D) -> void:
	var positions: Array[float] = [-16.0, 26.0, 104.0, -108.0, 68.0, -50.0]
	for i: int in mini(GameState.crew.size(), positions.size()):
		var member: CrewMember = GameState.crew[i]
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = CREW_FRAMES
		sprite.centered = false
		sprite.offset = Vector2(-24, -70)
		sprite.position = Vector2(positions[i], FLOOR_Y)
		sprite.play(&"idle_s")
		sprite.frame = i * 3 % 10 # pas tous la même respiration
		wagon.add_child(sprite)
		var label := Label.new()
		label.theme = GAME_THEME
		label.text = member.display_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(positions[i] - 30.0, FLOOR_Y - 84.0)
		label.size = Vector2(60.0, 10.0)
		label.add_theme_color_override(&"font_color", Color(1.0, 0.82, 0.35))
		label.add_theme_color_override(&"font_outline_color", Color(0.08, 0.06, 0.06))
		label.add_theme_constant_override(&"outline_size", 3)
		wagon.add_child(label)


func _sign(title: String) -> Label:
	var label := Label.new()
	label.theme = GAME_THEME
	label.text = title
	label.add_theme_font_size_override(&"font_size", 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-60.0, -108.0)
	label.size = Vector2(120.0, 16.0)
	label.add_theme_color_override(&"font_color", Color(0.85, 0.75, 0.5))
	return label


func _rect(rect: Rect2, color: Color) -> ColorRect:
	var node := ColorRect.new()
	node.position = rect.position
	node.size = rect.size
	node.color = color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## Paysage qui défile derrière les fenêtres et sous le train.
func _build_scenery() -> void:
	var width: float = _scenery.repeat_size.x
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.current_seed
	for x: int in int(width / 16.0):
		for y: int in range(2, 8):
			var tile: int = ZoneGenerator.Tile.DIRT if rng.randf() < 0.12 else (ZoneGenerator.Tile.GRASS_B if rng.randf() < 0.4 else ZoneGenerator.Tile.GRASS_A)
			_scenery_ground.set_cell(Vector2i(x, y), 0, Vector2i(tile, 0))
	for i: int in 10:
		var tree := Sprite2D.new()
		tree.texture = FURNITURE_OUTSIDE_TREE
		tree.centered = false
		tree.offset = Vector2(-20, -51)
		tree.position = Vector2(rng.randf_range(0.0, width), -8.0).round()
		_scenery_props.add_child(tree)


const FURNITURE_OUTSIDE_TREE: Texture2D = preload("res://assets/sprites/props/dead_tree.png")


# --- Postes ---------------------------------------------------------------------------

func _use_station(station: StringName) -> void:
	if _leaving:
		return
	if station == &"lever":
		_leave_for_stop()
		return
	_player.set_controls_enabled(false)
	_menu.call(&"open", STATION_TABS[station])


func _on_menu_closed() -> void:
	_player.set_controls_enabled(true)


func _leave_for_stop() -> void:
	_leaving = true
	_player.set_controls_enabled(false)
	_prompt.text = "Le train ralentit..."
	var tween := create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(_fade, "color:a", 1.0, 0.5)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_file(STOP_SCENE))


# --- Interface -------------------------------------------------------------------------

func _refresh_texts() -> void:
	_destination.text = "En route vers l'arrêt n°%d : %s" % [GameState.stop_number, GameState.current_zone.display_name]
	_summary.text = "Stock : %d ressource(s) · Équipage : %d · %s" % [GameState.storage_total(), GameState.crew.size(), GameState.loadout.describe()]


func _on_target_changed(target: Interactable) -> void:
	_target = target
	_refresh_prompt()


func _refresh_prompt() -> void:
	if _leaving:
		return
	_prompt.visible = is_instance_valid(_target)
	if _prompt.visible:
		_prompt.text = "Maintenir %s : %s" % [InputMode.label_for(&"interact"), _target.prompt]
