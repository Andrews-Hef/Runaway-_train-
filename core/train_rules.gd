class_name TrainRules
extends RefCounted
## Règles de composition du train.
##
## - La locomotive tire un nombre limité de voitures (cabine comprise) : 5 au
##   niveau 1, jusqu'à 8 au dernier niveau. C'est le plafond du train.
## - Les voitures se construisent avec les matériaux du stock ; la cabine et
##   l'atelier sont uniques.
## - Les dortoirs donnent des couchettes (taille max de l'équipage), les wagons
##   de stock des places (ressources rangées à bord).
##
## Pur : on lui passe la composition, le niveau de la locomotive et le stock.

## Ce qui empêche une construction ou une amélioration.
enum Problem { NONE, NOT_BUILDABLE, ALREADY_THERE, NO_TRACTION, MISSING_MATERIALS, MAX_LEVEL, NEEDS_PLAN }

## Niveaux de la locomotive, du premier au dernier.
const LEVELS: Array[LocomotiveLevel] = [
	preload("res://data/locomotive/level_1.tres"),
	preload("res://data/locomotive/level_2.tres"),
	preload("res://data/locomotive/level_3.tres"),
	preload("res://data/locomotive/level_4.tres"),
]

## Texte de chaque problème, pour l'interface.
const PROBLEM_TEXTS: Dictionary[Problem, String] = {
	Problem.NOT_BUILDABLE: "Ne se construit pas.",
	Problem.ALREADY_THERE: "Il y en a déjà une dans le train.",
	Problem.NO_TRACTION: "La locomotive ne peut pas tirer une voiture de plus : renforce-la.",
	Problem.MISSING_MATERIALS: "Il manque des matériaux dans le stock.",
	Problem.MAX_LEVEL: "La locomotive est au niveau maximum.",
	Problem.NEEDS_PLAN: "Il faut d'abord étudier son plan.",
}


static func max_level() -> int:
	return LEVELS.size()


## Voitures tirées au maximum à ce niveau (cabine comprise).
static func max_cars(level: int) -> int:
	return LEVELS[clampi(level, 1, LEVELS.size()) - 1].max_cars


## Le niveau suivant, ou null si la locomotive est au maximum.
static func next_level(level: int) -> LocomotiveLevel:
	return LEVELS[level] if level >= 1 and level < LEVELS.size() else null


static func count(train: Array[WagonData], wagon: WagonData) -> int:
	return train.count(wagon)


## `levels` : niveau d'agrandissement par type de voiture (id -> niveau, 1 par défaut).
static func beds(train: Array[WagonData], levels: Dictionary[StringName, int] = {}) -> int:
	var total: int = 0
	for wagon: WagonData in train:
		total += wagon.beds_at(levels.get(wagon.id, 1))
	return total


static func storage_capacity(train: Array[WagonData], levels: Dictionary[StringName, int] = {}) -> int:
	var total: int = 0
	for wagon: WagonData in train:
		total += wagon.storage_at(levels.get(wagon.id, 1))
	return total


## Coût pour agrandir toutes les voitures d'un type (`count` voitures) au niveau `level`.
static func upgrade_cost(wagon: WagonData, level: int, count: int) -> Dictionary[StringName, int]:
	var cost: Dictionary[StringName, int] = {}
	var upgrade: WagonUpgrade = wagon.upgrade_to(level)
	if upgrade:
		for id: StringName in upgrade.cost:
			cost[id] = upgrade.cost[id] * maxi(count, 1)
	return cost


## Peut-on agrandir ce type de voiture au niveau suivant ? Problem.NONE si oui.
static func upgrade_wagon_problem(wagon: WagonData, current_level: int, count: int,
		storage: Dictionary[StringName, int], plan_known: bool) -> Problem:
	var upgrade: WagonUpgrade = wagon.upgrade_to(current_level + 1)
	if upgrade == null:
		return Problem.MAX_LEVEL
	if not plan_known:
		return Problem.NEEDS_PLAN
	if not missing(upgrade_cost(wagon, current_level + 1, count), storage).is_empty():
		return Problem.MISSING_MATERIALS
	return Problem.NONE


## Ce qui manque dans le stock pour payer : id -> quantité (vide = payable).
static func missing(cost: Dictionary[StringName, int], storage: Dictionary[StringName, int]) -> Dictionary[StringName, int]:
	var lacking: Dictionary[StringName, int] = {}
	for id: StringName in cost:
		var short: int = cost[id] - storage.get(id, 0)
		if short > 0:
			lacking[id] = short
	return lacking


## Peut-on ajouter cette voiture au train ? Problem.NONE si oui.
static func build_problem(wagon: WagonData, train: Array[WagonData], level: int,
		storage: Dictionary[StringName, int], plan_known: bool = true) -> Problem:
	if not wagon.is_buildable():
		return Problem.NOT_BUILDABLE
	if not plan_known:
		return Problem.NEEDS_PLAN
	if wagon.unique and wagon in train:
		return Problem.ALREADY_THERE
	if train.size() >= max_cars(level):
		return Problem.NO_TRACTION
	if not missing(wagon.cost, storage).is_empty():
		return Problem.MISSING_MATERIALS
	return Problem.NONE


## Peut-on renforcer la locomotive ? Problem.NONE si oui.
static func upgrade_problem(level: int, storage: Dictionary[StringName, int]) -> Problem:
	var next: LocomotiveLevel = next_level(level)
	if next == null:
		return Problem.MAX_LEVEL
	if not missing(next.cost, storage).is_empty():
		return Problem.MISSING_MATERIALS
	return Problem.NONE


## Retire le coût du stock (à appeler après avoir vérifié qu'il est payable).
static func pay(cost: Dictionary[StringName, int], storage: Dictionary[StringName, int]) -> void:
	for id: StringName in cost:
		var left: int = storage.get(id, 0) - cost[id]
		if left > 0:
			storage[id] = left
		else:
			storage.erase(id)
