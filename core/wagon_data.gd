class_name WagonData
extends Resource
## Un type de voiture du train : cabine, atelier, stock, dortoir...
##
## Un type = un fichier .tres dans data/wagons/. Les meubles de chaque type sont
## placés par la scène de l'intérieur du train (levels/train_interior/), d'après `id`.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Un seul exemplaire possible dans le train (cabine, atelier).
@export var unique: bool = false

@export_group("Effets")
## Couchettes : nombre d'équipiers que la voiture peut loger.
@export var beds: int = 0
## Places dans le stock du train (nombre de ressources).
@export var storage: int = 0

@export_group("Construction")
## Matériaux à prendre dans le stock. Vide = ne se construit pas (fourni au départ).
@export var cost: Dictionary[StringName, int] = {}


func is_buildable() -> bool:
	return not cost.is_empty()


## Effets lisibles, pour l'interface : « +4 couchettes », « +60 places de stock ».
func describe_effects() -> String:
	var parts: PackedStringArray = []
	if beds > 0:
		parts.append("+%d couchettes" % beds)
	if storage > 0:
		parts.append("+%d places de stock" % storage)
	return ", ".join(parts) if not parts.is_empty() else description
