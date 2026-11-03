extends CanvasLayer
## Couche des contrôles tactiles (joystick + boutons).
##
## Visible seulement quand le dernier périphérique utilisé est le tactile
## (voir l'autoload InputMode) : toucher l'écran les affiche, utiliser
## un clavier ou une manette les masque.

@onready var _root: Control = $Root


func _ready() -> void:
	InputMode.changed.connect(_on_input_mode_changed)
	_on_input_mode_changed(InputMode.current)


func _on_input_mode_changed(_device: int) -> void:
	_root.visible = InputMode.is_touch()
