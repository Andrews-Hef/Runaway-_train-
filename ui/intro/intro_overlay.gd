class_name IntroOverlay
extends CanvasLayer
## Intro d'une nouvelle partie : le contexte du jeu en quelques pages, par-dessus le
## premier trajet (le train roule derrière le voile).
##
## Le texte s'écrit lettre à lettre. Un appui (toucher, clic, E, Entrée, Espace, A)
## l'affiche en entier, le suivant passe à la page d'après. Échap, Start, le bouton
## retour d'Android ou « Passer » sautent toute l'intro.

signal finished

const THEME: Theme = preload("res://ui/theme/game_theme.tres")
## Le contexte, une page par paragraphe court (lisible sur téléphone). Il reste fidèle
## à ce qui est décidé : rien sur l'origine de la ruche ni sur une destination finale.
const PAGES: Array[String] = [
	"Personne ne sait d'où elle vient. On l'appelle la peste : ceux qu'elle touche cessent d'être eux-mêmes et rejoignent la ruche.",
	"Les villes sont tombées. Le sol violet s'étend, les infectés errent, les pilleurs prennent ce qui reste. Seules quelques gares fortifiées tiennent encore le long de la ligne.",
	"Entre elles roule un train qui ne s'arrête jamais longtemps. À chaque arrêt, l'équipage descend chercher de quoi tenir : ferraille, bois, plantes, survivants. Au coup de sifflet, le train repart, avec ou sans eux.",
	"Toi, tu viens d'être recruté. Le capitaine donne les ordres, tu les exécutes. Fais tes preuves, monte en grade, et un jour, c'est toi qui commanderas ce train.",
]
## Dernière page : le capitaine, sur le papier de ses ordres.
const CAPTAIN_LINE: String = "« Bienvenue à bord, recrue. Premier arrêt dans trois heures. Ramène-moi de la ferraille, évite le violet, et sois là au coup de sifflet. »"
const CAPTAIN_SIGNATURE: String = "Le capitaine"
const CHARS_PER_SECOND: float = 45.0
const INK: Color = Color(0.17, 0.12, 0.08)

var page: int = -1

var _panel: PanelContainer
var _text: Label
var _signature: Label
var _counter: Label
var _hint: Label
var _root: Control
var _typing: Tween
var _done: bool = false


func _ready() -> void:
	layer = 20
	_build()
	InputMode.changed.connect(func(_device: int) -> void: _refresh_hint())
	_refresh_hint()
	_show_page(0)


## Nombre de pages, celle du capitaine comprise.
static func page_count() -> int:
	return PAGES.size() + 1


func is_typing() -> bool:
	return _typing != null and _typing.is_running()


## Un appui : finit d'écrire la page, sinon passe à la suivante (ou termine).
func advance() -> void:
	if _done:
		return
	if is_typing():
		_typing.kill()
		_text.visible_ratio = 1.0
		_signature.visible = page == PAGES.size()
		return
	if page + 1 < page_count():
		_show_page(page + 1)
	else:
		finish()


## Fin de l'intro (dernière page lue, ou passée).
func finish() -> void:
	if _done:
		return
	_done = true
	if _typing:
		_typing.kill()
	finished.emit()
	# Le trajet réapparaît pendant que le voile s'efface.
	var fade := create_tween()
	fade.tween_property(_root, "modulate:a", 0.0, 0.4)
	fade.tween_callback(queue_free)


func _input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		finish()
	elif event.is_action_pressed(&"interact") or event.is_action_pressed(&"attack") \
			or event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		advance()


## Toucher ou clic ailleurs que sur « Passer ».
func _on_root_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		_root.accept_event()
		advance()


func _show_page(index: int) -> void:
	page = index
	var captain: bool = page == PAGES.size()
	_panel.theme_type_variation = &"PaperPanel" if captain else &""
	_text.text = CAPTAIN_LINE if captain else PAGES[page]
	_text.add_theme_color_override(&"font_color", INK if captain else Color(0.92, 0.9, 0.86))
	_signature.visible = false
	_counter.text = "%d / %d" % [page + 1, page_count()]
	_text.visible_ratio = 0.0
	if _typing:
		_typing.kill()
	_typing = create_tween()
	_typing.tween_property(_text, "visible_ratio", 1.0, _text.text.length() / CHARS_PER_SECOND)
	if captain:
		_typing.tween_callback(func() -> void: _signature.visible = true)


func _refresh_hint() -> void:
	match InputMode.current:
		InputMode.Device.TOUCH:
			_hint.text = "Touche l'écran pour continuer"
		InputMode.Device.GAMEPAD:
			_hint.text = "A : continuer · Start : passer"
		_:
			_hint.text = "E, Entrée ou clic : continuer · Échap : passer"


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.theme = THEME
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_root_input)
	add_child(_root)

	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.02, 0.05, 0.6)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(veil)

	# Le texte sous la voie : le train reste visible au-dessus.
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.anchor_top = 0.6
	center.anchor_bottom = 0.88
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)
	_text = Label.new()
	_text.name = "Text"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(320.0, 34.0)
	_text.add_theme_font_size_override(&"font_size", 9)
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	box.add_child(_text)
	_signature = Label.new()
	_signature.text = "— " + CAPTAIN_SIGNATURE
	_signature.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_signature.add_theme_color_override(&"font_color", INK)
	box.add_child(_signature)
	_counter = Label.new()
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_counter.add_theme_font_size_override(&"font_size", 7)
	_counter.add_theme_color_override(&"font_color", MenuKit.MUTED)
	box.add_child(_counter)

	_hint = Label.new()
	_hint.name = "Hint"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -30.0
	_hint.offset_bottom = -14.0
	_hint.add_theme_color_override(&"font_color", MenuKit.MUTED)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hint)
	var blink := create_tween().set_loops()
	blink.tween_property(_hint, "modulate:a", 0.35, 0.6)
	blink.tween_property(_hint, "modulate:a", 1.0, 0.6)

	var skip := Button.new()
	skip.name = "Skip"
	skip.text = "Passer"
	skip.focus_mode = Control.FOCUS_NONE
	skip.custom_minimum_size = Vector2(44.0, 18.0)
	skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
	skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	skip.pressed.connect(finish)
	_root.add_child(skip)
