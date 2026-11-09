class_name EquipmentBar
extends HBoxContainer
## Barre d'équipement : une case par emplacement (arme, outil, tenue, masque, sac)
## avec l'icône de ce qui est porté. Elle se met à jour toute seule quand on
## change d'équipement. Dans le HUD de la zone et en haut à gauche du train.

## Ordre des cases : ce qui sert en sortie d'abord.
const SLOTS: Array[int] = [ItemData.Slot.WEAPON, ItemData.Slot.TOOL, ItemData.Slot.OUTFIT,
	ItemData.Slot.MASK, ItemData.Slot.BAG]
const CELL_SIZE: float = 16.0

var _icons: Dictionary[int, TextureRect] = {}


func _ready() -> void:
	add_theme_constant_override(&"separation", 2)
	for slot: int in SLOTS:
		var cell := PanelContainer.new()
		cell.theme_type_variation = &"SlotPanel"
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



## Un panneau prêt à poser en haut à gauche d'une interface (train, gare).
static func make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"HudPanel"
	panel.position = Vector2(4.0, 4.0)
	panel.add_child(EquipmentBar.new())
	return panel


## Cale le bandeau d'infos du haut (`top`) à droite de la barre d'équipement (`bar`, déjà
## dans l'arbre) : ils ne peuvent plus se chevaucher, quelle que soit la largeur de l'écran
## (480 px de large en 16:9 sur PC, 600 en 20:9 sur téléphone). Les textes trop longs
## passent à la ligne au lieu de déborder.
static func dock_beside(bar: Control, top: Control, gap: float = 4.0) -> void:
	top.anchor_left = 0.0
	top.anchor_right = 1.0
	top.offset_left = bar.position.x + bar.get_combined_minimum_size().x + gap
	top.offset_right = -bar.position.x
	for node: Node in top.find_children("*", "Label", true, false):
		(node as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
