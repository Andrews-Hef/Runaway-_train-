extends CanvasLayer
## Aiguillage : avant chaque arrêt (sauf les gares refuges), le levier de la cabine
## propose plusieurs voies. Chacune montre le type d'arrêt, ce qu'on y trouve, le
## danger, la règle du biome et l'ordre du capitaine : le joueur choisit selon ce
## qui lui manque. Lit GameState.route_options ; le choix passe par GameState.choose_route().

## Une voie choisie (index dans GameState.route_options).
signal chosen(index: int)
## Fermé sans choisir.
signal closed

const GAME_THEME: Theme = preload("res://ui/theme/game_theme.tres")
const GameStateScript = preload("res://core/game_state.gd")
const DANGER_NAMES: Array[String] = ["faible", "moyen", "élevé"]
const DANGER_COLORS: Array[Color] = [Color(0.55, 0.85, 0.45), Color(1.0, 0.8, 0.35), Color(1.0, 0.45, 0.35)]

var _root: Control
var _box: VBoxContainer
var _cards: HBoxContainer


func _ready() -> void:
	layer = 15
	_root = Control.new()
	_root.name = "Root"
	_root.theme = GAME_THEME
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440.0, 0.0)
	center.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override(&"separation", 4)
	panel.add_child(_box)


func _unhandled_input(event: InputEvent) -> void:
	if _root.visible and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause")):
		close()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _root.visible


func open() -> void:
	MenuKit.clear(_box)
	var region: BiomeData = GameState.region()
	var stops: Vector2i = GameState.region_stops()
	var title := MenuKit.label("Aiguillage · arrêt n°%d" % GameState.stop_number, MenuKit.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 11)
	_box.add_child(title)
	var subtitle := MenuKit.label("Région : %s · gare refuge à l'arrêt n°%d" % [region.display_name, stops.y], MenuKit.MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(subtitle)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override(&"separation", 6)
	_box.add_child(_cards)
	var first_button: Button
	for i: int in GameState.route_options.size():
		var button := _add_card(GameState.route_options[i], i)
		if first_button == null:
			first_button = button
	var cancel := Button.new()
	cancel.text = "Pas encore"
	cancel.custom_minimum_size = Vector2(0.0, 18.0)
	cancel.pressed.connect(close)
	_box.add_child(cancel)
	_root.visible = true
	if first_button:
		first_button.grab_focus.call_deferred()


func close() -> void:
	if not _root.visible:
		return
	_root.visible = false
	closed.emit()


## Nombre de voies affichées (pour les tests).
func card_count() -> int:
	return _cards.get_child_count() if _cards else 0


func _add_card(option: GameStateScript.StopOption, index: int) -> Button:
	var card := PanelContainer.new()
	card.theme_type_variation = &"InsetPanel"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(200.0, 0.0)
	_cards.add_child(card)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override(&"separation", 2)
	card.add_child(lines)
	var zone: ZoneProfile = option.zone
	var name_label := MenuKit.label(zone.display_name, MenuKit.GOLD)
	name_label.add_theme_font_size_override(&"font_size", 11)
	lines.add_child(name_label)
	lines.add_child(_wrapped(zone.specialty, MenuKit.GOOD))
	var danger: int = zone.danger(GameState.stop_number)
	lines.add_child(MenuKit.label("Danger : " + DANGER_NAMES[danger], DANGER_COLORS[danger]))
	if zone.biome and not zone.biome.rule_text.is_empty():
		lines.add_child(_wrapped(zone.biome.rule_text, MenuKit.MUTED))
	if option.order:
		lines.add_child(_wrapped("Ordre : %s (+%d mérite)" % [option.order.text(), option.order.data.merit], Color.WHITE))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lines.add_child(spacer)
	var button := Button.new()
	button.text = "Prendre cette voie"
	button.custom_minimum_size = Vector2(0.0, 18.0)
	button.pressed.connect(func() -> void: _choose(index))
	lines.add_child(button)
	return button


func _choose(index: int) -> void:
	if not GameState.choose_route(index):
		return
	_root.visible = false
	chosen.emit(index)


static func _wrapped(text: String, color: Color) -> Label:
	var label := MenuKit.label(text, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(186.0, 0.0)
	return label
