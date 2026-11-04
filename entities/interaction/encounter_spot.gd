class_name EncounterSpot
extends Interactable
## Point de rencontre : un PNJ, un sac abandonné, une armoire...
##
## Maintenir Agir ouvre la rencontre. La zone gère le dialogue et les choix ;
## ce nœud sait seulement s'il est encore disponible.

signal encounter_requested(spot: EncounterSpot)

@export var encounter: EncounterData:
	set(value):
		encounter = value
		if encounter:
			prompt = encounter.prompt
## Le PNJ s'en va (fondu) quand il est recruté.
@export var leaves_when_recruited: bool = true

## true : la rencontre est terminée, on ne peut plus interagir.
var resolved: bool = false


func can_interact() -> bool:
	return not resolved and encounter != null


func interact(actor: Node2D) -> void:
	if not can_interact():
		return
	super(actor)
	encounter_requested.emit(self)


## La rencontre est finie. `recruited` : le PNJ part rejoindre le train.
func mark_resolved(recruited: bool) -> void:
	resolved = true
	set_focused(false)
	set_deferred(&"monitorable", false)
	var tween := create_tween()
	if recruited and leaves_when_recruited:
		tween.tween_property(self, "modulate:a", 0.0, 0.6)
		tween.tween_callback(queue_free)
	else:
		tween.tween_property(self, "modulate", Color(0.6, 0.6, 0.65), 0.3)
