extends CanvasLayer
## Couche des contrôles tactiles (joystick + boutons).
##
## Visible sur les appareils tactiles, masquée sur PC.
## Le jeu suit le dernier périphérique utilisé : toucher l'écran affiche
## les contrôles, utiliser un clavier ou une manette les masque
## (pratique pour un téléphone avec une manette Bluetooth).
##
## Pour tester sur PC (la souris simule alors le doigt), au choix :
## - Paramètres du projet > game/debug/force_touch_controls = true
## - ligne de commande : godot --path . -- --touch
## Le forçage n'a aucun effet dans un build release.

const FORCE_TOUCH_ARG: String = "--touch"
const FORCE_TOUCH_SETTING: String = "game/debug/force_touch_controls"

var _forced: bool = false

@onready var _root: Control = $Root


func _ready() -> void:
	_forced = OS.is_debug_build() and (
		FORCE_TOUCH_ARG in OS.get_cmdline_user_args()
		or ProjectSettings.get_setting(FORCE_TOUCH_SETTING, false)
	)
	if _forced:
		Input.emulate_touch_from_mouse = true
	_root.visible = _forced or DisplayServer.is_touchscreen_available()


func _input(event: InputEvent) -> void:
	if _forced:
		return
	if event is InputEventScreenTouch:
		_root.visible = true
	elif event is InputEventKey or event is InputEventJoypadButton:
		_root.visible = false
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
		_root.visible = false
