class_name Projectile
extends Node2D
## Projectile d'un tireur : balle de fusil (pilleur) ou crachat de bile (infecté).
##
## Il file tout droit, s'arrête sur le décor (épaves, train...) et prévient quand
## il touche sa cible (hit). C'est la zone qui applique les effets.

signal hit(projectile: Projectile)

const HIT_RADIUS: float = 7.0
const MAX_DISTANCE: float = 260.0
## Hauteur visée sur la cible (le buste, pas les pieds).
const TARGET_HEIGHT: float = 8.0

## Le tireur : ses dégâts et son exposition s'appliquent au joueur.
var source: EnemyData
var target: Node2D
var direction: Vector2 = Vector2.RIGHT
var speed: float = 200.0
var color: Color = Color.WHITE

var _travelled: float = 0.0


func _ready() -> void:
	z_index = 6


func _physics_process(delta: float) -> void:
	var from: Vector2 = global_position
	var to: Vector2 = from + direction * speed * delta
	if _blocked(from, to):
		queue_free()
		return
	global_position = to
	_travelled += speed * delta
	if is_instance_valid(target) and segment_hits(from, to, target.global_position - Vector2(0.0, TARGET_HEIGHT), HIT_RADIUS):
		hit.emit(self)
		queue_free()
	elif _travelled > MAX_DISTANCE:
		queue_free()
	queue_redraw()


func _draw() -> void:
	draw_line(-direction * 5.0, Vector2.ZERO, Color(color, 0.5), 2.0)
	draw_circle(Vector2.ZERO, 1.6, color)


## Le décor (corps statiques) arrête le projectile ; les personnages non.
func _blocked(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, PhysicsLayers.WORLD)
	var result: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and result["collider"] is StaticBody2D


## Le segment from -> to passe-t-il à moins de `radius` du point ?
static func segment_hits(from: Vector2, to: Vector2, point: Vector2, radius: float) -> bool:
	return Geometry2D.get_closest_point_to_segment(point, from, to).distance_to(point) <= radius
