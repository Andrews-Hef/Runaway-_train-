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
## Mérite, grade, talents ou ordre du capitaine ont changé.
signal career_changed
## L'infection du joueur a changé (sortie, médicament).
signal infection_changed
## Un plan a été trouvé ou étudié.
signal plans_changed
## L'état du train a changé (horde, réparation).
signal condition_changed

## Plan qui relie les postes du train (voir stations_linked()).
const INTERCOM_PLAN: StringName = &"intercom"
const FIXED_SEED_SETTING: String = "game/debug/fixed_seed"
## Le premier arrêt est toujours celui-ci : une zone simple pour commencer.
const FIRST_ZONE: ZoneProfile = preload("res://data/zones/plains.tres")
## Tous les types d'arrêt. Chacun appartient à un biome (sa région).
const ZONES: Array[ZoneProfile] = [
	preload("res://data/zones/plains.tres"),
	preload("res://data/zones/dead_forest.tres"),
	preload("res://data/zones/scrapyard.tres"),
	preload("res://data/zones/blight.tres"),
	preload("res://data/zones/bog.tres"),
	preload("res://data/zones/stilt_village.tres"),
	preload("res://data/zones/reed_beds.tres"),
	preload("res://data/zones/boulevard.tres"),
	preload("res://data/zones/residential.tres"),
	preload("res://data/zones/hospital.tres"),
	preload("res://data/zones/chemical_plant.tres"),
	preload("res://data/zones/warehouses.tres"),
	preload("res://data/zones/rail_yard.tres"),
	preload("res://data/zones/frozen_plain.tres"),
	preload("res://data/zones/pine_forest.tres"),
	preload("res://data/zones/military_camp.tres"),
]
## Les régions de la ligne, dans l'ordre : on change de région à chaque gare refuge
## (arrêts 1 à 5 : campagne, 6 à 10 : marais...). Après la toundra, la ligne repart.
const REGIONS: Array[BiomeData] = [
	preload("res://data/biomes/countryside.tres"),
	preload("res://data/biomes/marsh.tres"),
	preload("res://data/biomes/city.tres"),
	preload("res://data/biomes/industrial.tres"),
	preload("res://data/biomes/tundra.tres"),
]
## Nombre de voies proposées à chaque aiguillage.
const ROUTE_CHOICES: int = 2
## Événements d'arrêt possibles. Les annoncés (pluie) sont tirés pour chaque voie de
## l'aiguillage ; les surprises (horde) sont tirées à l'arrivée, sans prévenir.
const EVENTS: Array[EventData] = [
	preload("res://data/events/infected_rain.tres"),
	preload("res://data/events/horde.tres"),
]
## État du train : en dessous, il est abîmé (les machines s'arrêtent)...
const TRAIN_DAMAGED: float = 0.6
## ... puis critique (il repart plus tôt : arrêts écourtés).
const TRAIN_CRITICAL: float = 0.25
## Arrêts écourtés quand le train est critique (part de la durée normale).
const CRITICAL_STOP_TIME: float = 0.8
## Réparation à la cabine : gain et coût.
const REPAIR_STEP: float = 0.25
const REPAIR_COST: Dictionary[StringName, int] = {&"scrap": 3, &"wood": 2}
## Réparation complète au dépôt d'une gare refuge.
const DEPOT_REPAIR_COST: Dictionary[StringName, int] = {&"scrap": 5}
## Réparation par mécanicien de l'équipage, à chaque trajet (voir CrewLife).
const MECHANIC_REPAIR: float = CrewLife.MECHANIC_REPAIR
const MAX_MECHANICS: int = CrewLife.MAX_MECHANICS
## Soins de l'équipage par le capitaine : panser (1 tissu) et confiance gagnée.
const BANDAGE_COST: Dictionary[StringName, int] = {&"cloth": 1}
const BANDAGE_HEAL: int = 30
const BANDAGE_TRUST: int = 5
const MEDICINE_TRUST: int = 10
## Places de quarantaine à l'infirmerie.
const QUARANTINE_BEDS: int = 2
## Confiance de départ : recrue de gare (sortie de quarantaine) ou trouvée en route.
const REFUGE_RECRUIT_TRUST: int = 60
const FIELD_RECRUIT_TRUST: int = 40
## Mérite pour une horde repoussée (tous ses membres éliminés).
const HORDE_MERIT: int = 15
## La nuit, les hordes sont plus fréquentes (multiplie leur chance).
const NIGHT_HORDE_FACTOR: float = 1.5

## Points de vie du joueur sans talent.
const BASE_HEALTH: int = 10
## Une gare refuge tous les N arrêts (arrêts n°5, 10, 15...).
const REFUGE_EVERY: int = 5
## Gares refuges de la ligne, dans l'ordre où le train les rencontre (puis on recommence).
const REFUGES: Array[RefugeData] = [
	preload("res://data/refuges/fort_cendre.tres"),
	preload("res://data/refuges/vireux.tres"),
]

