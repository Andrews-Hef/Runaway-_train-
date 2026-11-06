extends CanvasLayer
## Autoload « GameMenu » : menu pause (Échap / Start) et inventaire (I / Tab / Y),
## partout en jeu sauf sur l'écran titre. Le jeu est en pause tant qu'ils sont ouverts.
##
## - Pause : reprendre, inventaire, commandes, écran titre, quitter (PC).
## - Inventaire façon Minecraft : le personnage et ses 5 cases d'équipement, le sac en
##   cases (piles de 5 ; cases grisées = ce qu'un sac plus grand ajouterait) et le
##   casier. On touche une case, l'objet s'affiche en bas avec ce qu'on peut en faire :
##   « Jeter 1 » / « Jeter la pile » pendant un arrêt (le tas reste au sol), « Équiper »
##   dans le train seulement (on s'équipe avant de descendre),
##   équipement à bord ; onglet Grade (mérite, ordre, choix des talents).
## - Sur téléphone : deux boutons côte à côte en haut à droite, « Sac » et « II ».
## - À l'arrivée en zone et dans le train : rappel des touches pendant quelques secondes.
## - Android : le bouton retour fait comme Échap (il ne quitte pas le jeu, sauf depuis
##   l'écran titre). Quand l'app passe en arrière-plan, le jeu se met en pause et se
##   sauvegarde si possible (Android peut fermer une app en arrière-plan).
##
## L'interface est construite en code (comme les menus du train) et lit GameState.

enum View { NONE, PAUSE, CONTROLS, CONFIRM_TITLE, INVENTORY }
enum InventoryTab { ITEMS, GRADE }

## Le menu se referme (le casier du train rend alors la main au joueur).
signal closed

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
## Inventaire : taille d'une case et de son icône (×2, nette).
const SLOT_SIZE: Vector2 = Vector2(28.0, 28.0)
const SLOT_ICON: float = 24.0
const PORTRAIT: Texture2D = preload("res://assets/sprites/survivor/survivor.png")
## Emplacements autour du personnage : à gauche, puis à droite.
const LEFT_SLOTS: Array[int] = [ItemData.Slot.MASK, ItemData.Slot.OUTFIT, ItemData.Slot.BAG]
const RIGHT_SLOTS: Array[int] = [ItemData.Slot.WEAPON, ItemData.Slot.TOOL]
## Sac : au moins 2 rangées de 4 (au-delà du sac porté, cases grisées). Casier : 3 de large.
const BAG_COLUMNS: int = 4
const LOCKER_COLUMNS: int = 3

var view: View = View.NONE

var _root: Control
var _pause_panel: PanelContainer
var _pause_box: VBoxContainer
var _inventory_panel: PanelContainer
## Ressource dont la ligne reprend le focus après un « Jeter » (clavier, manette).
## Case choisie dans l'inventaire : {"kind": &"bag"|&"worn"|&"locker", "id" ou "item"}.
var _selected: Dictionary = {}
## Bas de l'onglet Inventaire : l'objet choisi et ses actions.
var _detail_box: HBoxContainer
var _inventory_tabs: TabContainer
var _items_box: HBoxContainer
var _grade_list: VBoxContainer
var _touch_buttons: HBoxContainer
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
	_selected = _default_selection()
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
	closed.emit()


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

	_inventory_panel = _panel(Vector2(440.0, 250.0))
	_inventory_panel.name = "Inventory"
	center.add_child(_inventory_panel)
	var inventory_box := VBoxContainer.new()
	inventory_box.add_theme_constant_override(&"separation", 4)
	_inventory_panel.add_child(inventory_box)
	_inventory_tabs = TabContainer.new()
	_inventory_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inventory_tabs.custom_minimum_size = Vector2(0.0, 206.0)
	inventory_box.add_child(_inventory_tabs)
	var items_scroll := _scroll("Inventaire")
	_inventory_tabs.add_child(items_scroll)
	var items_page := VBoxContainer.new()
	items_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_page.add_theme_constant_override(&"separation", 6)
	items_scroll.add_child(items_page)
	_items_box = HBoxContainer.new()
	_items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_box.add_theme_constant_override(&"separation", 12)
	items_page.add_child(_items_box)
	var detail_panel := PanelContainer.new()
	detail_panel.theme_type_variation = &"InsetPanel"
	items_page.add_child(detail_panel)
	_detail_box = HBoxContainer.new()
	_detail_box.name = "Detail"
	_detail_box.add_theme_constant_override(&"separation", 6)
	_detail_box.custom_minimum_size = Vector2(0.0, 26.0)
	detail_panel.add_child(_detail_box)
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

	# Boutons tactiles, côte à côte en haut à droite (le HUD laisse ce coin libre).
	_touch_buttons = HBoxContainer.new()
	_touch_buttons.name = "TouchButtons"
	_touch_buttons.add_theme_constant_override(&"separation", 4)
	_touch_buttons.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_touch_buttons.offset_left = -76.0
	_touch_buttons.offset_right = -4.0
	_touch_buttons.offset_top = 4.0
	_touch_buttons.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	overlay_base.add_child(_touch_buttons)
	var bag_button := _button("Sac", func() -> void: open_inventory())
	bag_button.icon = BAG_ICON
	bag_button.custom_minimum_size = Vector2(44.0, 24.0)
	_touch_buttons.add_child(bag_button)
	var pause_button := _button("II", open_pause)
	pause_button.custom_minimum_size = Vector2(24.0, 24.0)
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
	_hint.offset_top = -56.0
	_hint.offset_bottom = -44.0
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
	_items_box.add_child(_locker_column())
	_fill_detail()
	GradeView.fill(_grade_list)
	var title: String = "Grade"
	if not GameState.pending_promotions.is_empty():
		title = "Grade (talent à choisir)"
	_inventory_tabs.set_tab_title(InventoryTab.GRADE, title)


