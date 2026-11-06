class_name WagonData
extends Resource
## Un type de voiture du train : cabine, atelier, stock, dortoir...
##
## Un type = un fichier .tres dans data/wagons/. Les meubles de chaque type sont
## placés par la scène de l'intérieur du train (levels/train_interior/), d'après `id`.

@export var id: StringName
@export var display_name: String
## Icône 12 px des menus (onglet Train) : lit, caisse, marteau...
@export var icon: Texture2D
@export_multiline var description: String
## Un seul exemplaire possible dans le train (cabine, atelier).
@export var unique: bool = false

@export_group("Effets")
## Couchettes : nombre d'équipiers que la voiture peut loger.
@export var beds: int = 0
## Places dans le stock du train (nombre de ressources).
@export var storage: int = 0

@export_group("Machines")
## Ressources produites à chaque trajet (serre, laboratoire...).
@export var production: Dictionary[StringName, int] = {}
## Ressources consommées à chaque trajet pour produire (vide = gratuit).
@export var production_cost: Dictionary[StringName, int] = {}

@export_group("Construction")
## Matériaux à prendre dans le stock. Vide = ne se construit pas (fourni au départ).
@export var cost: Dictionary[StringName, int] = {}
## Plan à étudier avant de pouvoir la construire (vide = connue).
@export var plan: StringName

@export_group("Agrandissement")
## Niveaux 2, 3... (vide = ne s'agrandit pas).
@export var upgrades: Array[WagonUpgrade] = []


func max_level() -> int:
	return 1 + upgrades.size()


## L'agrandissement qui mène au niveau `level` (2, 3...), ou null.
func upgrade_to(level: int) -> WagonUpgrade:
	return upgrades[level - 2] if level >= 2 and level - 2 < upgrades.size() else null


func beds_at(level: int) -> int:
	var total: int = beds
	for i: int in range(2, level + 1):
		total += upgrade_to(i).beds if upgrade_to(i) else 0
	return total


func storage_at(level: int) -> int:
	var total: int = storage
	for i: int in range(2, level + 1):
		total += upgrade_to(i).storage if upgrade_to(i) else 0
	return total


func production_at(level: int) -> Dictionary[StringName, int]:
	var total: Dictionary[StringName, int] = production.duplicate()
	for i: int in range(2, level + 1):
		var upgrade: WagonUpgrade = upgrade_to(i)
		if upgrade:
			for id: StringName in upgrade.production:
				total[id] = total.get(id, 0) + upgrade.production[id]
	return total


func cure_bonus_at(level: int) -> float:
	var total: float = 0.0
	for i: int in range(2, level + 1):
		total += upgrade_to(i).cure_bonus if upgrade_to(i) else 0.0
	return total


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
