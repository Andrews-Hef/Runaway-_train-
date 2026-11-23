class_name RouteProgress
extends HBoxContainer
## Barre de progression jusqu'à la prochaine gare refuge : une case par arrêt de la
## région (faits en or, celui en cours en blanc, à venir en sombre), la gare au bout,
## et une phrase « Gare refuge de X : encore N arrêts ».
##
## `heading` : vrai quand on roule vers l'arrêt n°stop_number (trajet, intérieur du train),
## faux quand on y est (zone). `compact` : sans la phrase (elle passe en infobulle).

const STATION: Texture2D = preload("res://assets/ui/icons/station.png")
const PIP: int = 6
const PIP_CURRENT: int = 8
const GAP: int = 4
const DONE_COLOR: Color = Color("e0b84a")
const TODO_COLOR: Color = Color("2b2b33")
const TODO_EDGE: Color = Color("6b6b78")
const LINE_DONE: Color = Color("9a7426")

var heading: bool = true
var compact: bool = false
var _track: Control
var _label: Label


static func create(heading_to_stop: bool, compact_view: bool = false) -> RouteProgress:
	var progress := RouteProgress.new()
	progress.heading = heading_to_stop
	progress.compact = compact_view
	return progress


func _ready() -> void:
	name = "RouteProgress"
	add_theme_constant_override(&"separation", 4)
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_PASS
	_track = Control.new()
	_track.name = "Track"
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_track.draw.connect(_draw_track)
	add_child(_track)
	_label = MenuKit.label("", MenuKit.GOLD)
	_label.name = "Text"
	_label.visible = not compact
	add_child(_label)
	refresh()


## Relit GameState (numéro d'arrêt, gare à venir).
func refresh() -> void:
	if _track == null:
		return
	var stops: int = GameState.REFUGE_EVERY - 1
	_track.custom_minimum_size = Vector2(stops * (PIP + GAP) + (PIP_CURRENT - PIP) + STATION.get_width() + 1, 12)
	_label.text = text_for(heading)
	tooltip_text = _label.text
	_track.queue_redraw()


## La phrase : « Gare refuge de X : encore 2 arrêts », « … : prochain arrêt ! », « Tu es en gare ».
static func text_for(heading_to_stop: bool) -> String:
	var refuge: RefugeData = GameState.next_refuge()
	if not heading_to_stop and GameState.is_refuge_stop():
		return "Tu es en gare : %s" % refuge.display_name
	var left: int = GameState.stops_before_refuge(heading_to_stop)
	if left == 0:
		return "%s : prochain arrêt !" % refuge.display_name
	return "%s : encore %d arrêt%s" % [refuge.display_name, left, "s" if left > 1 else ""]


## État d'une case : -1 faite, 0 celle en cours, 1 à venir.
static func pip_state(stop: int) -> int:
	return signi(stop - GameState.stop_number)


func _draw_track() -> void:
	var first: int = GameState.region_stops().x
	var stops: int = GameState.REFUGE_EVERY - 1
	var middle: float = _track.size.y / 2.0
	var x: float = 0.0
	for i: int in stops + 1:
		var stop: int = first + i
		var state: int = pip_state(stop)
		var is_station: bool = i == stops
		var width: float = STATION.get_width() if is_station else (PIP_CURRENT if state == 0 else PIP)
		if i > 0:
			# Le trait qui relie à la case précédente : doré quand on l'a parcouru.
			_track.draw_rect(Rect2(x - GAP, middle - 1.0, GAP, 2.0), LINE_DONE if state <= 0 else TODO_EDGE)
		if is_station:
			var faded: Color = Color(1, 1, 1, 1.0 if state <= 0 else 0.85)
			_track.draw_texture(STATION, Vector2(x, middle - STATION.get_height() / 2.0), faded)
		else:
			var rect := Rect2(x, middle - width / 2.0, width, width)
			match state:
				-1:
					_track.draw_rect(rect, DONE_COLOR)
				0:
					_track.draw_rect(rect, Color.WHITE)
					_track.draw_rect(rect.grow(1.0), DONE_COLOR, false, 1.0)
				_:
					_track.draw_rect(rect, TODO_COLOR)
					_track.draw_rect(rect, TODO_EDGE, false, 1.0)
		x += width + GAP
