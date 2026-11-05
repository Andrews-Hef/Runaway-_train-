extends CanvasLayer
## Autoload « GameMenu » : menu pause (Échap / Start) et inventaire (I / Tab / Y),
## partout en jeu sauf sur l'écran titre. Le jeu est en pause tant qu'ils sont ouverts.
##
## - Pause : reprendre, inventaire, commandes, écran titre, quitter (PC).
## - Inventaire : équipement porté (icônes), stats, sac de l'arrêt en cours,
##   équipement à bord ; onglet Grade (mérite, ordre, choix des talents).
## - Sur téléphone : deux boutons à droite de l'écran, « Sac » et « II ».
## - À l'arrivée en zone et dans le train : rappel des touches pendant quelques secondes.
## - Android : le bouton retour fait comme Échap (il ne quitte pas le jeu, sauf depuis
##   l'écran titre). Quand l'app passe en arrière-plan, le jeu se met en pause et se
##   sauvegarde si possible (Android peut fermer une app en arrière-plan).
##
## L'interface est construite en code (comme les menus du train) et lit GameState.

enum View { NONE, PAUSE, CONTROLS, CONFIRM_TITLE, INVENTORY }
enum InventoryTab { ITEMS, GRADE }

const GAME_THEME: Theme = preload("res://ui/theme/game_theme.tres")
const BAG_ICON: Texture2D = preload("res://assets/ui/icons/bag.png")
const TITLE_SCENE: String = "res://levels/title/title.tscn"
## Scènes où le menu existe, et leur nature.
const SCENE_KINDS: Dictionary[String, StringName] = {
	"res://levels/stop_zone/stop_zone.tscn": &"zone",
	"res://levels/train_interior/train_interior.tscn": &"train",
	"res://levels/refuge/refuge.tscn": &"refuge",
	"res://levels/journey/journey.tscn": &"journey",
}
## Scènes où l'on peut sauvegarder à tout moment (on reprend au trajet, rien n'est perdu).
const SAVABLE_KINDS: Array[StringName] = [&"train", &"journey"]
## Scènes avec les boutons tactiles « Sac » et « II » (le trajet n'a pas d'interface).
const TOUCH_BUTTON_KINDS: Array[StringName] = [&"zone", &"train", &"refuge"]
## Durée du rappel des touches.
const HINT_TIME: float = 6.0

var view: View = View.NONE

var _root: Control
var _pause_panel: PanelContainer
var _pause_box: VBoxContainer
var _inventory_panel: PanelContainer
var _inventory_tabs: TabContainer
var _items_box: HBoxContainer
var _grade_list: VBoxContainer
var _touch_buttons: VBoxContainer
var _hint: Label
var _hint_tween: Tween
var _was_paused: bool = false
var _last_scene: Node


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	for signal_name: StringName in [&"equipment_changed", &"career_changed", &"infection_changed", &"storage_changed"]:
		# Différé : un bouton (« Choisir » un talent) ne doit pas être détruit pendant son clic.
		GameState.connect(signal_name, _refresh_inventory, CONNECT_DEFERRED)
	InputMode.changed.connect(func(_device: int) -> void: _update_touch_buttons())
	_update_touch_buttons()


