extends Node2D
## Trajet entre deux arrêts : le train roule, le décor défile.
##
## Affiche le stock du train et le prochain arrêt (tiré par GameState), puis
## entre dans le train (automatiquement ou dès que le joueur appuie sur Agir).

## Après le trajet vu de dehors, on entre dans le train (stock, atelier, équipage).
const TRAIN_SCENE: String = "res://levels/train_interior/train_interior.tscn"
const TILE_SIZE: int = 16
const GROUND_SOURCE_ID: int = 0
## Largeur d'un motif de décor qui se répète, en tuiles.
const STRIP_TILES: int = 48
const SCENERY_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/props/dead_tree.png"),
	preload("res://assets/sprites/props/dead_tree.png"),
	preload("res://assets/sprites/props/rock.png"),
	preload("res://assets/sprites/props/wreck.png"),
]
## Pivots (base au sol) des textures ci-dessus, voir tools/sync_td2d.py.
const SCENERY_PIVOTS: Array[Vector2] = [Vector2(20, 51), Vector2(20, 51), Vector2(14, 16), Vector2(36, 38)]

## Entrée automatique dans le train après ce délai (secondes).
@export var auto_continue_after: float = 6.0

@onready var _scenery: Parallax2D = $Scenery
@onready var _ground: TileMapLayer = $Scenery/Ground
@onready var _props: Node2D = $Scenery/Props
@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _next_stop: Label = %NextStop
@onready var _description: Label = %Description
@onready var _storage: Label = %Storage
@onready var _hint: Label = %Hint
@onready var _fade: ColorRect = %Fade
@onready var _train: Train = $Train

var _leaving: bool = false


func _ready() -> void:
	# Le train vu de dehors a autant de wagons que le vrai (ils s'attellent vers la gauche).
	_train.set_wagon_count(GameState.train.size() - 1)
	Campaign.autosave_journey()
	_paint_scenery()
	_fill_texts()
	InputMode.changed.connect(func(_device: int) -> void: _refresh_hint())
	_refresh_hint()
	var blink := create_tween().set_loops()
	blink.tween_property(_hint, "modulate:a", 0.35, 0.6)
	blink.tween_property(_hint, "modulate:a", 1.0, 0.6)
	# process_always = false : le menu pause arrête aussi le compte à rebours.
	get_tree().create_timer(auto_continue_after, false).timeout.connect(_continue)


func _unhandled_input(event: InputEvent) -> void:
	var touched: bool = event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	if touched or event.is_action_pressed(&"interact") or event.is_action_pressed(&"attack"):
		_continue()


func _paint_scenery() -> void:
	BiomeData.apply_ground(_ground, GameState.region())
	# Lumière du milieu du trajet (l'arrivée est à GameState.clock_minutes).
	var light := CanvasModulate.new()
	light.name = "DayLight"
	light.color = DayClock.sky_color(GameState.clock_minutes - DayClock.TRAVEL_MINUTES / 2)
	add_child(light)
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.current_seed
	_scenery.repeat_size = Vector2(STRIP_TILES * TILE_SIZE, 0.0)
	for x: int in STRIP_TILES:
		for y: int in range(-12, 12):
			var tile: int = ZoneGenerator.Tile.RAILS if y == 0 else _ground_tile(rng)
			_ground.set_cell(Vector2i(x, y), GROUND_SOURCE_ID, Vector2i(tile, 0))
	# Quelques arbres, rochers et épaves au bord de la voie, pour sentir la vitesse.
	for i: int in 14:
		var index: int = rng.randi_range(0, SCENERY_TEXTURES.size() - 1)
		var sprite := Sprite2D.new()
		sprite.texture = SCENERY_TEXTURES[index]
		sprite.centered = false
		sprite.offset = -SCENERY_PIVOTS[index]
		var above: bool = rng.randf() < 0.5
		sprite.position = Vector2(
			rng.randf_range(0.0, STRIP_TILES * TILE_SIZE),
			rng.randf_range(-150.0, -84.0) if above else rng.randf_range(44.0, 160.0)
		).round()
		_props.add_child(sprite)


