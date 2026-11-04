class_name Harvestable
extends Interactable
## Objet récoltable : épave, arbre mort, plante...
##
## Une fois récolté, il est épuisé : il disparaît (plantes) ou reste en place
## grisé (épaves, arbres qui servent aussi d'obstacles).

signal harvested(loot: LootData, amount: int, exposure: float)

@export var loot: LootData
## Si non vide, chaque récolte tire une ressource au hasard ici (caisses, cachettes).
@export var loot_pool: Array[LootData] = []
@export var amount_min: int = 1
@export var amount_max: int = 2
## Exposition ajoutée au joueur à la récolte (ressources infectées).
@export var exposure_on_harvest: float = 0.0
## true : l'objet disparaît une fois récolté. false : il reste, grisé.
@export var remove_when_depleted: bool = true

var depleted: bool = false


func can_interact() -> bool:
	return not depleted and (loot != null or not loot_pool.is_empty())


func interact(actor: Node2D) -> void:
	if not can_interact():
		return
	depleted = true
	set_focused(false)
	set_progress(0.0)
	var found: LootData = loot
	if not loot_pool.is_empty():
		found = loot_pool.pick_random()
	harvested.emit(found, randi_range(amount_min, amount_max), exposure_on_harvest)
	super(actor)
	_play_depleted()


func _play_depleted() -> void:
	set_deferred(&"monitorable", false)
	var tween := create_tween()
	if remove_when_depleted:
		tween.tween_property(self, "scale", Vector2(1.2, 0.0), 0.15)
		tween.tween_callback(queue_free)
	else:
		tween.tween_property(self, "modulate", Color(0.55, 0.55, 0.6), 0.2)