func _process(_delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene != _last_scene:
		_last_scene = scene
		_on_scene_changed()


## Type de la scène en cours : &"zone", &"train", &"refuge", &"journey", ou &"" (titre…).
func scene_kind() -> StringName:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return &""
	return SCENE_KINDS.get(scene.scene_file_path, &"")


## Le menu peut-il s'ouvrir ? Pas sur l'écran titre, ni par-dessus un écran qui a
## déjà mis le jeu en pause (bilan de fin d'arrêt).
func is_available() -> bool:
	return scene_kind() != &"" and (view != View.NONE or not get_tree().paused)


func is_open() -> bool:
	return view != View.NONE


# --- Système (Android : bouton retour, arrière-plan) ---------------------------------

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			go_back()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			on_app_hidden()


## Bouton retour d'Android : exactement comme Échap. Il ferme le menu ouvert (celui de
## la scène d'abord, comme le menu du train), sinon il ouvre la pause. Sur l'écran
## titre, c'est la scène qui décide (annuler, ou quitter le jeu).
func go_back() -> void:
	if scene_kind() == &"":
		var scene: Node = get_tree().current_scene
		if scene != null and scene.has_method(&"go_back"):
			scene.call(&"go_back")
		return
	var escape := InputEventAction.new()
	escape.action = &"pause"
	escape.pressed = true
	get_viewport().push_input(escape)


## L'app passe en arrière-plan (appel, notification, bouton accueil, autre fenêtre) :
## sauvegarde si la scène le permet, et pause pour ne rien rater au retour.
func on_app_hidden() -> void:
	save_if_possible()
	if view == View.NONE and is_available():
		open_pause()


## Sauvegarde la partie telle quelle, si on est dans le train ou en trajet (on y
## reprendra). En zone ou en gare, la reprise se fait au dernier point sauvegardé.
func save_if_possible() -> bool:
	if not scene_kind() in SAVABLE_KINDS:
		return false
	Campaign.autosave_journey()
	return true


# --- Entrées ------------------------------------------------------------------------

## Ouvrir : en dernier (les menus de la scène, comme celui du train, se ferment d'abord
## avec Échap). Fermer : en premier, avant que Tab ne déplace le focus des boutons.
func _unhandled_input(event: InputEvent) -> void:
	if view != View.NONE or not is_available():
		return
	if event.is_action_pressed(&"pause"):
		open_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"inventory"):
		open_inventory()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if view == View.NONE:
		return
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		if view == View.CONTROLS or view == View.CONFIRM_TITLE:
			_show_pause_buttons()
		else:
			close()
		get_viewport().set_input_as_handled()
	elif view == View.INVENTORY and event.is_action_pressed(&"inventory"):
		close()
		get_viewport().set_input_as_handled()


# --- Ouvrir / fermer ------------------------------------------------------------------

func open_pause() -> void:
	if not is_available():
		return
	_pause()
	_inventory_panel.visible = false
	_pause_panel.visible = true
	_show_pause_buttons()


func open_inventory(tab: InventoryTab = InventoryTab.ITEMS) -> void:
	if not is_available():
		return
	_pause()
	view = View.INVENTORY
	_pause_panel.visible = false
	_refresh_inventory()
	_inventory_tabs.current_tab = tab
	_inventory_panel.visible = true
	_root.visible = true
	_update_touch_buttons()
	MenuKit.focus_later(_inventory_tabs.get_tab_bar())


func close() -> void:
	if view == View.NONE:
		return
	view = View.NONE
	_root.visible = false
	get_tree().paused = _was_paused
	_update_touch_buttons()


func _pause() -> void:
	if view == View.NONE:
		_was_paused = get_tree().paused
	get_tree().paused = true
	hide_hint()


# --- Construction ---------------------------------------------------------------------

