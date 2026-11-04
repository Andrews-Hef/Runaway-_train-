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

## Numéro de l'arrêt en cours ou à venir (1 = premier arrêt).
var stop_number: int = 0
## Type de zone de l'arrêt (le dernier tiré, si l'arrêt est une gare refuge).
var current_zone: ZoneProfile
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


## Tire le prochain arrêt : gare refuge (tous les REFUGE_EVERY arrêts) ou type de
## zone, et graine de génération.
func prepare_next_stop() -> void:
	# On quitte un arrêt : les machines du train travaillent pendant le trajet.
	last_production.clear()
	if stop_number >= 1:
		last_production = run_machines()
	stop_number += 1
	if stop_number % REFUGE_EVERY == 0:
		current_refuge = REFUGES[(stop_number / REFUGE_EVERY - 1) % REFUGES.size()]
	else:
		current_refuge = null
		current_zone = FIRST_ZONE if stop_number == 1 else _pick_zone(current_zone)
	current_seed = _rng.randi()
	# L'ordre a son propre hasard, tiré de la graine de l'arrêt : il ne change pas le voyage.
	current_order = null
	if current_refuge == null:
		var order_rng := RandomNumberGenerator.new()
		order_rng.seed = current_seed + 7
		current_order = CaptainOrders.pick(current_zone, stop_number, order_rng, bag_capacity())
	career_changed.emit()


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
	result.merit_gained = result.kill_merit() + (current_order.data.merit if result.order_completed else 0)
	result.promotions = add_merit(result.merit_gained)
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
		return "Il faut une infirmerie (onglet Train)."
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
		crew_data.append({"name": member.display_name, "role": member.role, "role_label": member.role_label, "infected": member.infected})
	var equipped: Array[String] = []
	for item: ItemData in loadout.equipped.values():
		equipped.append(String(item.id))
	return {
		"version": SAVE_VERSION,
		"label": "Arrêt n°%d : %s" % [stop_number, stop_name()],
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
		"found_plans": found_plans.map(func(id: StringName) -> String: return String(id)),
		"researched_plans": researched_plans.map(func(id: StringName) -> String: return String(id)),
		"order": String(current_order.data.id) if current_order else "",
		"order_amount": current_order.amount if current_order else 0,
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
		crew.append(CrewMember.create(entry["name"], StringName(entry["role"]), entry["role_label"], bool(entry["infected"])))
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
	found_plans.clear()
	for id: String in data.get("found_plans", []):
		found_plans.append(StringName(id))
	researched_plans.clear()
	for id: String in data.get("researched_plans", []):
		researched_plans.append(StringName(id))
	var order_data: OrderData = CaptainOrders.find(StringName(data.get("order", "")))
	current_order = CaptainOrders.Order.new(order_data, int(data.get("order_amount", 0))) if order_data else null
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
