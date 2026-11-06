class_name BagHotbar
extends HBoxContainer
## Les cases du sac en bas de l'écran, façon Minecraft : une pile par case (icône et
## nombre), les cases libres vides. « Sac plein » s'affiche en rouge à droite.

const SLOT: Vector2 = Vector2(20.0, 20.0)
const FULL_COLOR: Color = Color(1.0, 0.45, 0.35)
const NUMBERS_FONT: Font = preload("res://assets/fonts/barlow/Barlow-Bold.ttf")

var _icons: Dictionary[StringName, Texture2D] = {}
var _order: Array[StringName] = []
var _slots: HBoxContainer
var _full: Label


func _init() -> void:
	name = "BagHotbar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 4)
	alignment = BoxContainer.ALIGNMENT_CENTER
	_slots = HBoxContainer.new()
	_slots.name = "Slots"
	_slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slots.add_theme_constant_override(&"separation", 2)
	add_child(_slots)
	_full = Label.new()
	_full.name = "Full"
	_full.text = "Sac plein"
	_full.visible = false
	_full.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_full.add_theme_color_override(&"font_color", FULL_COLOR)
	add_child(_full)


## Les ressources possibles (icônes, ordre des piles).
func set_loot_types(loot_types: Array[LootData]) -> void:
	_icons.clear()
	_order.clear()
	for loot: LootData in loot_types:
		_icons[loot.id] = loot.icon
		_order.append(loot.id)


## Redessine les cases : `capacity` cases, remplies par les piles du butin.
func show_bag(loot: Dictionary[StringName, int], capacity: int) -> void:
	var stacks: Array[Dictionary] = BagSlots.layout(loot, _order)
	var count: int = maxi(capacity, stacks.size())
	while _slots.get_child_count() < count:
		_slots.add_child(_make_slot())
	while _slots.get_child_count() > count:
		var extra: Node = _slots.get_child(_slots.get_child_count() - 1)
		_slots.remove_child(extra)
		extra.queue_free()
	for i: int in count:
		var cell: Node = _slots.get_child(i)
		var picture := cell.get_node("Box/Icon") as TextureRect
		var amount := cell.get_node("Box/Amount") as Label
		if i < stacks.size():
			picture.texture = _icons.get(stacks[i].id)
			amount.text = str(stacks[i].amount)
		else:
			picture.texture = null
			amount.text = ""
	_full.visible = capacity >= 0 and BagSlots.used(loot) >= capacity


## Nombre de cases affichées, et de cases remplies (pour les tests).
func slot_count() -> int:
	return _slots.get_child_count()


func filled_count() -> int:
	var filled: int = 0
	for cell: Node in _slots.get_children():
		if (cell.get_node("Box/Icon") as TextureRect).texture != null:
			filled += 1
	return filled


func _make_slot() -> PanelContainer:
	var cell := PanelContainer.new()
	cell.theme_type_variation = &"SlotPanel"
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := Control.new()
	box.name = "Box"
	box.custom_minimum_size = SLOT - Vector2(4.0, 4.0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(box)
	var picture := TextureRect.new()
	picture.name = "Icon"
	picture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(picture)
	var amount := Label.new()
	amount.name = "Amount"
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	amount.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	amount.offset_right = 1.0
	amount.offset_bottom = 1.0
	amount.add_theme_font_override(&"font", NUMBERS_FONT)
	amount.add_theme_font_size_override(&"font_size", 9)
	amount.add_theme_color_override(&"font_shadow_color", Color(0.06, 0.05, 0.06))
	amount.add_theme_constant_override(&"shadow_offset_x", 1)
	amount.add_theme_constant_override(&"shadow_offset_y", 1)
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(amount)
	return cell