func _build() -> void:
	var base := Control.new()
	base.name = "Base"
	base.theme = GAME_THEME
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)

	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	base.add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	_pause_panel = _panel(Vector2(200.0, 0.0))
	_pause_panel.name = "Pause"
	center.add_child(_pause_panel)
	_pause_box = VBoxContainer.new()
	_pause_box.add_theme_constant_override(&"separation", 4)
	_pause_panel.add_child(_pause_box)

	_inventory_panel = _panel(Vector2(440.0, 220.0))
	_inventory_panel.name = "Inventory"
	center.add_child(_inventory_panel)
	var inventory_box := VBoxContainer.new()
	inventory_box.add_theme_constant_override(&"separation", 4)
	_inventory_panel.add_child(inventory_box)
	_inventory_tabs = TabContainer.new()
	_inventory_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inventory_tabs.custom_minimum_size = Vector2(0.0, 180.0)
	inventory_box.add_child(_inventory_tabs)
	var items_scroll := _scroll("Inventaire")
	_inventory_tabs.add_child(items_scroll)
	_items_box = HBoxContainer.new()
	_items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_box.add_theme_constant_override(&"separation", 10)
	items_scroll.add_child(_items_box)
	var grade_scroll := _scroll("Grade")
	_inventory_tabs.add_child(grade_scroll)
	_grade_list = VBoxContainer.new()
	_grade_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grade_list.add_theme_constant_override(&"separation", 3)
	grade_scroll.add_child(_grade_list)
	inventory_box.add_child(_button("Fermer", close))

	# Boutons tactiles et rappel des touches : sur un calque à part, au-dessus des
	# contrôles tactiles (10) mais sous les menus des scènes (15) qui les recouvrent.
	var overlay := CanvasLayer.new()
	overlay.name = "Overlay"
	overlay.layer = 11
	add_child(overlay)
	var overlay_base := Control.new()
	overlay_base.theme = GAME_THEME
	overlay_base.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(overlay_base)

	# Boutons tactiles, à droite : entre le sac du HUD (en haut) et les boutons d'action (en bas).
	_touch_buttons = VBoxContainer.new()
	_touch_buttons.name = "TouchButtons"
	_touch_buttons.add_theme_constant_override(&"separation", 4)
	_touch_buttons.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_touch_buttons.offset_left = -44.0
	_touch_buttons.offset_right = -4.0
	_touch_buttons.offset_top = 74.0
	_touch_buttons.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	overlay_base.add_child(_touch_buttons)
	var bag_button := _button("Sac", func() -> void: open_inventory())
	bag_button.icon = BAG_ICON
	bag_button.custom_minimum_size = Vector2(40.0, 24.0)
	_touch_buttons.add_child(bag_button)
	var pause_button := _button("II", open_pause)
	pause_button.custom_minimum_size = Vector2(40.0, 24.0)
	_touch_buttons.add_child(pause_button)
	for child: Node in _touch_buttons.get_children():
		(child as Button).focus_mode = Control.FOCUS_NONE

	# Rappel des touches, en bas au-dessus des consignes.
	_hint = Label.new()
	_hint.name = "Hint"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -220.0
	_hint.offset_right = 220.0
	_hint.offset_top = -46.0
	_hint.offset_bottom = -34.0
	_hint.add_theme_color_override(&"font_color", Color(0.95, 0.92, 0.8))
	_hint.add_theme_color_override(&"font_shadow_color", Color(0.06, 0.05, 0.06))
	_hint.add_theme_constant_override(&"shadow_offset_x", 1)
	_hint.add_theme_constant_override(&"shadow_offset_y", 1)
	_hint.modulate.a = 0.0
	overlay_base.add_child(_hint)


static func _panel(min_size: Vector2) -> PanelContainer:
	# Style : la plaque du thème (ui/theme/game_theme.tres).
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	return panel


static func _scroll(title: String) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	return scroll


static func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 18.0)
	button.pressed.connect(action)
	return button


func _update_touch_buttons() -> void:
	if _touch_buttons == null:
		return
	_touch_buttons.visible = InputMode.is_touch() and view == View.NONE and scene_kind() in TOUCH_BUTTON_KINDS


# --- Pause -----------------------------------------------------------------------------

func _show_pause_buttons() -> void:
	view = View.PAUSE
	_root.visible = true
	_update_touch_buttons()
	MenuKit.clear(_pause_box)
	var title := MenuKit.label("Pause", MenuKit.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 16)
	_pause_box.add_child(title)
	var resume := _button("Reprendre", close)
	_pause_box.add_child(resume)
	_pause_box.add_child(_button("Inventaire (%s)" % InputMode.label_for(&"inventory"), func() -> void: open_inventory()))
	_pause_box.add_child(_button("Commandes", _show_controls))
	_pause_box.add_child(_button("Écran titre", _confirm_title))
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		_pause_box.add_child(_button("Quitter le jeu", func() -> void: get_tree().quit()))
	var version := MenuKit.label(MenuKit.version_text(), MenuKit.MUTED)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_font_size_override(&"font_size", 7)
	_pause_box.add_child(version)
	MenuKit.focus_later(resume)