## Catalogue des ressources, dans l'ordre d'affichage (HUD, bilan, trajet).
const LOOT_TYPES: Array[LootData] = [
	preload("res://data/loot/scrap.tres"),
	preload("res://data/loot/wood.tres"),
	preload("res://data/loot/herb.tres"),
	preload("res://data/loot/infected_herb.tres"),
	preload("res://data/loot/cloth.tres"),
	preload("res://data/loot/parts.tres"),
	preload("res://data/loot/metal_plate.tres"),
	preload("res://data/loot/chemicals.tres"),
	preload("res://data/loot/antiseptic.tres"),
	preload("res://data/loot/antibiotics.tres"),
	preload("res://data/loot/serum.tres"),
	preload("res://data/loot/vaccine.tres"),
]

## Le train du départ, de la queue à la tête (la cabine est toujours en tête).
const START_TRAIN: Array[WagonData] = [
	preload("res://data/wagons/dormitory.tres"),
	preload("res://data/wagons/workshop.tres"),
	preload("res://data/wagons/stock.tres"),
	preload("res://data/wagons/cabin.tres"),
]
## Tous les types de voitures (pour relire une sauvegarde).
const WAGON_TYPES: Array[WagonData] = [
	preload("res://data/wagons/cabin.tres"),
	preload("res://data/wagons/workshop.tres"),
	preload("res://data/wagons/stock.tres"),
	preload("res://data/wagons/dormitory.tres"),
	preload("res://data/wagons/infirmary.tres"),
	preload("res://data/wagons/greenhouse.tres"),
	preload("res://data/wagons/laboratory.tres"),
]
## Version du format de sauvegarde (à augmenter si le format change).
const SAVE_VERSION: int = 1
## Voitures qu'on peut construire, dans l'ordre d'affichage.
const BUILDABLE_WAGONS: Array[WagonData] = [
	preload("res://data/wagons/dormitory.tres"),
	preload("res://data/wagons/stock.tres"),
	preload("res://data/wagons/infirmary.tres"),
	preload("res://data/wagons/greenhouse.tres"),
	preload("res://data/wagons/laboratory.tres"),
]


## Une voie de l'aiguillage : un type d'arrêt, sa graine et l'ordre du capitaine.
class StopOption:
	var zone: ZoneProfile
	var seed: int
	var order: CaptainOrders.Order
	## Événement prévu à cet arrêt (pluie infectée...), null s'il n'y en a pas.
	var event: EventData
	## Un éclaireur a guetté la voie : on sait si une horde y attend (horde_spotted).
	var scouted: bool = false
	var horde_spotted: bool = false

	func _init(option_zone: ZoneProfile, option_seed: int, option_order: CaptainOrders.Order, option_event: EventData = null) -> void:
		zone = option_zone
		seed = option_seed
		order = option_order
		event = option_event

## Numéro de l'arrêt en cours ou à venir (1 = premier arrêt).
var stop_number: int = 0
## Type de zone de l'arrêt (le dernier tiré, si l'arrêt est une gare refuge).
var current_zone: ZoneProfile
## Voies proposées à l'aiguillage pour le prochain arrêt (vide pour une gare refuge).
## current_zone, current_seed et current_order valent la voie choisie (la 1re par défaut).
var route_options: Array[StopOption] = []
## Événement de l'arrêt à venir (celui de la voie choisie), null s'il n'y en a pas.
var current_event: EventData
## Gare refuge de l'arrêt, ou null si c'est une zone à fouiller.
var current_refuge: RefugeData
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
## Niveau d'agrandissement par type de voiture (id -> niveau ; absent = niveau 1).
var wagon_levels: Dictionary[StringName, int] = {}
## Carrière : mérite cumulé, talents choisis, grades obtenus dont le talent reste à choisir.
var merit: int = 0
var perks: Array[PerkData] = []
var pending_promotions: Array[GradeData] = []
## Ordre du capitaine pour l'arrêt à venir (null en gare refuge).
var current_order: CaptainOrders.Order
## Infection du joueur (0 à 1) : elle ne baisse qu'avec des médicaments. Voir Infection.
var infection: float = 0.0
## Heure du jeu, en minutes depuis le jour 1 à 0h (voir DayClock). Dans le train et
## au trajet : l'heure d'arrivée au prochain arrêt.
var clock_minutes: int = DayClock.START_MINUTES
## État du train (0 à 1) : la horde l'abîme, on le répare. Il reste d'un arrêt à l'autre.
var train_condition: float = 1.0
## Réparé par les mécaniciens pendant le dernier trajet.
var last_repair: float = 0.0
## Récit du dernier trajet pour l'équipage (travail, maladie, demandes, pertes).
var last_crew_events: Array[String] = []
## Dégâts de la horde depuis le dernier trajet : l'équipage à bord est blessé.
var _horde_damage: float = 0.0
## Plans trouvés (pas encore étudiés) et plans étudiés (ids de BlueprintData).
var found_plans: Array[StringName] = []
var researched_plans: Array[StringName] = []
## Ce que les machines du train ont produit pendant le dernier trajet (pour l'afficher).
var last_production: Dictionary[StringName, int] = {}

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
	current_refuge = null
	storage.clear()
	crew.clear()
	owned_items = ItemCatalog.starters()
	loadout = Loadout.new()
	for item: ItemData in owned_items:
		loadout.equip(item)
	train = START_TRAIN.duplicate()
	locomotive_level = 1
	wagon_levels.clear()
	merit = 0
	perks.clear()
	pending_promotions.clear()
	infection = 0.0
	train_condition = 1.0
	last_repair = 0.0
	last_crew_events.clear()
	_horde_damage = 0.0
	clock_minutes = DayClock.START_MINUTES
	found_plans.clear()
	researched_plans.clear()
	last_production.clear()
	storage_changed.emit()
	crew_changed.emit()
	equipment_changed.emit()
	train_changed.emit()
	prepare_next_stop()
	career_changed.emit()
	infection_changed.emit()
	plans_changed.emit()


