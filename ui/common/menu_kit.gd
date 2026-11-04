class_name MenuKit
extends RefCounted
## Petits morceaux d'interface partagés par les menus (train, gare refuge) :
## libellés colorés, lignes « titre + détail + bouton », coûts lisibles.

const GOOD: Color = Color(0.55, 0.85, 0.45)
const BAD: Color = Color(1.0, 0.45, 0.35)
const MUTED: Color = Color(0.7, 0.7, 0.74)
const GOLD: Color = Color(1.0, 0.82, 0.35)


static func label(text: String, color: Color = Color.WHITE) -> Label:
	var node := Label.new()
	node.text = text
	if color != Color.WHITE:
		node.add_theme_color_override(&"font_color", color)
	return node


## Une ligne « titre + détail » avec un bouton à droite (action vide = pas de bouton actif).
static func row(title: String, detail: String, detail_color: Color, button_text: String, disabled: bool,
		action: Callable) -> HBoxContainer:
	var line := HBoxContainer.new()
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override(&"separation", 0)
	info.add_child(label(title))
	var detail_label := label(detail, detail_color)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(detail_label)
	line.add_child(info)
	var button := Button.new()
	button.custom_minimum_size = Vector2(64.0, 18.0)
	button.text = button_text
	button.disabled = disabled
	if action.is_valid():
		button.pressed.connect(action)
	line.add_child(button)
	return line


static func clear(container: Container) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


## « 3 bois, 2 tissu ».
static func describe_amounts(amounts: Dictionary[StringName, int]) -> String:
	var parts: PackedStringArray = []
	for id: StringName in amounts:
		parts.append("%d %s" % [amounts[id], loot_name(id).to_lower()])
	return ", ".join(parts)


static func loot_name(id: StringName) -> String:
	for loot: LootData in GameState.LOOT_TYPES:
		if loot.id == id:
			return loot.display_name
	return String(id)
