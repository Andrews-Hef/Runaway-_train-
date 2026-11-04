class_name SaveStore
extends RefCounted
## Sauvegardes sur disque (user://), en JSON, une par emplacement.
##
## Emplacements utilisés par le jeu (voir Campaign) :
## - CHECKPOINT : point de reprise, pris en arrivant à une gare refuge ;
## - RESUME : reprise de session, pris à chaque trajet (l'appli peut être tuée
##   par le téléphone à tout moment).

const CHECKPOINT: String = "checkpoint"
const RESUME: String = "resume"

## Dossier des sauvegardes (les tests en utilisent un autre).
static var directory: String = "user://saves"


static func path(slot: String) -> String:
	return "%s/%s.json" % [directory, slot]


static func exists(slot: String) -> bool:
	return FileAccess.file_exists(path(slot))


static func write(slot: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(path(slot), FileAccess.WRITE)
	if file == null:
		push_warning("Sauvegarde impossible (%s) : %s" % [path(slot), error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


## La sauvegarde, ou un dictionnaire vide si elle n'existe pas ou est illisible.
static func read(slot: String) -> Dictionary:
	if not exists(slot):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path(slot)))
	return parsed if parsed is Dictionary else {}


static func erase(slot: String) -> void:
	if exists(slot):
		DirAccess.remove_absolute(path(slot))