## Prépare le prochain arrêt : gare refuge (tous les REFUGE_EVERY arrêts), ou deux voies
## à l'aiguillage, tirées parmi les types d'arrêt de la région en cours.
func prepare_next_stop() -> void:
	# On quitte un arrêt : les machines travaillent et les mécaniciens réparent pendant le trajet.
	last_production.clear()
	last_repair = 0.0
	last_crew_events.clear()
	var scouted: bool = false
	if stop_number >= 1:
		last_production = run_machines()
		scouted = _crew_trajet((stop_number + 1) % REFUGE_EVERY == 0)
	# Le temps passe : une heure en gare refuge si on en repart, puis le trajet.
	if current_refuge != null and stop_number >= 1:
		clock_minutes += DayClock.REFUGE_MINUTES
	clock_minutes += DayClock.TRAVEL_MINUTES
	stop_number += 1
	route_options.clear()
	if stop_number % REFUGE_EVERY == 0:
		current_refuge = REFUGES[(stop_number / REFUGE_EVERY - 1) % REFUGES.size()]
		current_seed = _rng.randi()
		current_order = null
		current_event = null
	else:
		current_refuge = null
		var zones: Array[ZoneProfile] = [FIRST_ZONE]
		if stop_number > 1:
			zones = _pick_zones(region(), current_zone, ROUTE_CHOICES)
		for zone: ZoneProfile in zones:
			route_options.append(_make_option(zone, _rng.randi()))
		# Un éclaireur a guetté : on sait quelles voies cachent une horde.
		if scouted:
			for option: StopOption in route_options:
				option.scouted = true
				option.horde_spotted = roll_surprise(option.zone.biome, stop_number, option.seed,
					DayClock.is_night(clock_minutes)) != null
		_apply_option(route_options[0])
	career_changed.emit()


## Une voie : l'ordre et l'événement ont leur propre hasard, tiré de la graine de l'arrêt.
func _make_option(zone: ZoneProfile, option_seed: int) -> StopOption:
	var order_rng := RandomNumberGenerator.new()
	order_rng.seed = option_seed + 7
	var order: CaptainOrders.Order = CaptainOrders.pick(zone, stop_number, order_rng, bag_capacity())
	return StopOption.new(zone, option_seed, order, roll_event(zone.biome, stop_number, option_seed))


## Événement d'un arrêt, tiré de sa graine (null : rien de prévu).
static func roll_event(biome: BiomeData, stop: int, option_seed: int) -> EventData:
	var event_rng := RandomNumberGenerator.new()
	event_rng.seed = option_seed + 13
	for event: EventData in EVENTS:
		if event.announced and event_rng.randf() < event.chance_for(biome, stop):
			return event
	return null


## Surprise d'un arrêt (horde), tirée de sa graine à l'arrivée : jamais annoncée.
## La nuit, les hordes sont plus fréquentes.
static func roll_surprise(biome: BiomeData, stop: int, stop_seed: int, night: bool = false) -> EventData:
	var surprise_rng := RandomNumberGenerator.new()
	surprise_rng.seed = stop_seed + 29
	for event: EventData in EVENTS:
		var chance: float = event.chance_for(biome, stop) * (NIGHT_HORDE_FACTOR if night else 1.0)
		if not event.announced and surprise_rng.randf() < chance:
			return event
	return null


func _apply_option(option: StopOption) -> void:
	current_zone = option.zone
	current_seed = option.seed
	current_order = option.order
	current_event = option.event


## Faut-il choisir sa voie à l'aiguillage avant de descendre ?
func has_route_choice() -> bool:
	return route_options.size() > 1


## Prend la voie n° index de l'aiguillage. Renvoie false si elle n'existe pas.
func choose_route(index: int) -> bool:
	if index < 0 or index >= route_options.size():
		return false
	_apply_option(route_options[index])
	career_changed.emit()
	return true


## Région (biome) d'un numéro d'arrêt : elle change après chaque gare refuge.
func region_for(stop: int) -> BiomeData:
	var index: int = maxi(stop - 1, 0) / REFUGE_EVERY
	return REGIONS[index % REGIONS.size()]


## Région de l'arrêt à venir.
func region() -> BiomeData:
	return region_for(stop_number)


## Arrêts de la région en cours : du premier à la gare refuge qui la termine.
func region_stops() -> Vector2i:
	var first: int = maxi(stop_number - 1, 0) / REFUGE_EVERY * REFUGE_EVERY + 1
	return Vector2i(first, first + REFUGE_EVERY - 1)


func is_refuge_stop() -> bool:
	return current_refuge != null