func _show_controls() -> void:
	view = View.CONTROLS
	MenuKit.clear(_pause_box)
	_pause_box.add_child(MenuKit.label("Commandes", MenuKit.GOLD))
	for line: Array in controls_lines(InputMode.current):
		var row := HBoxContainer.new()
		var action := MenuKit.label(line[0], MenuKit.MUTED)
		action.custom_minimum_size = Vector2(92.0, 0.0)
		row.add_child(action)
		row.add_child(MenuKit.label(line[1]))
		_pause_box.add_child(row)
	var back := _button("Retour", _show_pause_buttons)
	_pause_box.add_child(back)
	MenuKit.focus_later(back)


## Les commandes du périphérique : [action, touche(s)].
static func controls_lines(device: int) -> Array[Array]:
	match device:
		InputMode.Device.GAMEPAD:
			return [["Se déplacer", "Stick gauche, croix"], ["Frapper", "X"], ["Agir, fouiller", "A (maintenir)"],
				["Inventaire", "Y"], ["Pause", "Start"], ["Retour", "B"]]
		InputMode.Device.TOUCH:
			return [["Se déplacer", "Joystick à gauche"], ["Frapper", "Bouton Coup"], ["Agir, fouiller", "Bouton Agir (maintenir)"],
				["Inventaire", "Bouton Sac, à droite"], ["Pause", "Bouton II, à droite"], ["Retour", "Bouton retour du téléphone"]]
	return [["Se déplacer", "ZQSD, WASD ou flèches"], ["Frapper", "Espace ou clic gauche"],
		["Agir, fouiller", "E (maintenir)"], ["Inventaire", "I ou Tab"], ["Pause", "Échap"]]


func _confirm_title() -> void:
	view = View.CONFIRM_TITLE
	MenuKit.clear(_pause_box)
	_pause_box.add_child(MenuKit.label("Retourner à l'écran titre ?", MenuKit.GOLD))
	var warning := MenuKit.label(quit_warning(scene_kind()), MenuKit.MUTED)
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.custom_minimum_size = Vector2(184.0, 0.0)
	_pause_box.add_child(warning)
	_pause_box.add_child(_button("Oui, écran titre", _go_to_title))
	var stay := _button("Non, reprendre", _show_pause_buttons)
	_pause_box.add_child(stay)
	MenuKit.focus_later(stay)


## Ce qu'on perd en quittant ici.
static func quit_warning(kind: StringName) -> String:
	match kind:
		&"zone":
			return "Le butin de cet arrêt sera perdu : la partie reprendra au début du dernier trajet."
		&"refuge":
			return "Ce que tu as fait en gare sera perdu : la partie reprendra à ton arrivée."
	return "La partie est sauvegardée : tu reprendras ici, dans le train."


func _go_to_title() -> void:
	# Dans le train, rien n'est perdu : on sauvegarde la session telle quelle.
	save_if_possible()
	view = View.NONE
	_root.visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)


# --- Inventaire ------------------------------------------------------------------------

func _refresh_inventory() -> void:
	if view != View.INVENTORY:
		return
	MenuKit.clear(_items_box)
	_items_box.add_child(_equipment_column())
	_items_box.add_child(_bag_column())
	GradeView.fill(_grade_list)
	var title: String = "Grade"
	if not GameState.pending_promotions.is_empty():
		title = "Grade (talent à choisir)"
	_inventory_tabs.set_tab_title(InventoryTab.GRADE, title)


func _equipment_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", 2)
	column.add_child(MenuKit.label("Équipement porté", MenuKit.GOLD))
	for slot: int in EquipmentBar.SLOTS:
		var item: ItemData = GameState.loadout.get_item(slot)
		var row := HBoxContainer.new()
		row.add_child(MenuKit.icon(item.icon if item else null, 24.0))
		var info := VBoxContainer.new()
		info.add_theme_constant_override(&"separation", 0)
		info.add_child(MenuKit.label("%s : %s" % [ItemData.SLOT_NAMES[slot], item.display_name if item else "rien"]))
		info.add_child(MenuKit.label(item.describe_effects() if item else "—", MenuKit.MUTED))
		row.add_child(info)
		column.add_child(row)
	column.add_child(MenuKit.label("PV max %d · Armure %d · Protection %d %%" % [
		GameState.max_health(), GameState.armor(), roundi(GameState.protection() * 100.0)]))
	column.add_child(MenuKit.label("Infection : " + Infection.describe(GameState.infection), Infection.color(GameState.infection)))
	var tip := MenuKit.label("On change d'équipement au casier de l'atelier, dans le train.", MenuKit.MUTED)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(190.0, 0.0)
	column.add_child(tip)
	return column


