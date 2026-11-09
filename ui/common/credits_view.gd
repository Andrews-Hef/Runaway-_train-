class_name CreditsView
extends ScrollContainer
## Les crédits : le jeu, la musique, les bruitages, la police, les images. Chaque œuvre est
## une ligne-bouton : à la manette ou au clavier on descend ligne par ligne (la liste suit),
## et un clic ouvre sa page. Le menu pause et l'écran titre s'en servent.
##
## Musique et bruitages viennent d'AudioCatalog (écrit par tools/build_audio.py) : la liste
## reste juste quand on change un son.

## [œuvre, auteur, licence, lien]
const OTHER_CREDITS: Array[Array] = [
	["Police Barlow", "Jeremy Tribby", "SIL OFL 1.1", "https://github.com/jpt/barlow"],
	["Sprites provisoires", "générés avec td2d", "", "https://github.com/brphillis/threedee-twodee"],
]
const LINE_FONT_SIZE: int = 9

## Les lignes cliquables, dans l'ordre (la première prend le focus à l'ouverture).
var lines: Array[Button] = []


static func create(height: float = 120.0) -> CreditsView:
	var view := CreditsView.new()
	view._build(height)
	return view


func _build(height: float) -> void:
	custom_minimum_size = Vector2(280.0, height)
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	follow_focus = true
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override(&"separation", 1)
	add_child(box)
	box.add_child(MenuKit.label("Un jeu d'Andrews-Hef", MenuKit.GOLD))
	_section(box, "Musique", AudioCatalog.MUSIC_CREDITS)
	_section(box, "Bruitages", AudioCatalog.SFX_CREDITS)
	_section(box, "Police et images", OTHER_CREDITS)
	var note := MenuKit.label("CC0 : domaine public, aucun crédit exigé (merci quand même !). Détail : assets/audio/CREDITS.md",
		MenuKit.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override(&"font_size", LINE_FONT_SIZE)
	box.add_child(note)


func _section(box: VBoxContainer, title: String, entries: Array[Array]) -> void:
	box.add_child(MenuKit.section(title))
	for entry: Array in entries:
		box.add_child(_line(entry))


static func line_text(entry: Array) -> String:
	var text: String = "%s — %s" % [entry[0], entry[1]]
	return text + (" (%s)" % entry[2] if not (entry[2] as String).is_empty() else "")


func _line(entry: Array) -> Button:
	var button := Button.new()
	button.flat = true
	button.text = line_text(entry)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override(&"font_size", LINE_FONT_SIZE)
	button.tooltip_text = entry[3]
	button.pressed.connect(OS.shell_open.bind(entry[3]))
	lines.append(button)
	return button