## Numéro de la prochaine gare refuge (l'arrêt en cours s'il en est une).
func next_refuge_stop() -> int:
	var rest: int = stop_number % REFUGE_EVERY
	return stop_number if rest == 0 else stop_number + REFUGE_EVERY - rest


## Nom de l'arrêt à venir, gare refuge ou zone.
func stop_name() -> String:
	return current_refuge.display_name if current_refuge else current_zone.display_name


func stop_description() -> String:
	return current_refuge.description if current_refuge else current_zone.description


## Range le butin d'une sortie réussie dans le train et accueille les recrues.
## Ce qui ne rentre pas dans le stock reste sur le quai (result.left_behind).
## Compte aussi le mérite : ennemis éliminés et ordre du capitaine (rempli dans result).
func record_expedition(result: ExpeditionResult) -> void:
	if not result.boarded:
		return
	result.order_completed = current_order != null and current_order.is_completed(result)
	result.merit_gained = result.kill_merit() + (current_order.data.merit if result.order_completed else 0) \
		+ (HORDE_MERIT if result.horde_repelled else 0)
	result.promotions = add_merit(result.merit_gained)
	for member: CrewMember in crew:
		if CrewRequests.met_by(member, result):
			result.crew_thanks.append(CrewRequests.complete(member))
	if not result.crew_thanks.is_empty():
		crew_changed.emit()
	infection = clampf(result.exposure, 0.0, 1.0)
	infection_changed.emit()
	for plan_id: StringName in result.plans:
		if not plan_id in found_plans and not plan_id in researched_plans:
			found_plans.append(plan_id)
	if not result.plans.is_empty():
		plans_changed.emit()
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


## Fabrique un équipement à l'atelier avec les matériaux du stock (son plan doit être étudié).
func craft(item: ItemData) -> bool:
	if not is_known(item.plan) or not Crafting.craft(item, storage, owned_items):
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


# --- Infection et médicaments -----------------------------------------------------

## Prend un médicament du stock : l'infection baisse. Renvoie false si impossible.
func take_medicine(medicine: LootData) -> bool:
	if not medicine.is_medicine() or storage_amount(medicine.id) <= 0 or infection <= 0.0:
		return false
	TrainRules.pay({medicine.id: 1} as Dictionary[StringName, int], storage)
	infection = maxf(infection - medicine_cure(medicine), 0.0)
	storage_changed.emit()
	infection_changed.emit()
	return true


## Effet d'un médicament pris à bord : le sien, plus le bonus de l'infirmerie agrandie.
func medicine_cure(medicine: LootData) -> float:
	var bonus: float = 0.0
	for wagon: WagonData in train:
		bonus = maxf(bonus, wagon.cure_bonus_at(wagon_level(wagon.id)))
	return medicine.cure + bonus


func has_wagon(id: StringName) -> bool:
	for wagon: WagonData in train:
		if wagon.id == id:
			return true
	return false


# --- Plans, recherche, recettes ----------------------------------------------------

## Plan déjà trouvé ou étudié (on ne le rachète pas).
func knows_plan(plan_id: StringName) -> bool:
	return plan_id != &"" and (plan_id in found_plans or plan_id in researched_plans)


## Une recette, un équipement ou une voiture avec ce plan est-il connu ?
func is_known(plan_id: StringName) -> bool:
	return plan_id == &"" or plan_id in researched_plans


## Postes du train reliés (plan Interphone étudié) : chaque meuble ouvre tous les
## menus. Sinon, chaque poste n'ouvre que le sien (l'établi, l'atelier...).
func stations_linked() -> bool:
	return INTERCOM_PLAN in researched_plans


## Plans qu'on peut encore trouver par hasard à cet arrêt.
func unfound_plans() -> Array[StringName]:
	var list: Array[StringName] = []
	for plan: BlueprintData in BlueprintCatalog.ALL:
		if stop_number >= plan.min_stop and not plan.id in found_plans and not plan.id in researched_plans:
			list.append(plan.id)
	return list


## Ajoute un plan trouvé (gare, marchand...). Renvoie false s'il était déjà connu.
func add_plan(plan_id: StringName) -> bool:
	if plan_id == &"" or plan_id in found_plans or plan_id in researched_plans:
		return false
	found_plans.append(plan_id)
	plans_changed.emit()
	return true


## Étudie un plan trouvé à l'atelier : paie son coût, débloque ce qu'il contient.
func research(plan: BlueprintData) -> bool:
	if not BlueprintCatalog.research_problem(plan, found_plans, researched_plans, storage).is_empty():
		return false
	TrainRules.pay(plan.research_cost, storage)
	found_plans.erase(plan.id)
	researched_plans.append(plan.id)
	storage_changed.emit()
	plans_changed.emit()
	return true


## Pourquoi on ne peut pas préparer cette recette (vide = c'est possible).
func recipe_problem(recipe: RecipeData) -> String:
	if not is_known(recipe.plan):
		return "Plan à étudier."
	if recipe.station == RecipeData.Station.INFIRMARY and not has_wagon(&"infirmary"):
		return "Il faut une infirmerie (à construire dans la cabine)."
	if not TrainRules.missing(recipe.cost, storage).is_empty():
		return "Il manque des matériaux dans le stock."
	var gained: int = 0
	for amount: int in recipe.output.values():
		gained += amount
	for amount: int in recipe.cost.values():
		gained -= amount
	if gained > storage_free():
		return "Pas assez de place dans le stock."
	return ""


