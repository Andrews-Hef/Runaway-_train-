class_name Interactable
extends Area2D
## Objet avec lequel le joueur interagit en maintenant Agir.
##
## La zone (Area2D) définit la portée d'interaction. Le joueur la détecte
## grâce à son Interactor. Un indicateur au-dessus de l'objet montre qu'il
## est ciblé, puis la progression de l'appui maintenu.

signal interacted(actor: Node2D)

## Texte affiché par le HUD quand l'objet est ciblé.
@export var prompt: String = "Interagir"
## Durée d'appui sur Agir nécessaire, en secondes.
@export var hold_time: float = 0.5
## Position de l'indicateur, relative à l'objet.
@export var indicator_offset: Vector2 = Vector2(0.0, -24.0)

var focused: bool = false
var progress: float = 0.0

var _indicator: Node2D


func _ready() -> void:
	# Imposé par le code : un objet interactif doit être sur la couche INTERACTION.
	collision_layer = PhysicsLayers.INTERACTION
	collision_mask = 0
	monitoring = false
	monitorable = true

	_indicator = Node2D.new()
	_indicator.name = "Indicator"
	_indicator.z_index = 10
	_indicator.position = indicator_offset
	_indicator.draw.connect(_draw_indicator)
	add_child(_indicator)


## Peut-on interagir maintenant ? Les classes filles affinent la règle.
func can_interact() -> bool:
	return true


func interact(actor: Node2D) -> void:
	interacted.emit(actor)


func set_focused(value: bool) -> void:
	focused = value
	_indicator.queue_redraw()


func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	_indicator.queue_redraw()


func _draw_indicator() -> void:
	if progress > 0.0:
		_indicator.draw_circle(Vector2.ZERO, 6.0, Color(0.0, 0.0, 0.0, 0.5))
		_indicator.draw_arc(Vector2.ZERO, 5.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 24, Color.WHITE, 2.0)
	elif focused:
		var points := PackedVector2Array([Vector2(-3.0, -3.0), Vector2(3.0, -3.0), Vector2(0.0, 1.0)])
		_indicator.draw_colored_polygon(points, Color(1.0, 1.0, 1.0, 0.9))