static func _ground_tile(rng: RandomNumberGenerator) -> int:
	var roll: float = rng.randf()
	if roll < 0.1:
		return ZoneGenerator.Tile.DIRT
	if roll < 0.45:
		return ZoneGenerator.Tile.GRASS_B
	return ZoneGenerator.Tile.GRASS_A


func _fill_texts() -> void:
	if GameState.stop_number == 1:
		_title.text = "Tu viens d'être recruté."
		_subtitle.text = "Le capitaine t'envoie au premier arrêt. Rapporte ce que tu peux."
	elif GameState.is_refuge_stop():
		_title.text = "Une gare refuge en vue"
		_subtitle.text = "Des murs, des gens, pas d'infection. On va pouvoir souffler."
	else:
		_title.text = "En route"
		_subtitle.text = "Le train file vers l'arrêt suivant."
	if GameState.has_route_choice():
		# Deux voies à l'aiguillage : on choisit dans la cabine du train.
		var names: PackedStringArray = []
		for option: Object in GameState.route_options:
			var option_zone: ZoneProfile = option.get(&"zone")
			var forecast: EventData = option.get(&"event")
			names.append("%s (%s%s)" % [option_zone.display_name, option_zone.specialty,
				" · " + forecast.forecast_text.to_lower() if forecast else ""])
		_next_stop.text = "Arrêt n°%d : aiguillage en %s" % [GameState.stop_number, GameState.region().display_name]
		_description.text = "Deux voies possibles : %s.\nChoisis la tienne au levier de la cabine." % " ou ".join(names)
		if GameState.stop_number == GameState.region_stops().x and GameState.stop_number > 1:
			_subtitle.text = "Nouvelle région : %s. %s" % [GameState.region().display_name, GameState.region().description]
	else:
		_next_stop.text = "Arrêt n°%d : %s" % [GameState.stop_number, GameState.stop_name()]
		_description.text = GameState.stop_description()
		if GameState.current_order:
			_description.text += "\nOrdre du capitaine : %s." % GameState.current_order.text()
		if GameState.current_event:
			_description.text += "\n%s." % GameState.current_event.forecast_text
	if GameState.last_repair > 0.0:
		_description.text += "\nLes mécaniciens ont réparé le train : +%d %%." % roundi(GameState.last_repair * 100.0)
	if GameState.condition() != GameState.Condition.GOOD:
		_description.text += "\nTrain %s. Répare-le à la cabine." % GameState.describe_condition()
	if not GameState.last_production.is_empty():
		_description.text += "\nPendant le trajet, les machines du train ont produit : %s." % MenuKit.describe_amounts(GameState.last_production)
	_description.text += "\nArrivée vers %s, %s (%s)." % [DayClock.time_text(GameState.clock_minutes),
		"jour %d" % DayClock.day(GameState.clock_minutes), DayClock.period_name(GameState.clock_minutes)]
	if DayClock.is_night(GameState.clock_minutes) and not GameState.is_refuge_stop():
		_description.text += " La nuit, la ruche chasse et les pilleurs somnolent."
	_storage.text = _storage_summary() + "\n" + _crew_summary()


static func _storage_summary() -> String:
	if GameState.storage_total() == 0:
		return "Stock du train : vide"
	var parts: PackedStringArray = []
	for loot: LootData in GameState.LOOT_TYPES:
		var amount: int = GameState.storage_amount(loot.id)
		if amount > 0:
			parts.append("%s %d" % [loot.display_name, amount])
	return "Stock du train : " + " · ".join(parts)


static func _crew_summary() -> String:
	if GameState.crew.is_empty():
		return "Équipage : personne pour l'instant"
	var names: PackedStringArray = []
	for member: CrewMember in GameState.crew:
		names.append(member.describe())
	return "Équipage : " + ", ".join(names)


func _refresh_hint() -> void:
	_hint.text = "Appuie sur %s pour entrer dans le train" % InputMode.label_for(&"interact")


func _continue() -> void:
	if _leaving:
		return
	_leaving = true
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.35)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_file(TRAIN_SCENE))
