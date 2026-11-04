extends CanvasLayer
## Menu du train : stock, atelier (fabrication), équipement, équipage.
##
## Un seul panneau à onglets ; chaque meuble du train l'ouvre sur son onglet.
## Il lit et modifie GameState, rien d'autre.

signal closed

enum Tab { STOCK, WORKSHOP, EQUIPMENT, CREW }

const GOOD: Color = Color(0.55, 0.85, 0.45)
const BAD: Color = Color(1.0, 0.45, 0.35)
const MUTED: Color = Color(0.7, 0.7, 0.74)
const GOLD: Color = Color(1.0, 0.82, 0.35)

@onready var _root: Control = $Root
@onready var _tabs: TabContainer = %Tabs
@onready var _stock_list: VBoxContainer = %StockList
@onready var _workshop_list: VBoxContainer = %WorkshopList
@onready var _equipment_list: VBoxContainer = %EquipmentList
@onready var _crew_list: VBoxContainer = %CrewList
@onready var _close: Button = %Close


func _ready() -> void:
	_root.visible = false
	_close.pressed.connect(close)
	for signal_name: StringName in [&"storage_changed", &"equipment_changed", &"crew_changed"]:
		GameState.connect(signal_name, _refresh)
	_tabs.set_tab_title(Tab.STOCK, "Stock")
	_tabs.set_tab_title(Tab.WORKSHOP, "Atelier")
	_tabs.set_tab_title(Tab.EQUIPMENT, "Équipement")
	_tabs.set_tab_title(Tab.CREW, "Équipage")


func _unhandled_input(event: InputEvent) -> void:
	if _root.visible and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause")):
		close()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _root.visible


func open(tab: Tab) -> void:
	_refresh()
	_tabs.current_tab = tab
	_root.visible = true
	_close.grab_focus.call_deferred()


func close() -> void:
	if not _root.visible:
		return
	_root.visible = false
	closed.emit()


func _refresh() -> void:
	_fill_stock()
	_fill_workshop()
	_fill_equipment()
	_fill_crew()


# --- Stock ------------------------------------------------------------------------

func _fill_stock() -> void:
	_clear(_stock_list)
	for loot: LootData in GameState.LOOT_TYPES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 4)
		var swatch := ColorRect.new()
		swatch.color = loot.color
		swatch.custom_minimum_size = Vector2(6.0, 6.0)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		row.add_child(_label("%s : %d" % [loot.display_name, GameState.storage_amount(loot.id)]))
		_stock_list.add_child(row)
	_stock_list.add_child(_label("Équipements à bord : %d" % GameState.owned_items.size(), MUTED))


# --- Atelier ----------------------------------------------------------------------

func _fill_workshop() -> void:
	_clear(_workshop_list)
	for item: ItemData in ItemCatalog.craftables():
		var owned: bool = item in GameState.owned_items
		var lacking := Crafting.missing(item, GameState.storage)
		var row := HBoxContainer.new()
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override(&"separation", 0)
		info.add_child(_label("%s (%s) — %s" % [item.display_name, item.slot_name(), item.describe_effects()]))
		info.add_child(_label("Coût : " + _describe_amounts(item.recipe), MUTED if owned else (GOOD if lacking.is_empty() else BAD)))
		row.add_child(info)
		var button := Button.new()
		button.custom_minimum_size = Vector2(64.0, 18.0)
		if owned:
			button.text = "Possédé"
			button.disabled = true
		else:
			button.text = "Fabriquer"
			button.disabled = not lacking.is_empty()
			button.pressed.connect(func() -> void: GameState.craft(item))
		row.add_child(button)
		_workshop_list.add_child(row)


# --- Équipement -------------------------------------------------------------------

func _fill_equipment() -> void:
	_clear(_equipment_list)
	var loadout: Loadout = GameState.loadout
	_equipment_list.add_child(_label(loadout.describe(), GOLD))
	for slot: int in ItemData.Slot.values():
		var options: Array[ItemData] = GameState.owned_for_slot(slot)
		var current: ItemData = loadout.get_item(slot)
		var row := HBoxContainer.new()
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override(&"separation", 0)
		var name_text: String = current.display_name if current else "rien"
		info.add_child(_label("%s : %s" % [ItemData.SLOT_NAMES[slot], name_text]))
		info.add_child(_label(current.describe_effects() if current else "Fabrique-en un à l'atelier.", MUTED))
		row.add_child(info)
		var button := Button.new()
		button.custom_minimum_size = Vector2(64.0, 18.0)
		button.text = "Changer (%d)" % options.size()
		button.disabled = options.size() < 2
		button.pressed.connect(func() -> void: _cycle(slot))
		row.add_child(button)
		_equipment_list.add_child(row)


## Passe à l'équipement suivant possédé pour cet emplacement.
func _cycle(slot: int) -> void:
	var options: Array[ItemData] = GameState.owned_for_slot(slot)
	if options.is_empty():
		return
	var index: int = options.find(GameState.loadout.get_item(slot))
	GameState.equip(options[(index + 1) % options.size()])


# --- Équipage ---------------------------------------------------------------------

func _fill_crew() -> void:
	_clear(_crew_list)
	if GameState.crew.is_empty():
		_crew_list.add_child(_label("Personne à bord pour l'instant.", MUTED))
		_crew_list.add_child(_label("Recrute des survivants dans les refuges pendant les sorties.", MUTED))
		return
	for member: CrewMember in GameState.crew:
		_crew_list.add_child(_label("%s — %s" % [member.display_name, member.role_label]))


# --- Outils -----------------------------------------------------------------------

func _label(text: String, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	if color != Color.WHITE:
		label.add_theme_color_override(&"font_color", color)
	return label


static func _clear(container: Container) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


static func _describe_amounts(amounts: Dictionary[StringName, int]) -> String:
	var parts: PackedStringArray = []
	for id: StringName in amounts:
		var loot_name: String = String(id)
		for loot: LootData in GameState.LOOT_TYPES:
			if loot.id == id:
				loot_name = loot.display_name.to_lower()
		parts.append("%d %s" % [amounts[id], loot_name])
	return ", ".join(parts)
