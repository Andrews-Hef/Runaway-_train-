class_name MenuKit
extends RefCounted
## Petits morceaux d'interface partagés par les menus (train, gare refuge) :
## libellés colorés, pastilles chiffrées, coûts en petites cases, barre de détail.

const GOOD: Color = Color(0.55, 0.85, 0.45)
const BAD: Color = Color(1.0, 0.45, 0.35)
const MUTED: Color = Color(0.7, 0.7, 0.74)
const GOLD: Color = Color(1.0, 0.82, 0.35)

const ARROW: Texture2D = preload("res://assets/ui/icons/arrow.png")
## Portraits d'équipiers teintés selon le rôle : on reconnaît le mécano du soigneur sans lire.
const ROLE_COLORS: Dictionary[StringName, Color] = {
	&"mechanic": Color(1.0, 0.78, 0.5),
	&"medic": Color(0.62, 1.0, 0.82),
	&"scout": Color(0.7, 0.85, 1.0),
}


static func label(text: String, color: Color = Color.WHITE) -> Label:
	var node := Label.new()
	node.text = text
	if color != Color.WHITE:
		node.add_theme_color_override(&"font_color", color)
	return node


## Icône pixel art (12 px de base) affichée à `size` px, sans flou.
static func icon(texture: Texture2D, size: float = 12.0) -> TextureRect:
	var node := TextureRect.new()
	node.texture = texture
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.custom_minimum_size = Vector2(size, size)
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return node


## Une ligne « titre + détail » avec un bouton à droite (action vide = pas de bouton actif).
## `picture` : icône à gauche (équipement, ressource), facultative.
static func row(title: String, detail: String, detail_color: Color, button_text: String, disabled: bool,
		action: Callable, picture: Texture2D = null) -> HBoxContainer:
	var line := HBoxContainer.new()
	if picture:
		line.add_child(icon(picture, 24.0))
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


## Donne le focus (clavier, manette) au prochain frame, si le contrôle est encore
## affiché : un menu reconstruit entre-temps (MenuKit.clear) a pu le retirer.
static func focus_later(control: Control) -> void:
	_focus_if_shown.call_deferred(control)


static func _focus_if_shown(control: Variant) -> void:
	if is_instance_valid(control) and (control as Control).is_inside_tree() and (control as Control).is_visible_in_tree():
		(control as Control).grab_focus()


## Version du jeu (« v0.0.1-rc1 ») : la CI y met le tag ou « -dev.<n° du run> ».
static func version_text() -> String:
	return "v%s" % ProjectSettings.get_setting("application/config/version", "?")


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


# --- Menus en cases -----------------------------------------------------------------

## Pastille « icône + nombre » des en-têtes (4/5 voitures, 47/60 places...).
## L'explication est dans l'infobulle, pas à l'écran.
static func chip(texture: Texture2D, text: String, color: Color = Color.WHITE, tip: String = "") -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 2)
	box.tooltip_text = tip
	box.mouse_filter = Control.MOUSE_FILTER_STOP if not tip.is_empty() else Control.MOUSE_FILTER_IGNORE
	if texture:
		var picture := icon(texture, 12.0)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(picture)
	var value := label(text, color)
	value.add_theme_font_override(&"font", BagHotbar.NUMBERS_FONT)
	value.add_theme_font_size_override(&"font_size", 9)
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(value)
	return box


## Ligne d'en-tête d'un onglet : des pastilles, espacées.
static func header() -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	return box


## Petit titre de section, doré.
static func section(text: String) -> Label:
	return label(text, GOLD)


## Une grille de cases qui passe à la ligne toute seule.
static func grid() -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override(&"h_separation", 2)
	flow.add_theme_constant_override(&"v_separation", 2)
	return flow


## Des quantités en petites cases : [bois 3] [tissu 2]. Avec `stock`, le nombre passe
## en rouge quand il en manque (et l'infobulle dit combien on en a).
static func cost_row(amounts: Dictionary[StringName, int], stock: Variant = null) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 1)
	# Dans une barre plus haute, les cases gardent leur taille (pas étirées).
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for id: StringName in amounts:
		var data: LootData = loot(id)
		var tip: String = "%d %s" % [amounts[id], loot_name(id).to_lower()]
		var cell := SlotCell.create(data.icon if data else null, str(amounts[id]), tip, false, SlotCell.SMALL)
		if stock is Dictionary:
			var have: int = (stock as Dictionary).get(id, 0)
			cell.tooltip_text = "%s (%d en stock)" % [tip, have]
			if have < amounts[id]:
				cell.set_count_color(BAD)
		box.add_child(cell)
	return box


## Une recette en cases : ce qu'on donne → ce qu'on obtient.
static func recipe_row(cost: Dictionary[StringName, int], output: Dictionary[StringName, int], stock: Variant = null) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 2)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not cost.is_empty():
		box.add_child(cost_row(cost, stock))
		box.add_child(icon(ARROW, 12.0))
	box.add_child(cost_row(output))
	return box


## Le titre et la ligne d'explication de la barre de détail, avec l'icône à gauche.
static func detail_info(box: Container, texture: Texture2D, title: String, text: String = "",
		text_color: Color = MUTED) -> VBoxContainer:
	if texture:
		box.add_child(icon(texture, SlotCell.ICON))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override(&"separation", 0)
	info.add_child(label(title))
	if not text.is_empty():
		var line := label(text, text_color)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(line)
	box.add_child(info)
	return info


## Bouton d'action de la barre de détail (Fabriquer, Construire...). `why` : la raison
## quand il est grisé, en infobulle.
## `sound` : le bruit du bouton à la place du clic (Audio), &"" = le clic habituel.
static func action(text: String, on_press: Callable, disabled: bool = false, why: String = "",
		sound: StringName = &"") -> Button:
	var button := Button.new()
	if sound != &"":
		button.set_meta(&"sound", sound)
	button.text = text
	button.disabled = disabled
	button.tooltip_text = why
	button.custom_minimum_size = Vector2(0.0, 18.0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if on_press.is_valid():
		button.pressed.connect(on_press)
	return button


static func role_color(role: StringName) -> Color:
	return ROLE_COLORS.get(role, Color.WHITE)


static func loot(id: StringName) -> LootData:
	for data: LootData in GameState.LOOT_TYPES:
		if data.id == id:
			return data
	return null


## Les 4 stats d'un équipier : nom et barre en 5 crans (infobulle : ce qu'elle fait).
static func stats_grid(member: CrewMember) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 4)
	grid.add_theme_constant_override(&"v_separation", 1)
	for entry: Array in CrewMember.STATS:
		var value: int = member.stat(entry[0])
		var name_label := label(entry[1], MUTED)
		name_label.tooltip_text = "%s : %s" % [entry[1], entry[2]]
		name_label.mouse_filter = Control.MOUSE_FILTER_STOP
		grid.add_child(name_label)
		var bar := StageBar.new()
		bar.custom_minimum_size = Vector2(40.0, 4.0)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.fill_color = GOLD if value >= 4 else (BAD if value <= 1 else Color(0.8, 0.8, 0.84))
		bar.value = value / 5.0
		bar.marks = [0.2, 0.4, 0.6, 0.8] as Array[float]
		bar.tooltip_text = "%s %d/5 : %s" % [entry[1], value, entry[2]]
		grid.add_child(bar)
	return grid
