extends Node
## Autoload « GameState » : la partie en cours, d'un arrêt à l'autre.
##
## Il connaît le prochain arrêt (type de zone + graine) et le stock du train,
## qui grossit à chaque sortie réussie. Il ne connaît aucune scène : les scènes
## le lisent et lui rapportent les résultats.
##
## Graine fixe pour déboguer : Paramètres du projet > game/debug/fixed_seed (0 = aléatoire).

signal storage_changed
signal crew_changed
signal equipment_changed
signal train_changed

const FIXED_SEED_SETTING: String = "game/debug/fixed_seed"
## Le premier arrêt est toujours celui-ci : une zone simple pour commencer.
const FIRST_ZONE: ZoneProfile = preload("res://data/zones/plains.tres")
## Zones possibles pour les arrêts suivants.
const ZONES: Array[ZoneProfile] = [
	preload("res://data/zones/plains.tres"),
	preload("res://data/zones/dead_forest.tres"),
	preload("res://data/zones/scrapyard.tres"),
	preload("res://data/zones/blight.tres"),
]

## Catalogue des ressources, dans l'ordre d'affichage (HUD, bilan, trajet).
const LOOT_TYPES: Array[LootData] = [
	preload("res://data/loot/scrap.tres"),
	preload("res://data/loot/wood.tres"),
	preload("res://data/loot/herb.tres"),
	preload("res://data/loot/infected_herb.tres"),
	preload("res://data/loot/cloth.tres"),
	preload("res://data/loot/parts.tres"),
]

## Le train du départ, de la queue à la tête (la cabine est toujours en tête).
const START_TRAIN: Array[WagonData] = [
	preload("res://data/wagons/dormitory.tres"),
	preload("res://data/wagons/workshop.tres"),
	preload("res://data/wagons/stock.tres"),
	preload("res://data/wagons/cabin.tres"),
]
## Voitures qu'on peut construire, dans l'ordre d'affichage.
const BUILDABLE_WAGONS: Array[WagonData] = [
	preload("res://data/wagons/dormitory.tres"),
	preload("res://data/wagons/stock.tres"),
]

## Numéro de l'arrêt en cours ou à venir (1 = premier arrêt).
var stop_number: int = 0
var current_zone: ZoneProfile
var current_seed: int = 0
## Ressources rapportées dans le train : id de LootData -> quantité.
var storage: Dictionary[StringName, int] = {}
## Équipage recruté pendant les sorties.
var crew: Array[CrewMember] = []
## Équipements possédés (rangés dans le train ou portés).
var owned_items: Array[ItemData] = []
## Ce que le joueur porte.
var loadout: Loadout = Loadout.new()
## Composition du train, de la queue à la tête. Les règles sont dans TrainRules.
var train: Array[WagonData] = []
var locomotive_level: int = 1

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	new_run()


## Nouvelle partie. run_seed = 0 : aléatoire (ou graine fixe des paramètres du projet).
func new_run(run_seed: int = 0) -> void:
	var fixed_seed: int = ProjectSettings.get_setting(FIXED_SEED_SETTING, 0)
	if run_seed != 0:
		_rng.seed = run_seed
	elif fixed_seed != 0:
		_rng.seed = fixed_seed
	else:
		_rng.randomize()
	stop_number = 0
	current_zone = null
	storage.clear()
	crew.clear()
	owned_items = ItemCatalog.starters()
	loadout = Loadout.new()
	for item: ItemData in owned_items:
		loadout.equip(item)
	train = START_TRAIN.duplicate()
	locomotive_level = 1
	storage_changed.emit()
	crew_changed.emit()
	equipment_changed.emit()
	train_changed.emit()
	prepare_next_stop()


## Tire le prochain arrêt : type de zone et graine de génération.
func prepare_next_stop() -> void:
	stop_number += 1
	current_zone = FIRST_ZONE if stop_number == 1 else _pick_zone(current_zone)
	current_seed = _rng.randi()