func make_recipe(recipe: RecipeData) -> bool:
	if not recipe_problem(recipe).is_empty():
		return false
	TrainRules.pay(recipe.cost, storage)
	for id: StringName in recipe.output:
		storage[id] = storage.get(id, 0) + recipe.output[id]
	storage_changed.emit()
	return true


## Les machines du train (serre, laboratoire) produisent : renvoie ce qui a été produit.
func run_machines() -> Dictionary[StringName, int]:
	var produced: Dictionary[StringName, int] = {}
	# Train abîmé : plus de courant pour la serre ni le labo.
	if train_condition < TRAIN_DAMAGED:
		return produced
	for wagon: WagonData in train:
		var production: Dictionary[StringName, int] = wagon.production_at(wagon_level(wagon.id))
		if production.is_empty() or not TrainRules.missing(wagon.production_cost, storage).is_empty():
			continue
		var gained: int = 0
		for amount: int in production.values():
			gained += amount
		for amount: int in wagon.production_cost.values():
			gained -= amount
		if gained > storage_free():
			continue
		TrainRules.pay(wagon.production_cost, storage)
		for id: StringName in production:
			storage[id] = storage.get(id, 0) + production[id]
			produced[id] = produced.get(id, 0) + production[id]
	if not produced.is_empty():
		storage_changed.emit()
	return produced


# --- État du train -----------------------------------------------------------------

enum Condition { GOOD, DAMAGED, CRITICAL }


func condition() -> Condition:
	if train_condition < TRAIN_CRITICAL:
		return Condition.CRITICAL
	return Condition.DAMAGED if train_condition < TRAIN_DAMAGED else Condition.GOOD


## « 84 % · bon », « 40 % · abîmé : les machines sont à l'arrêt »...
func describe_condition() -> String:
	var percent: int = roundi(train_condition * 100.0)
	match condition():
		Condition.CRITICAL:
			return "%d %% · critique : machines à l'arrêt, arrêts écourtés" % percent
		Condition.DAMAGED:
			return "%d %% · abîmé : machines à l'arrêt" % percent
	return "%d %% · bon état" % percent


## Coups de la horde. Renvoie l'état restant.
func damage_train(amount: float) -> float:
	if amount <= 0.0 or train_condition <= 0.0:
		return train_condition
	_horde_damage += minf(amount, train_condition)
	train_condition = maxf(train_condition - amount, 0.0)
	condition_changed.emit()
	return train_condition


## Part de la durée normale d'un arrêt : écourté quand le train est critique.
func stop_time_factor() -> float:
	return CRITICAL_STOP_TIME if condition() == Condition.CRITICAL else 1.0


func can_repair_train() -> bool:
	return train_condition < 1.0 and TrainRules.missing(REPAIR_COST, storage).is_empty()


## Réparation à la cabine : +REPAIR_STEP pour REPAIR_COST. Renvoie false si impossible.
func repair_train() -> bool:
	if not can_repair_train():
		return false
	TrainRules.pay(REPAIR_COST, storage)
	train_condition = minf(train_condition + REPAIR_STEP, 1.0)
	storage_changed.emit()
	condition_changed.emit()
	return true


## Réparation complète au dépôt d'une gare refuge.
func repair_train_at_depot() -> bool:
	if train_condition >= 1.0 or not TrainRules.missing(DEPOT_REPAIR_COST, storage).is_empty():
		return false
	TrainRules.pay(DEPOT_REPAIR_COST, storage)
	train_condition = 1.0
	storage_changed.emit()
	condition_changed.emit()
	return true


## L'équipage pendant le trajet (CrewLife) : travail, repos, maladie, pertes, demandes.
## Renvoie true si un éclaireur a guetté la voie.
func _crew_trajet(to_refuge: bool) -> bool:
	if crew.is_empty():
		_horde_damage = 0.0
		return false
	var context := CrewLife.Context.new()
	context.dorm_level = wagon_level(&"dormitory")
	context.horde_damage = _horde_damage
	context.to_refuge = to_refuge
	context.rng = RandomNumberGenerator.new()
	context.rng.seed = _rng.seed + stop_number * 101
	_horde_damage = 0.0
	var report: CrewLife.Report = CrewLife.run_trajet(crew, context)
	var before: float = train_condition
	train_condition = clampf(train_condition + report.repair - report.train_damage, 0.0, 1.0)
	last_repair = maxf(train_condition - before, 0.0) if report.train_damage == 0.0 else 0.0
	last_crew_events = report.events
	crew_changed.emit()
	if train_condition != before:
		condition_changed.emit()
	return report.scouted


# --- Soins et ordres à l'équipage ---------------------------------------------------

func can_bandage(member: CrewMember) -> bool:
	return member.health < 100 and TrainRules.missing(BANDAGE_COST, storage).is_empty()


