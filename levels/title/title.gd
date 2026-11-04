extends Node2D
## Écran titre : continuer la campagne enregistrée, ou en commencer une nouvelle.
##
## Le train roule en fond, la voie défile.

const TILE_SIZE: int = 16

@onready var _ground: Parallax2D = $Ground
@onready var _tiles: TileMapLayer = $Ground/Tiles
@onready var _continue: Button = %Continue
@onready var _new_game: Button = %NewGame
@onready var _hint: Label = %Hint

var _confirm_new: bool = false


func _ready() -> void:
	_paint_ground()
	var has_save: bool = Campaign.has_resume()
	_continue.visible = has_save
	if has_save:
		_continue.text = "Continuer — " + Campaign.describe(SaveStore.RESUME)
	_continue.pressed.connect(_on_continue)
	_new_game.pressed.connect(_on_new_game)
	_hint.text = "Partie sauvegardée à chaque trajet. Rater le train ramène à la dernière gare refuge." if has_save \
		else "Tu viens d'être recruté à bord. Le capitaine attend."
	(_continue if has_save else _new_game).grab_focus.call_deferred()


func _paint_ground() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for x: int in int(_ground.repeat_size.x / TILE_SIZE):
		for y: int in range(-13, 6):
			var tile: int = ZoneGenerator.Tile.GRASS_B if rng.randf() < 0.4 else ZoneGenerator.Tile.GRASS_A
			if rng.randf() < 0.08:
				tile = ZoneGenerator.Tile.DIRT
			if y == 0:
				tile = ZoneGenerator.Tile.RAILS
			_tiles.set_cell(Vector2i(x, y), 0, Vector2i(tile, 0))


func _on_continue() -> void:
	if not Campaign.continue_game(get_tree()):
		# Sauvegarde illisible : on le dit et on propose de recommencer.
		_continue.visible = false
		_hint.text = "La sauvegarde n'a pas pu être relue."
		_new_game.grab_focus()


func _on_new_game() -> void:
	if Campaign.has_resume() and not _confirm_new:
		_confirm_new = true
		_new_game.text = "Confirmer : effacer la partie en cours"
		return
	Campaign.start_new(get_tree())
