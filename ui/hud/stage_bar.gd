class_name StageBar
extends Control
## Jauge continue (0 à 1) avec des repères : les paliers d'infection (Fièvre,
## Contaminé, Critique) se voient avant d'être atteints. Sans repères : simple jauge
## (remplissage du sac).

const OUTLINE: Color = Color(0.08, 0.06, 0.07, 0.95)
const EMPTY: Color = Color(0.1, 0.1, 0.12, 0.85)
const MARK_AHEAD: Color = Color(0.55, 0.55, 0.6, 0.9)
const MARK_PASSED: Color = Color(1.0, 0.92, 0.7, 0.95)

@export_range(0.0, 1.0) var value: float = 0.0:
	set(new_value):
		value = clampf(new_value, 0.0, 1.0)
		queue_redraw()
@export var fill_color: Color = Color(0.75, 0.42, 1.0):
	set(new_color):
		fill_color = new_color
		queue_redraw()
## Repères, entre 0 et 1.
@export var marks: Array[float] = []:
	set(new_marks):
		marks = new_marks
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), OUTLINE)
	var inner := Rect2(1.0, 1.0, size.x - 2.0, size.y - 2.0)
	draw_rect(inner, EMPTY)
	var filled := Rect2(inner.position, Vector2(floorf(inner.size.x * value), inner.size.y))
	if filled.size.x > 0.0:
		draw_rect(filled, fill_color)
		draw_rect(Rect2(filled.position, Vector2(filled.size.x, 1.0)), fill_color.lightened(0.35))
	for mark: float in marks:
		var x: float = inner.position.x + floorf(inner.size.x * mark)
		draw_rect(Rect2(x, 0.0, 1.0, size.y), MARK_PASSED if value >= mark else MARK_AHEAD)