## Panser un équipier : 1 tissu, +30 PV, un peu de confiance.
func bandage(member: CrewMember) -> bool:
	if not can_bandage(member):
		return false
	TrainRules.pay(BANDAGE_COST, storage)
	member.health = mini(member.health + BANDAGE_HEAL, 100)
	member.trust = mini(member.trust + BANDAGE_TRUST, 100)
	storage_changed.emit()
	crew_changed.emit()
	return true


## Le médicament qu'on donnerait (le plus faible disponible), null s'il n'y en a pas.
func medicine_for_crew() -> LootData:
	for loot: LootData in LOOT_TYPES:
		if loot.is_medicine() and storage_amount(loot.id) > 0:
			return loot
	return null


## Donner un médicament : l'infection baisse et on sait enfin où il en est.
func medicate(member: CrewMember) -> bool:
	var medicine: LootData = medicine_for_crew()
	if medicine == null or (member.infection_known and member.infection == 0):
		return false
	storage[medicine.id] -= 1
	member.infection = maxi(member.infection - roundi(medicine.cure * 100.0), 0)
	member.infection_known = true
	member.infected = member.infection > 0
	member.trust = mini(member.trust + MEDICINE_TRUST, 100)
	storage_changed.emit()
	crew_changed.emit()
	return true


func toggle_rest(member: CrewMember) -> void:
	member.resting = not member.resting
	crew_changed.emit()


func quarantined_count() -> int:
	return crew.filter(func(m: CrewMember) -> bool: return m.quarantined).size()


func can_quarantine(member: CrewMember) -> bool:
	return member.quarantined or (has_wagon(&"infirmary") and quarantined_count() < QUARANTINE_BEDS)


## Isoler à l'infirmerie (ou l'en sortir) : il ne contamine plus personne.
func toggle_quarantine(member: CrewMember) -> bool:
	if not can_quarantine(member):
		return false
	member.quarantined = not member.quarantined
	crew_changed.emit()
	return true


## Le faire descendre du train (au prochain arrêt).
func dismiss(member: CrewMember) -> void:
	crew.erase(member)
	crew_changed.emit()


func can_fulfil_request(member: CrewMember) -> bool:
	return member.request_kind == &"deliver" and TrainRules.missing(CrewRequests.cost(member), storage).is_empty()


## Remplir une demande « donner » avec le stock. Renvoie false si impossible.
func fulfil_request(member: CrewMember) -> bool:
	if not can_fulfil_request(member):
		return false
	TrainRules.pay(CrewRequests.cost(member), storage)
	CrewRequests.complete(member)
	storage_changed.emit()
	crew_changed.emit()
	return true


# --- Carrière ----------------------------------------------------------------------

func grade_index() -> int:
	return Career.grade_index_for(merit)


func grade() -> GradeData:
	return Career.GRADES[grade_index()]


## Ajoute du mérite. Renvoie les grades obtenus (leur talent est à choisir).
func add_merit(amount: int) -> Array[GradeData]:
	var gained: Array[GradeData] = []
	if amount <= 0:
		return gained
	var before: int = grade_index()
	merit += amount
	for i: int in range(before + 1, grade_index() + 1):
		gained.append(Career.GRADES[i])
		pending_promotions.append(Career.GRADES[i])
	career_changed.emit()
	return gained


## Choisit le talent de la plus ancienne promotion en attente.
func choose_perk(perk: PerkData) -> bool:
	if pending_promotions.is_empty() or not perk in pending_promotions[0].perks:
		return false
	perks.append(perk)
	pending_promotions.pop_front()
	career_changed.emit()
	return true


## Somme d'un bonus de talent (nom de propriété de PerkData : &"max_health", &"armor"...).
func perk_bonus(stat: StringName) -> float:
	return Career.bonus(perks, stat)


## PV max : base + talents − palier d'infection.
## Armure totale : équipement porté + talents.
func armor() -> int:
	return loadout.armor() + int(perk_bonus(&"armor"))


## Protection contre l'exposition : équipement porté + talents (plafonnée).
func protection() -> float:
	return minf(loadout.protection() + perk_bonus(&"protection"), Loadout.MAX_PROTECTION)


func max_health() -> int:
	return maxi(BASE_HEALTH + int(perk_bonus(&"max_health")) - Infection.health_malus(infection), 1)


## Taille du sac : celle du sac porté, plus les talents.
func bag_capacity() -> int:
	return loadout.capacity() + int(perk_bonus(&"capacity"))


# --- Train ------------------------------------------------------------------------

## Voitures que la locomotive peut tirer (cabine comprise).
func max_cars() -> int:
	return TrainRules.max_cars(locomotive_level)


func beds() -> int:
	return TrainRules.beds(train, wagon_levels)


## Couchettes libres : combien de recrues le train peut encore accueillir.
func free_beds() -> int:
	return maxi(beds() - crew.size(), 0)


func storage_capacity() -> int:
	return TrainRules.storage_capacity(train, wagon_levels)


func wagon_level(id: StringName) -> int:
	return wagon_levels.get(id, 1)


## Combien de voitures de ce type dans le train.
func wagon_count(id: StringName) -> int:
	var count: int = 0
	for wagon: WagonData in train:
		if wagon.id == id:
			count += 1
	return count