func _bag_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", 2)
	var session := get_tree().get_first_node_in_group(StopSession.GROUP) as StopSession
	if session and scene_kind() == &"zone":
		var result: ExpeditionResult = session.result
		column.add_child(MenuKit.label("Sac : %d/%d" % [result.total_items(), session.capacity], MenuKit.GOLD))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override(&"h_separation", 10)
		for loot: LootData in GameState.LOOT_TYPES:
			var amount: int = result.get_amount(loot.id)
			if amount > 0:
				grid.add_child(_icon_line(loot.icon, "%s ×%d" % [loot.display_name, amount]))
		if grid.get_child_count() == 0:
			column.add_child(MenuKit.label("Vide pour l'instant.", MenuKit.MUTED))
		column.add_child(grid)
		for plan_id: StringName in result.plans:
			column.add_child(MenuKit.label("Plan trouvé : " + BlueprintCatalog.get_plan(plan_id).display_name, MenuKit.GOOD))
		for member: CrewMember in result.recruits:
			column.add_child(MenuKit.label("Recrue : %s (%s)" % [member.display_name, member.role_label], MenuKit.GOOD))
	else:
		column.add_child(MenuKit.label("Sac", MenuKit.GOLD))
		var empty := MenuKit.label("Vide : en rentrant, le butin est rangé dans le stock du train.", MenuKit.MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(190.0, 0.0)
		column.add_child(empty)
	var spare: Array[ItemData] = []
	for item: ItemData in GameState.owned_items:
		if GameState.loadout.get_item(item.slot) != item:
			spare.append(item)
	column.add_child(MenuKit.label("Équipement au casier (%d)" % spare.size(), MenuKit.GOLD))
	if spare.is_empty():
		column.add_child(MenuKit.label("Rien d'autre : fabrique-en à l'établi.", MenuKit.MUTED))
	for item: ItemData in spare:
		column.add_child(_icon_line(item.icon, item.display_name))
	return column


static func _icon_line(texture: Texture2D, text: String) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 3)
	line.add_child(MenuKit.icon(texture, 12.0))
	line.add_child(MenuKit.label(text))
	return line


# --- Rappel des touches ----------------------------------------------------------------

func _on_scene_changed() -> void:
	if view != View.NONE:
		close()
	_update_touch_buttons()
	var kind: StringName = scene_kind()
	if kind == &"zone" or kind == &"train":
		show_hint(hint_text(kind, InputMode.current))


## Rappel des touches pour une scène (vide sur téléphone : les boutons sont à l'écran).
static func hint_text(kind: StringName, device: int) -> String:
	if device == InputMode.Device.TOUCH:
		return ""
	var labels: Array = [InputMode.LABELS[&"inventory"][device], InputMode.LABELS[&"pause"][device]]
	var menus: String = "%s : inventaire · %s : pause" % labels
	if kind == &"zone":
		return "%s : frapper · %s (maintenir) : fouiller · %s" % [
			InputMode.LABELS[&"attack"][device], InputMode.LABELS[&"interact"][device], menus]
	return menus


func hide_hint() -> void:
	if _hint_tween:
		_hint_tween.kill()
	_hint.modulate.a = 0.0


func show_hint(text: String) -> void:
	if text.is_empty():
		return
	_hint.text = text
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint, "modulate:a", 1.0, 0.3)
	_hint_tween.tween_interval(HINT_TIME)
	_hint_tween.tween_property(_hint, "modulate:a", 0.0, 0.8)
