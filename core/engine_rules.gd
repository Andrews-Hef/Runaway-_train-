class_name EngineRules
extends RefCounted
## Énergie de la locomotive et pannes moteur. Pur : pas de scène, testable seul.
##
## La chaudière a une réserve (LocomotiveLevel.tender) qu'on remplit en y brûlant du bois
## ou du charbon (LootData.fuel). Chaque trajet en consomme selon la longueur du train.
## Si la réserve ne suffit pas : panne sèche, le train s'arrête en pleine voie. À chaque
## trajet, une panne moteur peut aussi l'arrêter, plus souvent s'il est abîmé.
##
## Arrêt forcé : on rapporte à la locomotive ce qui manque (combustible ou pièces), la
## réparation (ou la montée en pression) prend un moment, puis le train siffle et repart.

## Panne sèche : la chaudière est vide.
const DRY: StringName = &"dry"
## Panne moteur : il faut des pièces mécaniques.
const BREAKDOWN: StringName = &"breakdown"

## Énergie d'un trajet : une base, plus une par voiture (cabine comprise).
const TRIP_BASE: int = 2
const TRIP_PER_CAR: int = 1
## Réserve au départ d'une partie : 4 trajets avec le train de départ (4 voitures).
const START_ENERGY: int = 24

## Panne moteur : chance de base par trajet, plus selon l'usure du train, moins par
## mécanicien au travail.
const BREAKDOWN_BASE: float = 0.04
const BREAKDOWN_WEAR: float = 0.3
const BREAKDOWN_PER_MECHANIC: float = 0.02
const BREAKDOWN_MIN: float = 0.01
const BREAKDOWN_MAX: float = 0.4
## Pas de panne moteur avant cet arrêt : on apprend d'abord le jeu.
const BREAKDOWN_FROM_STOP: int = 3
## Pièces mécaniques pour réparer, une de plus si le train est critique.
const BREAKDOWN_PARTS: int = 2
const CRITICAL_EXTRA_PARTS: int = 1

## Réparation, une fois les pièces rapportées : moins longue avec des mécaniciens.
const REPAIR_SECONDS: float = 40.0
const REPAIR_PER_MECHANIC: float = 8.0
const REPAIR_MIN_SECONDS: float = 16.0
## Panne sèche : le temps que la pression remonte, une fois la chaudière rechargée.
const PRESSURE_SECONDS: float = 20.0
## Prêt à repartir : le train siffle et part après ce délai (monte vite !).
const DEPARTURE_SECONDS: float = 30.0
## Arrêt forcé : la horde arrive vite, le train immobile l'attire.
const HORDE_DELAY: Vector2 = Vector2(16.0, 24.0)


static func trip_cost(cars: int) -> int:
	return TRIP_BASE + TRIP_PER_CAR * maxi(cars, 0)


## Énergie qu'il reste à brûler quand le train s'arrête à mi-chemin.
static func rest_of_trip(cost: int) -> int:
	return ceili(cost / 2.0)


static func breakdown_chance(condition: float, mechanics: int) -> float:
	var chance: float = BREAKDOWN_BASE + BREAKDOWN_WEAR * (1.0 - clampf(condition, 0.0, 1.0)) \
		- BREAKDOWN_PER_MECHANIC * maxi(mechanics, 0)
	return clampf(chance, BREAKDOWN_MIN, BREAKDOWN_MAX)


static func parts_needed(critical: bool) -> int:
	return BREAKDOWN_PARTS + (CRITICAL_EXTRA_PARTS if critical else 0)


## Temps entre « tout est rapporté » et « le train peut repartir ».
static func repair_seconds(kind: StringName, mechanics: int) -> float:
	if kind == DRY:
		return PRESSURE_SECONDS
	return maxf(REPAIR_SECONDS - REPAIR_PER_MECHANIC * maxi(mechanics, 0), REPAIR_MIN_SECONDS)


## Combien d'unités d'un combustible (valeur `value`) tiennent dans `room` d'énergie,
## sans dépasser `have`. Une unité qui déborderait ne se charge pas.
static func loadable(value: int, room: int, have: int) -> int:
	if value <= 0 or room <= 0:
		return 0
	return mini(room / value, maxi(have, 0))


## Ce qu'il faut brûler pour obtenir au moins `energy`, dans la limite de `stock`, en
## gaspillant le moins possible : des unités entières du plus efficace d'abord, puis le
## reste avec le plus petit combustible disponible. Renvoie {id: quantité} (il peut
## manquer de quoi atteindre `energy`).
static func fuel_for(energy: int, stock: Dictionary, fuels: Array[LootData]) -> Dictionary[StringName, int]:
	var burn: Dictionary[StringName, int] = {}
	var usable: Array[LootData] = fuels.filter(func(loot: LootData) -> bool: return loot.fuel > 0)
	usable.sort_custom(func(a: LootData, b: LootData) -> bool: return a.fuel > b.fuel)
	var need: int = energy
	for loot: LootData in usable:
		var count: int = mini(int(stock.get(loot.id, 0)), need / loot.fuel)
		if count > 0:
			burn[loot.id] = count
			need -= count * loot.fuel
	usable.reverse()
	for loot: LootData in usable:
		while need > 0 and int(stock.get(loot.id, 0)) > burn.get(loot.id, 0):
			burn[loot.id] = burn.get(loot.id, 0) + 1
			need -= loot.fuel
	return burn


## Énergie que donnent ces combustibles.
static func energy_of(burn: Dictionary, fuels: Array[LootData]) -> int:
	var total: int = 0
	for loot: LootData in fuels:
		total += int(burn.get(loot.id, 0)) * loot.fuel
	return total