## Pourquoi on ne peut pas agrandir ce type de voiture (Problem.NONE = c'est possible).
func upgrade_wagon_problem(wagon: WagonData) -> TrainRules.Problem:
	var next: WagonUpgrade = wagon.upgrade_to(wagon_level(wagon.id) + 1)
	return TrainRules.upgrade_wagon_problem(wagon, wagon_level(wagon.id), wagon_count(wagon.id), storage,
		next == null or is_known(next.plan))


## Agrandit toutes les voitures d'un type (niveau suivant), avec le stock.
func upgrade_wagon(wagon: WagonData) -> bool:
	if wagon_count(wagon.id) == 0 or upgrade_wagon_problem(wagon) != TrainRules.Problem.NONE:
		return false
	var level: int = wagon_level(wagon.id) + 1
	TrainRules.pay(TrainRules.upgrade_cost(wagon, level, wagon_count(wagon.id)), storage)
	wagon_levels[wagon.id] = level
	storage_changed.emit()
	train_changed.emit()
	return true


func storage_free() -> int:
	return maxi(storage_capacity() - storage_total(), 0)


## Construit une voiture avec le stock. Elle s'attelle en queue du train.
func build_wagon(wagon: WagonData) -> bool:
	if TrainRules.build_problem(wagon, train, locomotive_level, storage, is_known(wagon.plan)) != TrainRules.Problem.NONE:
		return false
	TrainRules.pay(wagon.cost, storage)
	train.insert(0, wagon)
	storage_changed.emit()
	train_changed.emit()
	return true


## Prend une offre de gare refuge (échange ou recrue), payée avec le stock.
## `done` : offre déjà prise pendant ce passage. Renvoie false si c'est impossible.
func use_refuge_offer(offer: RefugeOffer, rng: RandomNumberGenerator, done: bool = false) -> bool:
	if RefugeRules.problem(offer, storage, storage_free(), free_beds(), done or knows_plan(offer.reward_plan)) != RefugeRules.Problem.NONE:
		return false
	var recruit: CrewMember = RefugeRules.apply(offer, storage, rng, crew_names())
	add_plan(offer.reward_plan)
	storage_changed.emit()
	if recruit:
		crew.append(recruit)
		crew_changed.emit()
	return true


## Renforce la locomotive : elle tire une voiture de plus. Se fait au dépôt d'une
## gare refuge (c'est l'interface de la gare qui le propose).
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


# --- Sauvegarde -------------------------------------------------------------------

## Toute la partie en dictionnaire simple (JSON). Les données de jeu (.tres) sont
## enregistrées par leur id.
func to_save() -> Dictionary:
	var crew_data: Array[Dictionary] = []
	for member: CrewMember in crew:
		crew_data.append(member.to_dict())
	var equipped: Array[String] = []
	for item: ItemData in loadout.equipped.values():
		equipped.append(String(item.id))
	return {
		"version": SAVE_VERSION,
		"label": "Jour %d · Arrêt n°%d : %s" % [DayClock.day(clock_minutes), stop_number,
			region().display_name if has_route_choice() else stop_name()],
		"stop_number": stop_number,
		"zone": String(current_zone.id) if current_zone else "",
		"refuge": String(current_refuge.id) if current_refuge else "",
		# Entiers 64 bits en texte : le JSON les arrondirait.
		"seed": str(current_seed),
		"rng_seed": str(_rng.seed),
		"rng_state": str(_rng.state),
		"storage": storage,
		"crew": crew_data,
		"items": owned_items.map(func(item: ItemData) -> String: return String(item.id)),
		"equipped": equipped,
		"train": train.map(func(wagon: WagonData) -> String: return String(wagon.id)),
		"locomotive_level": locomotive_level,
		"wagon_levels": wagon_levels,
		"merit": merit,
		"perks": perks.map(func(perk: PerkData) -> String: return String(perk.id)),
		"pending_promotions": pending_promotions.map(func(g: GradeData) -> String: return String(g.id)),
		"infection": infection,
		"train_condition": train_condition,
		"clock": clock_minutes,
		"found_plans": found_plans.map(func(id: StringName) -> String: return String(id)),
		"researched_plans": researched_plans.map(func(id: StringName) -> String: return String(id)),
		"order": String(current_order.data.id) if current_order else "",
		"order_amount": current_order.amount if current_order else 0,
		"route": route_options.map(func(option: StopOption) -> Dictionary: return {
			"zone": String(option.zone.id),
			"seed": str(option.seed),
			"order": String(option.order.data.id) if option.order else "",
			"order_amount": option.order.amount if option.order else 0,
			"event": String(option.event.id) if option.event else "",
			"scouted": option.scouted,
			"horde_spotted": option.horde_spotted,
		}),
		"event": String(current_event.id) if current_event else "",
	}


