extends Node2D
## Écran titre : continuer la campagne enregistrée, ou en commencer une nouvelle, régler
## le son (Musique, Effets) avant de jouer, et lire les crédits.
##
## Le train roule en fond, la voie défile.

const TILE_SIZE: int = 16
const NEW_GAME_TEXT: String = "Nouvelle partie"

@onready var _ground: Parallax2D = $Ground
@onready var _tiles: TileMapLayer = $Ground/Tiles
@onready var _continue: Button = %Continue
@onready var _new_game: Button = %NewGame
@onready var _hint: Label = %Hint

var _confirm_new: bool = false
var _sound_button: Button
var _credits_button: Button
## Les curseurs de volume, ouverts sous les boutons (null = fermés).
var _sound: SoundSettings
## Les crédits, à la place des boutons (null = fermés).
var _credits: CreditsView
var _credits_back: Button


func _ready() -> void:
	Audio.play_music(&"title")
	_paint_ground()
	var has_save: bool = Campaign.has_resume()
	_continue.visible = has_save
	if has_save:
		_continue.text = "Continuer — " + Campaign.describe(SaveStore.RESUME)
	_continue.pressed.connect(_on_continue)
	_new_game.pressed.connect(_on_new_game)
	_hint.text = "Partie sauvegardée à chaque trajet. Rater le train ramène à la dernière gare refuge." if has_save \
		else "Tu viens d'être recruté à bord. Le capitaine attend."
	# « Son » et « Crédits » côte à côte, sous « Nouvelle partie ».
	var options := HBoxContainer.new()
	options.name = "Options"
	_new_game.add_sibling(options)
	_sound_button = _option_button(options, "Sound", "Son", toggle_sound)
	_credits_button = _option_button(options, "Credits", "Crédits", toggle_credits)
	MenuKit.focus_later(_continue if has_save else _new_game)
	_add_version()


func _option_button(box: HBoxContainer, node_name: String, text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = _new_game.custom_minimum_size
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(on_press)
	box.add_child(button)
	return button


## Les crédits prennent la place des boutons ; « Retour » (ou Échap, B) les referme.
func toggle_credits() -> void:
	var options: Control = _sound_button.get_parent()
	var opening: bool = _credits == null
	if _sound and opening:
		toggle_sound()
	for control: Control in [_new_game, options, _hint]:
		control.visible = not opening
	_continue.visible = not opening and Campaign.has_resume()
	if opening:
		_credits = CreditsView.create(118.0)
		options.add_sibling(_credits)
		_credits_back = Button.new()
		_credits_back.text = "Retour"
		_credits_back.custom_minimum_size = Vector2(0.0, 18.0)
		_credits_back.pressed.connect(toggle_credits)
		_credits.add_sibling(_credits_back)
		_credits.lines[0].grab_focus()
	else:
		_credits.queue_free()
		_credits_back.queue_free()
		_credits = null
		_credits_button.grab_focus()


## Ouvre ou ferme les curseurs de volume, juste sous les boutons « Son » et « Crédits ».
func toggle_sound() -> void:
	if _sound:
		_sound.queue_free()
		_sound = null
		_sound_button.grab_focus()
		return
	_sound = SoundSettings.create()
	_sound_button.get_parent().add_sibling(_sound)
	_sound.sliders[0].grab_focus()


func _add_version() -> void:
	var version := MenuKit.label(MenuKit.version_text(), MenuKit.MUTED)
	version.name = "Version"
	version.add_theme_font_size_override(&"font_size", 7)
	$Ui/Root.add_child(version)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 4)


## Bouton retour d'Android (via GameMenu) : annule la confirmation « effacer la partie »,
## sinon quitte le jeu.
func go_back() -> void:
	if _credits:
		toggle_credits()
		return
	if _sound:
		toggle_sound()
		return
	if _confirm_new:
		_confirm_new = false
		_new_game.text = NEW_GAME_TEXT
		_new_game.grab_focus()
		return
	get_tree().quit()


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
