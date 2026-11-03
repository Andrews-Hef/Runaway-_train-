extends Node
## Autoload « InputMode » : dernier périphérique utilisé (clavier, manette ou tactile).
##
## Sert à adapter l'interface : afficher ou masquer les contrôles tactiles,
## écrire « E », « A » ou « Agir » dans les consignes.
##
## Forçage du tactile sur PC, pour tester (sans effet dans un build release) :
## - Paramètres du projet > game/debug/force_touch_controls = true
## - ligne de commande : godot --path . -- --touch

enum Device { KEYBOARD, GAMEPAD, TOUCH }

signal changed(device: Device)

const FORCE_TOUCH_ARG: String = "--touch"
const FORCE_TOUCH_SETTING: String = "game/debug/force_touch_controls"

## Nom affiché de chaque action, par périphérique.
const LABELS: Dictionary[StringName, Array] = {
	&"interact": ["E", "A", "Agir"],
	&"attack": ["Espace", "X", "Coup"],
}

var current: Device = Device.KEYBOARD
var forced_touch: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	forced_touch = OS.is_debug_build() and (
		FORCE_TOUCH_ARG in OS.get_cmdline_user_args()
		or ProjectSettings.get_setting(FORCE_TOUCH_SETTING, false)
	)
	if forced_touch:
		Input.emulate_touch_from_mouse = true
	if forced_touch or DisplayServer.is_touchscreen_available():
		current = Device.TOUCH


func _input(event: InputEvent) -> void:
	if forced_touch:
		return
	if event is InputEventScreenTouch:
		set_device(Device.TOUCH)
	elif event is InputEventKey:
		set_device(Device.KEYBOARD)
	elif event is InputEventJoypadButton:
		set_device(Device.GAMEPAD)
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
		set_device(Device.GAMEPAD)


func set_device(device: Device) -> void:
	if device == current:
		return
	current = device
	changed.emit(device)


func is_touch() -> bool:
	return current == Device.TOUCH


## Libellé de l'action pour le périphérique courant, ex. label_for(&"interact") -> "E".
func label_for(action: StringName) -> String:
	var labels: Array = LABELS.get(action, [])
	if labels.size() <= current:
		return String(action)
	return labels[current]
