extends SceneTree
## Construit ui/theme/game_theme.tres à partir du kit d'interface (assets/ui/frames/,
## dessiné par tools/gen_ui.py). Toutes les interfaces du jeu utilisent ce thème.
##
## Usage, depuis la racine du repo (après python tools/gen_ui.py et un import) :
##     godot --headless --path . --script tools/build_theme.gd
##
## Variantes (theme_type_variation) à poser sur un nœud :
## - PanelContainer : HudPanel (HUD, transparent), PaperPanel (télégramme du capitaine),
##   AlertPanel (sifflet), SlotPanel (case d'équipement), InsetPanel (fond creusé)
## - Label : BannerLabel (bandeau d'alerte)

const OUT: String = "res://ui/theme/game_theme.tres"
const FRAMES: String = "res://assets/ui/frames/%s.png"
const FONT: String = "res://assets/fonts/barlow/Barlow-SemiBold.ttf"

const TEXT: Color = Color(0.93, 0.91, 0.86)
const TEXT_MUTED: Color = Color(0.62, 0.62, 0.66)
const TEXT_HOVER: Color = Color(1.0, 0.9, 0.62)
const INK: Color = Color(0.17, 0.12, 0.08)


func _initialize() -> void:
	var theme := Theme.new()
	theme.default_font = load(FONT)
	theme.default_font_size = 8

	theme.set_color(&"font_color", &"Label", TEXT)

	# Panneaux : la grande plaque par défaut (menus), des variantes pour le reste.
	var plate := frame("plate", 6, Vector4(8, 7, 8, 7))
	theme.set_stylebox(&"panel", &"PanelContainer", plate)
	theme.set_stylebox(&"panel", &"Panel", plate)
	variation(theme, &"HudPanel", &"PanelContainer", frame("hud_plate", 3, Vector4(4, 3, 4, 3)))
	variation(theme, &"PaperPanel", &"PanelContainer", frame("paper", 6, Vector4(8, 4, 8, 5)))
	variation(theme, &"AlertPanel", &"PanelContainer", frame("alert", 3, Vector4(6, 2, 6, 3)))
	variation(theme, &"SlotPanel", &"PanelContainer", frame("slot", 2, Vector4(1, 1, 1, 1)))
	variation(theme, &"InsetPanel", &"PanelContainer", frame("inset", 2, Vector4(4, 3, 4, 3)))
	theme.set_type_variation(&"BannerLabel", &"Label")
	theme.set_stylebox(&"normal", &"BannerLabel", frame("alert", 3, Vector4(8, 2, 8, 3)))

	# Boutons : plaque en relief, laiton au survol, enfoncée au clic.
	theme.set_stylebox(&"normal", &"Button", frame("button_normal", 4, Vector4(6, 2, 6, 3)))
	theme.set_stylebox(&"hover", &"Button", frame("button_hover", 4, Vector4(6, 2, 6, 3)))
	theme.set_stylebox(&"pressed", &"Button", frame("button_pressed", 4, Vector4(6, 3, 6, 2)))
	theme.set_stylebox(&"hover_pressed", &"Button", frame("button_pressed", 4, Vector4(6, 3, 6, 2)))
	theme.set_stylebox(&"disabled", &"Button", frame("button_disabled", 4, Vector4(6, 2, 6, 3)))
	theme.set_stylebox(&"focus", &"Button", frame("focus", 4, Vector4(6, 2, 6, 3)))
	theme.set_color(&"font_color", &"Button", TEXT)
	theme.set_color(&"font_focus_color", &"Button", TEXT)
	theme.set_color(&"font_hover_color", &"Button", TEXT_HOVER)
	theme.set_color(&"font_pressed_color", &"Button", TEXT_HOVER)
	theme.set_color(&"font_hover_pressed_color", &"Button", TEXT_HOVER)
	theme.set_color(&"font_disabled_color", &"Button", TEXT_MUTED)

	# Onglets : collés au contenu creusé ; l'onglet ouvert a un filet laiton.
	for type: StringName in [&"TabContainer", &"TabBar"]:
		theme.set_stylebox(&"tab_selected", type, frame("tab_selected", 4, Vector4(7, 4, 7, 2)))
		theme.set_stylebox(&"tab_unselected", type, frame("tab_unselected", 4, Vector4(7, 4, 7, 2)))
		theme.set_stylebox(&"tab_hovered", type, frame("tab_hovered", 4, Vector4(7, 4, 7, 2)))
		theme.set_stylebox(&"tab_disabled", type, frame("tab_unselected", 4, Vector4(7, 4, 7, 2)))
		theme.set_stylebox(&"tab_focus", type, frame("focus", 4, Vector4(7, 4, 7, 2)))
		theme.set_color(&"font_selected_color", type, TEXT_HOVER)
		theme.set_color(&"font_unselected_color", type, TEXT_MUTED)
		theme.set_color(&"font_hovered_color", type, TEXT)
		theme.set_color(&"font_disabled_color", type, TEXT_MUTED)
	theme.set_stylebox(&"panel", &"TabContainer", frame("inset", 2, Vector4(5, 4, 5, 4)))

	# Jauges et barres de défilement.
	theme.set_stylebox(&"background", &"ProgressBar", frame("track", 2, Vector4(1, 1, 1, 1)))
	var gold := StyleBoxFlat.new()
	gold.bg_color = Color(0.85, 0.68, 0.3)
	theme.set_stylebox(&"fill", &"ProgressBar", gold)
	for type: StringName in [&"VScrollBar", &"HScrollBar"]:
		theme.set_stylebox(&"scroll", type, frame("track", 2, Vector4(2, 2, 2, 2)))
		theme.set_stylebox(&"scroll_focus", type, frame("track", 2, Vector4(2, 2, 2, 2)))
		theme.set_stylebox(&"grabber", type, frame("grabber", 2, Vector4(2, 2, 2, 2)))
		theme.set_stylebox(&"grabber_highlight", type, frame("grabber_hover", 2, Vector4(2, 2, 2, 2)))
		theme.set_stylebox(&"grabber_pressed", type, frame("grabber_hover", 2, Vector4(2, 2, 2, 2)))

	# Info-bulles (PC, au survol des icônes).
	theme.set_stylebox(&"panel", &"TooltipPanel", frame("hud_plate", 3, Vector4(4, 2, 4, 3)))
	theme.set_color(&"font_color", &"TooltipLabel", TEXT)

	var error: Error = ResourceSaver.save(theme, OUT)
	print("thème écrit : ", OUT, " (", error_string(error), ")")
	quit(0 if error == OK else 1)


## Texture découpée en 9 : `margin` pixels de bord non étirés, `content` = marges intérieures
## (gauche, haut, droite, bas).
static func frame(name: String, margin: int, content: Vector4) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(FRAMES % name)
	style.texture_margin_left = margin
	style.texture_margin_top = margin
	style.texture_margin_right = margin
	style.texture_margin_bottom = margin
	style.content_margin_left = content.x
	style.content_margin_top = content.y
	style.content_margin_right = content.z
	style.content_margin_bottom = content.w
	return style


static func variation(theme: Theme, name: StringName, base: StringName, style: StyleBox) -> void:
	theme.set_type_variation(name, base)
	theme.set_stylebox(&"panel", name, style)