## Range le butin d'une sortie réussie dans le train et accueille les recrues.
## Ce qui ne rentre pas dans le stock reste sur le quai (result.left_behind).
func record_expedition(result: ExpeditionResult) -> void:
	if not result.boarded:
		return
	var free: int = storage_free()
	result.left_behind.clear()
	for id: StringName in result.loot:
		var kept: int = mini(result.loot[id], free)
		if kept > 0:
			storage[id] = storage.get(id, 0) + kept
			free -= kept
		if kept < result.loot[id]:
			result.left_behind[id] = result.loot[id] - kept
	storage_changed.emit()
	if not result.recruits.is_empty():
		crew.append_array(result.recruits)
		crew_changed.emit()
	for item: ItemData in result.items:
		if not item in owned_items:
			owned_items.append(item)
	if not result.items.is_empty():
		equipment_changed.emit()


## Fabrique un équipement à l'atelier avec les matériaux du stock.
func craft(item: ItemData) -> bool:
	if not Crafting.craft(item, storage, owned_items):
		return false
	storage_changed.emit()
	equipment_changed.emit()
	return true


## Porte un équipement possédé (remplace celui du même emplacement).
func equip(item: ItemData) -> void:
	if not item in owned_items:
		return
	loadout.equip(item)
	equipment_changed.emit()


func owned_for_slot(slot: ItemData.Slot) -> Array[ItemData]:
	var list: Array[ItemData] = []
	for item: ItemData in owned_items:
		if item.slot == slot:
			list.append(item)
	return list


## Prénoms déjà pris dans l'équipage (pour ne pas recruter deux « Léa »).
func crew_names() -> Array[String]:
	var names: Array[String] = []
	for member: CrewMember in crew:
		names.append(member.display_name)
	return names


# --- Train ------------------------------------------------------------------------

## Voitures que la locomotive peut tirer (cabine comprise).
func max_cars() -> int:
	return TrainRules.max_cars(locomotive_level)


func beds() -> int:
	return TrainRules.beds(train)


## Couchettes libres : combien de recrues le train peut encore accueillir.
func free_beds() -> int:
	return maxi(beds() - crew.size(), 0)


func storage_capacity() -> int:
	return TrainRules.storage_capacity(train)


func storage_free() -> int:
	return maxi(storage_capacity() - storage_total(), 0)


## Construit une voiture avec le stock. Elle s'attelle en queue du train.
func build_wagon(wagon: WagonData) -> bool:
	if TrainRules.build_problem(wagon, train, locomotive_level, storage) != TrainRules.Problem.NONE:
		return false
	TrainRules.pay(wagon.cost, storage)
	train.insert(0, wagon)
	storage_changed.emit()
	train_changed.emit()
	return true


## Renforce la locomotive : elle tire une voiture de plus.
func upgrade_locomotive() -> bool:
	if TrainRules.upgrade_problem(locomotive_level, storage) != TrainRules.Problem.NONE:
		return false
	TrainRules.pay(TrainRules.next_level(locomotive_level).cost, storage)
	locomotive_level += 1
	storage_changed.emit()
	train_changed.emit()
	return true


func storage_amount(id: StringName) -> int:
	return storage.get(id, 0)


func storage_total() -> int:
	var total: int = 0
	for amount: int in storage.values():
		total += amount
	return total


## Tirage pondéré, en évitant si possible de reprendre la même zone deux fois de suite.
func _pick_zone(previous: ZoneProfile) -> ZoneProfile:
	var candidates: Array[ZoneProfile] = []
	for zone: ZoneProfile in ZONES:
		if zone != previous:
			candidates.append(zone)
	if candidates.is_empty():
		candidates = ZONES.duplicate()
	var total: float = 0.0
	for zone: ZoneProfile in candidates:
		total += zone.weight
	var roll: float = _rng.randf() * total
	for zone: ZoneProfile in candidates:
		roll -= zone.weight
		if roll <= 0.0:
			return zone
	return candidates.back()
