class_name SlotCell
extends PanelContainer
## Une case façon inventaire : cadre creusé, icône pixel art, nombre en bas à droite,
## liseré doré quand elle est choisie.
##
## Partagée par l'inventaire, le menu du train et les gares : un objet = une case, et
## c'est la barre de détail du menu qui l'explique. Peu de texte à l'écran, le reste au
## toucher (ou au survol : infobulle).

## La case a été touchée : clic, doigt, Entrée.
signal chosen
## Le focus (manette, clavier) s'est posé dessus : un menu peut y faire suivre son détail.
signal focused

const SIZE: Vector2 = Vector2(28.0, 28.0)
## Icônes 12 px affichées ×2 : nettes à toutes les échelles entières.
const ICON: float = 24.0
## Petite case des coûts (« 3 bois ») : l'icône à sa taille réelle.
const SMALL: Vector2 = Vector2(16.0, 16.0)
const SMALL_ICON: float = 12.0
## Marque de coin (coche, cadenas) : 12 px, posée en haut à droite.
const CORNER: float = 12.0

## Ce que la case représente (une ressource, une recette, une voiture...) : le menu la
## retrouve par là pour la surligner ou lui rendre le focus.
var key: Variant
var button: Button
var _picture: TextureRect
var _count: Label
var _selected: bool = false


## `count` : texte du coin bas-droit (« 12 », « 2/3 »), vide = rien. `interactive` faux :
## case inerte (coûts, cases vides), elle ne prend ni le focus ni les clics.
static func create(texture: Texture2D, count: String = "", tip: String = "", interactive: bool = true,
		cell_size: Vector2 = SIZE) -> SlotCell:
	var cell := SlotCell.new()
	cell._build(texture, count, tip, interactive, cell_size)
	return cell


func _build(texture: Texture2D, count: String, tip: String, interactive: bool, cell_size: Vector2) -> void:
	theme_type_variation = &"SlotPanel"
	button = Button.new()
	button.flat = true
	button.custom_minimum_size = cell_size
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_ALL if interactive else Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	if interactive:
		button.pressed.connect(chosen.emit)
		button.focus_entered.connect(focused.emit)
	else:
		# Une case inerte laisse passer le survol jusqu'au conteneur (infobulle du coût).
		mouse_filter = Control.MOUSE_FILTER_PASS
		tooltip_text = tip
	add_child(button)
	var small: bool = cell_size.x < SIZE.x
	if texture:
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_picture = MenuKit.icon(texture, SMALL_ICON if small else ICON)
		_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(_picture)
		button.add_child(center)
	if not count.is_empty():
		_count = Label.new()
		_count.text = count
		_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_count.offset_right = 0.0 if small else -1.0
		_count.offset_bottom = 3.0 if small else 1.0
		_count.add_theme_font_override(&"font", BagHotbar.NUMBERS_FONT)
		_count.add_theme_font_size_override(&"font_size", 8 if small else 9)
		_count.add_theme_color_override(&"font_shadow_color", Color(0.06, 0.05, 0.06))
		_count.add_theme_constant_override(&"shadow_offset_x", 1)
		_count.add_theme_constant_override(&"shadow_offset_y", 1)
		_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(_count)


## Liseré doré : la case dont la barre de détail parle.
func set_selected(on: bool) -> void:
	if on == _selected:
		return
	_selected = on
	if on:
		var gold := StyleBoxFlat.new()
		gold.bg_color = Color(0.18, 0.15, 0.1, 0.9)
		gold.set_border_width_all(1)
		gold.border_color = MenuKit.GOLD
		add_theme_stylebox_override(&"panel", gold)
	else:
		remove_theme_stylebox_override(&"panel")


func is_selected() -> bool:
	return _selected


## Icône à demi effacée : il n'y en a pas, ou on ne peut pas encore la faire.
func set_dim(on: bool) -> SlotCell:
	if _picture:
		_picture.modulate = Color(1.0, 1.0, 1.0, 0.38) if on else Color.WHITE
	return self


func set_count_color(color: Color) -> SlotCell:
	if _count:
		_count.add_theme_color_override(&"font_color", color)
	return self


## Petite marque en haut à droite : coche (possédé, étudié), cadenas (inconnu)...
func set_corner(texture: Texture2D) -> SlotCell:
	var mark := TextureRect.new()
	mark.texture = texture
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	mark.anchor_left = 1.0
	mark.anchor_right = 1.0
	mark.offset_left = -CORNER + 1.0
	mark.offset_right = 1.0
	mark.offset_top = -2.0
	mark.offset_bottom = CORNER - 2.0
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(mark)
	return self


## Teinte de l'icône (portraits d'équipiers colorés selon le rôle).
func set_tint(color: Color) -> SlotCell:
	if _picture:
		_picture.self_modulate = color
	return self
