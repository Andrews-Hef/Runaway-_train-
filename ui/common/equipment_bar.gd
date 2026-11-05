class_name EquipmentBar
extends HBoxContainer
## Barre d'équipement : une case par emplacement (arme, outil, tenue, masque, sac)
## avec l'icône de ce qui est porté. Elle se met à jour toute seule quand on
## change d'équipement. Dans le HUD de la zone et en haut à gauche du train.

## Ordre des cases : ce qui sert en sortie d'abord.
const SLOTS: Array[int] = [ItemData.Slot.WEAPON, ItemData.Slot.TOOL, ItemData.Slot.OUTFIT,
	ItemData.Slot.MASK, ItemData.Slot.BAG]
const CELL_SIZE: float = 16.0
const EMPTY_COLOR: Color = Color(0.45, 0.45, 0.5, 0.6)

var _icons: Dictionary[int, TextureRect] = {}


func _ready() -> void:
	add_theme_constant_override(&"separation", 2)
	for slot: int in SLOTS:
		var cell := PanelContainer.new()
		cell.add_theme_stylebox_override(&"panel", _cell_style())
		cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
		var icon := MenuKit.icon(null, 12.0)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(icon)
		add_child(cell)
		_icons[slot] = icon
	GameState.equipment_changed.connect(refresh)
	refresh()


func refresh() -> void:
	for slot: int in SLOTS:
		var item: ItemData = GameState.loadout.get_item(slot)
		var icon: TextureRect = _icons[slot]
		icon.texture = item.icon if item else null
		var cell := icon.get_parent() as Control
		cell.tooltip_text = "%s : %s" % [ItemData.SLOT_NAMES[slot], item.display_name if item else "rien"]


## Icône portée dans une case (null si rien) : pour les tests.
func icon_for(slot: int) -> Texture2D:
	return _icons[slot].texture


static func _cell_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	style.border_color = Color(0.45, 0.4, 0.3, 0.9)
	style.set_border_width_all(1)
	style.set_content_margin_all(1.0)
	return style


## Un panneau prêt à poser en haut à gauche d'une interface (train, gare).
static func make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.06, 0.75)
	style.set_content_margin_all(3.0)
	panel.add_theme_stylebox_override(&"panel", style)
	panel.position = Vector2(4.0, 4.0)
	panel.add_child(EquipmentBar.new())
	return panel