## Recharge une partie. Renvoie false (et ne change rien) si la sauvegarde est illisible.
func load_save(data: Dictionary) -> bool:
	if int(data.get("version", 0)) != SAVE_VERSION or not data.has("stop_number"):
		return false
	var zone: ZoneProfile = _find_by_id(ZONES, data.get("zone", ""))
	var refuge: RefugeData = _find_by_id(REFUGES, data.get("refuge", ""))
	if zone == null and refuge == null:
		return false
	stop_number = int(data["stop_number"])
	current_zone = zone
	current_refuge = refuge
	current_seed = str(data.get("seed", "0")).to_int()
	_rng.seed = str(data.get("rng_seed", "0")).to_int()
	_rng.state = str(data.get("rng_state", "0")).to_int()
	storage.clear()
	var saved_storage: Dictionary = data.get("storage", {})
	for id: String in saved_storage:
		storage[StringName(id)] = int(saved_storage[id])
	crew.clear()
	for entry: Dictionary in data.get("crew", []):
		crew.append(CrewMember.from_dict(entry))
	owned_items.clear()
	for id: String in data.get("items", []):
		var item: ItemData = ItemCatalog.get_item(StringName(id))
		if item:
			owned_items.append(item)
	loadout = Loadout.new()
	for id: String in data.get("equipped", []):
		var item: ItemData = ItemCatalog.get_item(StringName(id))
		if item:
			loadout.equip(item)
	train.clear()
	for id: String in data.get("train", []):
		var wagon: WagonData = _find_by_id(WAGON_TYPES, id)
		if wagon:
			train.append(wagon)
	if train.is_empty():
		train = START_TRAIN.duplicate()
	locomotive_level = clampi(int(data.get("locomotive_level", 1)), 1, TrainRules.max_level())
	wagon_levels.clear()
	var saved_levels: Dictionary = data.get("wagon_levels", {})
	for id: String in saved_levels:
		var wagon: WagonData = _find_by_id(WAGON_TYPES, id)
		if wagon:
			wagon_levels[StringName(id)] = clampi(int(saved_levels[id]), 1, wagon.max_level())
	merit = int(data.get("merit", 0))
	perks.clear()
	for id: String in data.get("perks", []):
		var perk: PerkData = Career.find_perk(StringName(id))
		if perk:
			perks.append(perk)
	pending_promotions.clear()
	for id: String in data.get("pending_promotions", []):
		var promotion: GradeData = _find_by_id(Career.GRADES, id)
		if promotion:
			pending_promotions.append(promotion)
	infection = clampf(float(data.get("infection", 0.0)), 0.0, 1.0)
	train_condition = clampf(float(data.get("train_condition", 1.0)), 0.0, 1.0)
	clock_minutes = maxi(int(data.get("clock", DayClock.START_MINUTES)), 0)
	found_plans.clear()
	for id: String in data.get("found_plans", []):
		found_plans.append(StringName(id))
	researched_plans.clear()
	for id: String in data.get("researched_plans", []):
		researched_plans.append(StringName(id))
	var order_data: OrderData = CaptainOrders.find(StringName(data.get("order", "")))
	current_order = CaptainOrders.Order.new(order_data, int(data.get("order_amount", 0))) if order_data else null
	# Voies de l'aiguillage (anciennes sauvegardes : la seule voie est l'arrêt enregistré).
	route_options.clear()
	for entry: Dictionary in data.get("route", []):
		var option_zone: ZoneProfile = _find_by_id(ZONES, entry.get("zone", ""))
		if option_zone == null:
			continue
		var option_order_data: OrderData = CaptainOrders.find(StringName(entry.get("order", "")))
		var option := StopOption.new(option_zone, str(entry.get("seed", "0")).to_int(),
			CaptainOrders.Order.new(option_order_data, int(entry.get("order_amount", 0))) if option_order_data else null,
			_find_by_id(EVENTS, entry.get("event", "")))
		option.scouted = bool(entry.get("scouted", false))
		option.horde_spotted = bool(entry.get("horde_spotted", false))
		route_options.append(option)
	current_event = _find_by_id(EVENTS, data.get("event", ""))
	if route_options.is_empty() and current_zone and current_refuge == null:
		route_options.append(StopOption.new(current_zone, current_seed, current_order, current_event))
	storage_changed.emit()
	crew_changed.emit()
	equipment_changed.emit()
	train_changed.emit()
	career_changed.emit()
	infection_changed.emit()
	plans_changed.emit()
	return true


static func _find_by_id(list: Array, id: String) -> Resource:
	for entry: Resource in list:
		if String(entry.get(&"id")) == id:
			return entry
	return null


## Tirage pondéré de `count` types d'arrêt différents dans une région, en évitant si
## possible de reprendre celui qu'on vient de faire.
func _pick_zones(biome: BiomeData, previous: ZoneProfile, count: int) -> Array[ZoneProfile]:
	var candidates: Array[ZoneProfile] = []
	for zone: ZoneProfile in ZONES:
		if zone.biome == biome and zone != previous:
			candidates.append(zone)
	if candidates.size() < count:
		for zone: ZoneProfile in ZONES:
			if zone.biome == biome and not zone in candidates:
				candidates.append(zone)
	var picked: Array[ZoneProfile] = []
	while picked.size() < count and not candidates.is_empty():
		var total: float = 0.0
		for zone: ZoneProfile in candidates:
			total += zone.weight
		var roll: float = _rng.randf() * total
		var chosen: ZoneProfile = candidates.back()
		for zone: ZoneProfile in candidates:
			roll -= zone.weight
			if roll <= 0.0:
				chosen = zone
				break
		picked.append(chosen)
		candidates.erase(chosen)
	return picked
