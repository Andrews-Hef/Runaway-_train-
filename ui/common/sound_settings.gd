class_name SoundSettings
extends VBoxContainer
## Les deux volumes, Musique et Effets : un curseur chacun (manette et clavier : gauche /
## droite ; souris et doigt : on le fait glisser). Le menu pause et l'écran titre s'en
## servent. Chaque réglage est appliqué tout de suite et gardé (Audio.set_volume).

## [texte, bus audio].
const ROWS: Array[Array] = [["Musique", &"Music"], ["Effets", &"SFX"]]
const STEP: float = 0.05

var sliders: Array[HSlider] = []


static func create() -> SoundSettings:
	var box := SoundSettings.new()
	box._build()
	return box


func _build() -> void:
	add_theme_constant_override(&"separation", 4)
	for line: Array in ROWS:
		var bus: StringName = line[1]
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 6)
		var title := MenuKit.label(line[0], MenuKit.MUTED)
		title.custom_minimum_size = Vector2(46.0, 0.0)
		row.add_child(title)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = STEP
		slider.value = Audio.volume(bus)
		slider.custom_minimum_size = Vector2(96.0, 16.0)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.focus_mode = Control.FOCUS_ALL
		_style(slider)
		row.add_child(slider)
		var percent := MenuKit.label(_percent(slider.value))
		percent.custom_minimum_size = Vector2(26.0, 0.0)
		percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(percent)
		slider.value_changed.connect(func(value: float) -> void:
			Audio.set_volume(bus, value)
			percent.text = _percent(value)
			if bus == &"SFX":
				Audio.play(&"pickup", 0.0)) # on entend tout de suite le nouveau volume
		add_child(row)
		sliders.append(slider)


## Rail sombre, partie remplie dorée (comme les titres des menus).
static func _style(slider: HSlider) -> void:
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color(0.08, 0.08, 0.1)
	rail.content_margin_top = 3.0
	rail.content_margin_bottom = 3.0
	slider.add_theme_stylebox_override(&"slider", rail)
	var filled := StyleBoxFlat.new()
	filled.bg_color = MenuKit.GOLD.darkened(0.25)
	slider.add_theme_stylebox_override(&"grabber_area", filled)
	var lit := StyleBoxFlat.new()
	lit.bg_color = MenuKit.GOLD
	slider.add_theme_stylebox_override(&"grabber_area_highlight", lit)


static func _percent(value: float) -> String:
	return "%d %%" % roundi(value * 100.0)