## On change d'équipement dans le train seulement.
func can_change_equipment() -> bool:
	return scene_kind() == &"train"


func _session() -> StopSession:
	if scene_kind() != &"zone":
		return null
	return get_tree().get_first_node_in_group(StopSession.GROUP) as StopSession


## À l'ouverture : la première pile du sac en arrêt, le premier objet du casier à bord.
func _default_selection() -> Dictionary:
	var session := _session()
	if session:
		var stacks := BagSlots.layout(session.result.loot, _loot_order())
		if not stacks.is_empty():
			return {"kind": &"bag", "id": stacks[0].id}
	if can_change_equipment():
		var spare := _spare_items()
		if not spare.is_empty():
			return {"kind": &"locker", "item": spare[0]}
	return {}


static func _loot_order() -> Array[StringName]:
	var order: Array[StringName] = []
	for loot: LootData in GameState.LOOT_TYPES:
		order.append(loot.id)
	return order


static func _loot(id: StringName) -> LootData:
	for loot: LootData in GameState.LOOT_TYPES:
		if loot.id == id:
			return loot
	return null


static func _spare_items() -> Array[ItemData]:
	var spare: Array[ItemData] = []
	for item: ItemData in GameState.owned_items:
		if GameState.loadout.get_item(item.slot) != item:
			spare.append(item)
	return spare


## Une case : son cadre, l'icône (×2), le nombre en bas à droite (`amount` > 0, les
## piles du sac). `on_press` vide :
## case inerte (vide, grisée). `selected` : liseré doré.
func _slot(texture: Texture2D, amount: int, tip: String, selected: bool, on_press: Callable) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.theme_type_variation = &"SlotPanel"
	if selected:
		var gold := StyleBoxFlat.new()
		gold.bg_color = Color(0.18, 0.15, 0.1, 0.9)
		gold.set_border_width_all(1)
		gold.border_color = MenuKit.GOLD
		cell.add_theme_stylebox_override(&"panel", gold)
	var button := Button.new()
	button.flat = true
	button.custom_minimum_size = SLOT_SIZE
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_ALL if on_press.is_valid() else Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP if on_press.is_valid() else Control.MOUSE_FILTER_IGNORE
	if on_press.is_valid():
		button.pressed.connect(on_press)
	cell.add_child(button)
	if texture:
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var picture := MenuKit.icon(texture, SLOT_ICON)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(picture)
		button.add_child(center)
	if amount > 0:
		var count := Label.new()
		count.text = str(amount)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		count.offset_right = -1.0
		count.offset_bottom = 1.0
		count.add_theme_font_override(&"font", BagHotbar.NUMBERS_FONT)
		count.add_theme_font_size_override(&"font_size", 9)
		count.add_theme_color_override(&"font_shadow_color", Color(0.06, 0.05, 0.06))
		count.add_theme_constant_override(&"shadow_offset_x", 1)
		count.add_theme_constant_override(&"shadow_offset_y", 1)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(count)
	if selected and on_press.is_valid():
		MenuKit.focus_later(button)
	return cell


func _select(selection: Dictionary) -> void:
	_selected = selection
	_refresh_inventory()


