extends Node2D
## Roues du train vues de côté, dessinées en code, qui tournent en continu.
## Les manetons laiton rendent la rotation lisible.

@export var wheel_x: PackedFloat32Array = PackedFloat32Array()
@export var radius: float = 11.0
## Tours par seconde.
@export var turns_per_second: float = 1.6

var _angle: float = 0.0


func _process(delta: float) -> void:
	_angle = fposmod(_angle + TAU * turns_per_second * delta, TAU)
	queue_redraw()


func _draw() -> void:
	for x: float in wheel_x:
		var center := Vector2(x, 0.0)
		draw_circle(center, radius + 1.0, Color(0.1, 0.1, 0.12))
		draw_circle(center, radius, Color(0.29, 0.3, 0.34))
		for i: int in 3:
			var a: float = _angle + i * TAU / 3.0
			draw_line(center, center + Vector2.from_angle(a) * (radius - 1.0), Color(0.17, 0.17, 0.2), 2.0)
		draw_circle(center, 2.5, Color(0.17, 0.17, 0.2))
		draw_rect(Rect2(center + Vector2.from_angle(_angle) * (radius * 0.65) - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), Color(0.72, 0.57, 0.23))
