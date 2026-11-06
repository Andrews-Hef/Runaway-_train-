class_name DroppedPile
extends Interactable
## Ce que le joueur a jeté de son sac pendant un arrêt : un tas au sol.
##
## On le ramasse en maintenant Agir, comme une récolte : la zone remet dans le sac
## ce qui rentre (take), le reste reste dans le tas. Vide, il disparaît.

## Le joueur a fini d'appuyer : la zone décide de ce qui revient dans le sac.
signal pick_requested(pile: DroppedPile)

const GROUP: StringName = &"dropped_pile"
## Jeter près d'un tas existant le complète au lieu d'en poser un autre.
const MERGE_RADIUS: float = 24.0

var contents: Dictionary[StringName, int] = {}


func _ready() -> void:
	super()
	add_to_group(GROUP)
	_refresh_prompt()


func add(id: StringName, amount: int) -> void:
	if amount <= 0:
		return
	contents[id] = contents.get(id, 0) + amount
	_refresh_prompt()


## Reprend jusqu'à `amount` d'une ressource. Renvoie ce qui a été pris.
func take(id: StringName, amount: int) -> int:
	var taken: int = mini(amount, contents.get(id, 0))
	if taken <= 0:
		return 0
	if taken == contents[id]:
		contents.erase(id)
	else:
		contents[id] -= taken
	_refresh_prompt()
	if contents.is_empty():
		_vanish()
	return taken


func total() -> int:
	var sum: int = 0
	for id: StringName in contents:
		sum += contents[id]
	return sum


func can_interact() -> bool:
	return not contents.is_empty()


func interact(actor: Node2D) -> void:
	if not can_interact():
		return
	set_progress(0.0)
	pick_requested.emit(self)
	super(actor)


## Le tas le plus proche de `at` dans le rayon de fusion, ou null.
static func nearest(tree: SceneTree, at: Vector2) -> DroppedPile:
	var best: DroppedPile = null
	var best_distance: float = MERGE_RADIUS
	for node: Node in tree.get_nodes_in_group(GROUP):
		var pile := node as DroppedPile
		if pile == null or pile.is_queued_for_deletion() or pile.contents.is_empty():
			continue
		var distance: float = pile.global_position.distance_to(at)
		if distance <= best_distance:
			best = pile
			best_distance = distance
	return best


func _refresh_prompt() -> void:
	prompt = "Ramasser (%s)" % MenuKit.describe_amounts(contents) if not contents.is_empty() else "Ramasser"


func _vanish() -> void:
	set_focused(false)
	set_deferred(&"monitorable", false)
	remove_from_group(GROUP)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 0.0), 0.15)
	tween.tween_callback(queue_free)