func _is_selected(kind: StringName, key: Variant) -> bool:
	if _selected.get("kind", &"") != kind:
		return false
	return _selected.get("id" if kind == &"bag" else "item") == key


# --- Colonne 1 : le personnage et ce qu'il porte ---------------------------------------

func _equipment_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 3)
	column.add_child(MenuKit.label("Équipement porté", MenuKit.GOLD))
	var figure := HBoxContainer.new()
	figure.add_theme_constant_override(&"separation", 3)
	column.add_child(figure)
	figure.add_child(_worn_slots(LEFT_SLOTS))
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"InsetPanel"
	var portrait := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = PORTRAIT
	atlas.region = Rect2(0.0, 0.0, 36.0, 40.0)
	portrait.texture = atlas
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(54.0, 60.0)
	frame.add_child(portrait)
	figure.add_child(frame)
	figure.add_child(_worn_slots(RIGHT_SLOTS))
	column.add_child(MenuKit.label("PV %d · Armure %d · Prot. %d %%" % [
		GameState.max_health(), GameState.armor(), roundi(GameState.protection() * 100.0)], MenuKit.MUTED))
	column.add_child(MenuKit.label("Infection : " + Infection.describe(GameState.infection), Infection.color(GameState.infection)))
	return column


func _worn_slots(slots: Array[int]) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 3)
	for slot: int in slots:
		var item: ItemData = GameState.loadout.get_item(slot)
		var tip: String = "%s : %s" % [ItemData.SLOT_NAMES[slot], item.display_name if item else "rien"]
		var on_press: Callable = func() -> void: _select({"kind": &"worn", "item": item, "slot": slot})
		box.add_child(_slot(item.icon if item else null, 0, tip, _is_selected(&"worn", item) and item != null, on_press))
	return box


# --- Colonne 2 : le sac en cases --------------------------------------------------------

func _bag_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 3)
	var capacity: int = GameState.bag_capacity()
	var session := _session()
	var loot: Dictionary[StringName, int] = {}
	if session:
		loot = session.result.loot
		capacity = session.capacity
	var bag: ItemData = GameState.loadout.get_item(ItemData.Slot.BAG)
	var used: int = BagSlots.used(loot)
	column.add_child(MenuKit.label("Sac · %s · %d/%d cases" % [bag.display_name if bag else "aucun", used, capacity],
		MenuKit.BAD if used >= capacity else MenuKit.GOLD))
	var grid := GridContainer.new()
	grid.name = "BagGrid"
	grid.columns = BAG_COLUMNS
	grid.add_theme_constant_override(&"h_separation", 3)
	grid.add_theme_constant_override(&"v_separation", 3)
	column.add_child(grid)
	var stacks := BagSlots.layout(loot, _loot_order())
	var shown: int = maxi(ceili(float(capacity) / BAG_COLUMNS) * BAG_COLUMNS, BAG_COLUMNS * 2)
	var seen: Dictionary[StringName, bool] = {}
	for i: int in shown:
		if i < stacks.size():
			var id: StringName = stacks[i].id
			var data := _loot(id)
			# La première pile d'une ressource porte la sélection.
			var selected: bool = _is_selected(&"bag", id) and not seen.has(id)
			seen[id] = true
			var on_press: Callable = func() -> void: _select({"kind": &"bag", "id": id})
			grid.add_child(_slot(data.icon if data else null, stacks[i].amount, "%s ×%d" % [data.display_name if data else id, stacks[i].amount], selected, on_press))
		else:
			var cell := _slot(null, 0, "", false, Callable())
			if i >= capacity:
				cell.modulate.a = 0.3
			grid.add_child(cell)
	var tip: String
	if session == null:
		tip = "Vide à bord : il se remplit pendant les arrêts, et le butin va au stock du train."
	elif capacity < BAG_COLUMNS * 2:
		tip = "Cases grisées : un sac plus grand ou un talent en ajoute."
	if not tip.is_empty():
		var note := MenuKit.label(tip, MenuKit.MUTED)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(124.0, 0.0)
		column.add_child(note)
	if session:
		for plan_id: StringName in session.result.plans:
			column.add_child(MenuKit.label("Plan : " + BlueprintCatalog.get_plan(plan_id).display_name, MenuKit.GOOD))
		for member: CrewMember in session.result.recruits:
			column.add_child(MenuKit.label("Recrue : " + member.display_name, MenuKit.GOOD))
	return column


# --- Colonne 3 : le casier (à bord) -----------------------------------------------------

