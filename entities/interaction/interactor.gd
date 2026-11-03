class_name Interactor
extends Area2D
## Portée d'interaction du joueur.
##
## Cible l'objet interactif le plus proche et gère l'appui maintenu sur Agir.
## Marche avec le clavier, la manette et le bouton tactile, car tous
## passent par l'action « interact ».

signal target_changed(target: Interactable)
signal interaction_completed(target: Interactable)

## Celui qui interagit (le joueur). Par défaut : le nœud parent.
var actor: Node2D
var target: Interactable = null

var _candidates: Array[Interactable] = []
var _hold: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.INTERACTION
	monitoring = true
	monitorable = false
	if actor == null:
		actor = get_parent() as Node2D
	area_entered.connect(add_candidate)
	area_exited.connect(remove_candidate)


func add_candidate(area: Area2D) -> void:
	var interactable := area as Interactable
	if interactable and not _candidates.has(interactable):
		_candidates.append(interactable)


func remove_candidate(area: Area2D) -> void:
	_candidates.erase(area as Interactable)


func _physics_process(delta: float) -> void:
	_refresh_target()
	if target == null:
		_hold = 0.0
		return

	if Input.is_action_pressed(&"interact"):
		_hold += delta
		target.set_progress(_hold / maxf(target.hold_time, 0.01))
		if _hold >= target.hold_time:
			var done: Interactable = target
			_hold = 0.0
			done.set_progress(0.0)
			done.interact(actor)
			interaction_completed.emit(done)
	elif _hold > 0.0:
		_hold = 0.0
		target.set_progress(0.0)


func _refresh_target() -> void:
	var best: Interactable = null
	var best_distance: float = INF
	for candidate: Interactable in _candidates.duplicate():
		if not is_instance_valid(candidate):
			_candidates.erase(candidate)
			continue
		if not candidate.can_interact():
			continue
		var distance: float = global_position.distance_squared_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate

	if best == target:
		return
	if is_instance_valid(target):
		target.set_focused(false)
		target.set_progress(0.0)
	target = best
	_hold = 0.0
	if target:
		target.set_focused(true)
	target_changed.emit(target)
