class_name WagonUpgrade
extends Resource
## Un niveau d'agrandissement d'un type de voiture (niv. 2, niv. 3...).
## Ses bonus s'ajoutent à ceux de la voiture et des niveaux précédents.
## Agrandir un type agrandit toutes les voitures de ce type : le coût est multiplié
## par leur nombre.

## Couchettes en plus (dortoir).
@export var beds: int = 0
## Places de stock en plus (wagon de stock).
@export var storage: int = 0
## Production en plus à chaque trajet (serre, laboratoire).
@export var production: Dictionary[StringName, int] = {}
## Médicaments plus efficaces quand on les prend à bord (infirmerie) : points en plus.
@export_range(0.0, 1.0) var cure_bonus: float = 0.0
## Matériaux pour une voiture de ce type.
@export var cost: Dictionary[StringName, int] = {}
## Plan à étudier avant (vide = aucun).
@export var plan: StringName


## Bonus lisibles : « +2 couchettes », « +1 plante saine à chaque trajet »...
func describe() -> String:
	var parts: PackedStringArray = []
	if beds > 0:
		parts.append("+%d couchettes" % beds)
	if storage > 0:
		parts.append("+%d places de stock" % storage)
	for id: StringName in production:
		parts.append("+%d %s à chaque trajet" % [production[id], MenuKit.loot_name(id).to_lower()])
	if cure_bonus > 0.0:
		parts.append("médicaments +%d points" % roundi(cure_bonus * 100.0))
	return ", ".join(parts)
