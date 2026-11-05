class_name SegmentBar
extends Control
## Jauge en segments : un segment par point (la vie : un segment = 1 PV).
## Dessinée en pixels nets ; si les segments deviennent trop fins, une barre continue.

const OUTLINE: Color = Color(0.08, 0.06, 0.07, 0.95)
const EMPTY: Color = Color(0.1, 0.1, 0.12, 0.85)

@export var max_value: float = 10.0:
	set(new_max):
		max_value = maxf(new_max, 1.0)
		queue_redraw()
@export var value: float = 10.0:
	set(new_value):
		value = new_value
		queue_redraw()
@export var fill_color: Color = Color(0.86, 0.27, 0.24)
## Écart entre deux segments, en pixels.
@export var gap: int = 1


func _draw() -> void:
	var count: int = int(max_value)
	var height: float = size.y
	var width: float = floorf((size.x - gap * (count - 1)) / count)
	if width < 3.0:
		_draw_continuous()
		return
	for i: int in count:
		var x: float = i * (width + gap)
		draw_rect(Rect2(x, 0.0, width, height), OUTLINE)
		var inner := Rect2(x + 1.0, 1.0, width - 2.0, height - 2.0)
		if i < int(value):
			draw_rect(inner, fill_color)
			draw_rect(Rect2(inner.position, Vector2(inner.size.x, 1.0)), fill_color.lightened(0.35))
		else:
			draw_rect(inner, EMPTY)


func _draw_continuous() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), OUTLINE)
	var inner := Rect2(1.0, 1.0, size.x - 2.0, size.y - 2.0)
	draw_rect(inner, EMPTY)
	var filled := Rect2(inner.position, Vector2(floorf(inner.size.x * clampf(value / max_value, 0.0, 1.0)), inner.size.y))
	draw_rect(filled, fill_color)
	draw_rect(Rect2(filled.position, Vector2(filled.size.x, 1.0)), fill_color.lightened(0.35))