func _locker_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 3)
	var active: bool = can_change_equipment()
	var spare := _spare_items()
	column.add_child(MenuKit.label("Casier · %d" % spare.size() if active else "Casier · dans le train", MenuKit.GOLD if active else MenuKit.MUTED))
	var grid := GridContainer.new()
	grid.name = "LockerGrid"
	grid.columns = LOCKER_COLUMNS
	grid.add_theme_constant_override(&"h_separation", 3)
	grid.add_theme_constant_override(&"v_separation", 3)
	if not active:
		grid.modulate.a = 0.45
	column.add_child(grid)
	var shown: int = maxi(ceili(float(spare.size()) / LOCKER_COLUMNS) * LOCKER_COLUMNS, LOCKER_COLUMNS * 2)
	for i: int in shown:
		if i < spare.size():
			var item: ItemData = spare[i]
			var on_press: Callable = (func() -> void: _select({"kind": &"locker", "item": item})) if active else Callable()
			grid.add_child(_slot(item.icon, 0, item.display_name, active and _is_selected(&"locker", item), on_press))
		else:
			grid.add_child(_slot(null, 0, "", false, Callable()))
	var text: String = "Touche un objet, puis « Équiper » : il remplace celui que tu portes." if active \
		else "On change d'équipement dans le train, avant de descendre."
	if spare.is_empty():
		text = "Rien d'autre : fabrique-en à l'établi."
	var note := MenuKit.label(text, MenuKit.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(96.0, 0.0)
	column.add_child(note)
	return column


# --- En bas : l'objet choisi et ses actions ---------------------------------------------

func _fill_detail() -> void:
	MenuKit.clear(_detail_box)
	match _selected.get("kind", &""):
		&"bag":
			var session := _session()
			var id: StringName = _selected.get("id", &"")
			var amount: int = session.result.get_amount(id) if session else 0
			var data := _loot(id)
			if session == null or amount <= 0 or data == null:
				_selected = {}
				_fill_detail()
				return
			_detail_line(data.icon, "%s ×%d" % [data.display_name, amount], data.describe())
			var pile: int = mini(amount, BagSlots.STACK_SIZE)
			_detail_box.add_child(_action("Jeter 1", func() -> void: _drop(session, id, 1)))
			if pile > 1:
				_detail_box.add_child(_action("Jeter la pile (%d)" % pile, func() -> void: _drop(session, id, pile)))
		&"locker":
			var item: ItemData = _selected.get("item")
			if item == null or not item in _spare_items():
				_selected = {}
				_fill_detail()
				return
			var worn: ItemData = GameState.loadout.get_item(item.slot)
			var compare: String = "Tu portes : %s." % worn.display_name if worn else "Emplacement vide."
			_detail_line(item.icon, "%s · %s" % [item.display_name, ItemData.SLOT_NAMES[item.slot]], "%s · %s" % [item.describe_effects(), compare])
			var equip := _action("Équiper", func() -> void: _equip(item))
			equip.disabled = not can_change_equipment()
			_detail_box.add_child(equip)
		&"worn":
			var item: ItemData = _selected.get("item")
			if item == null:
				_selected = {}
				_fill_detail()
				return
			_detail_line(item.icon, "%s · %s (porté)" % [item.display_name, ItemData.SLOT_NAMES[item.slot]], item.describe_effects())
		_:
			_detail_line(null, "Touche une case pour voir ce qu'elle contient.", "")


func _detail_line(texture: Texture2D, title: String, text: String) -> void:
	if texture:
		_detail_box.add_child(MenuKit.icon(texture, SLOT_ICON))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override(&"separation", 0)
	info.add_child(MenuKit.label(title))
	if not text.is_empty():
		var line := MenuKit.label(text, MenuKit.MUTED)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(line)
	_detail_box.add_child(info)


static func _action(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 20.0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(action)
	return button


## Jette du sac (la zone pose le tas), puis redessine l'inventaire : la sélection reste
## sur la même ressource s'il en reste.
func _drop(session: StopSession, id: StringName, amount: int) -> void:
	if session.drop(id, amount) <= 0:
		return
	if session.result.get_amount(id) <= 0:
		_selected = _default_selection()
	_refresh_inventory()


## Équipe un objet du casier (à bord) : celui qu'on portait revient au casier ; la
## sélection suit l'objet, maintenant porté.
func _equip(item: ItemData) -> void:
	if not can_change_equipment():
		return
	GameState.equip(item)
	_selected = {"kind": &"worn", "item": item, "slot": item.slot}
	_refresh_inventory()


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
