class_name TouchActionButton
extends Control
## Bouton tactile qui déclenche une action de l'InputMap.
##
## Il envoie un vrai InputEventAction : le jeu reçoit le même évènement
## que si le joueur avait appuyé sur la touche clavier ou le bouton manette.
## Gère le multi-touch : on peut marcher avec le joystick et appuyer en même temps.

## Action de l'InputMap déclenchée par ce bouton.
@export var action: StringName = &"attack"
## Texte affiché au centre (temporaire, en attendant des icônes).
@export var text: String = "A"
## Rayon du bouton, en pixels de jeu.
@export var radius: float = 20.0
@export var idle_color: Color = Color(1.0, 1.0, 1.0, 0.18)
@export var pressed_color: Color = Color(1.0, 1.0, 1.0, 0.45)

var _touch_index: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2.ONE * radius * 2.0
	resized.connect(queue_redraw)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", 10)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(label)


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventScreenTouch:
		return
	var touch := event as InputEventScreenTouch
	if touch.pressed and _touch_index == -1:
		_touch_index = touch.index
		_send(true)
		accept_event()
	elif not touch.pressed and touch.index == _touch_index:
		_touch_index = -1
		_send(false)
		accept_event()


func _notification(what: int) -> void:
	if (what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_VISIBILITY_CHANGED) and _touch_index != -1:
		_touch_index = -1
		_send(false)


func is_held() -> bool:
	return _touch_index != -1


func _send(pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
	queue_redraw()


func _draw() -> void:
	draw_circle(size / 2.0, radius, pressed_color if is_held() else idle_color)
