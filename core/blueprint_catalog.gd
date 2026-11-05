class_name BlueprintCatalog
## Tous les plans, et les règles pour les étudier. Pur.

const ALL: Array[BlueprintData] = [
	preload("res://data/plans/metallurgy.tres"),
	preload("res://data/plans/chemistry.tres"),
	preload("res://data/plans/horticulture.tres"),
	preload("res://data/plans/torch.tres"),
	preload("res://data/plans/armory.tres"),
	preload("res://data/plans/pharmacy.tres"),
	preload("res://data/plans/distillery.tres"),
	preload("res://data/plans/outfitting.tres"),
	preload("res://data/plans/vaccine.tres"),
	preload("res://data/plans/intercom.tres"),
]


static func get_plan(id: StringName) -> BlueprintData:
	for plan: BlueprintData in ALL:
		if plan.id == id:
			return plan
	return null


## Pourquoi on ne peut pas encore l'étudier (vide = c'est possible).
static func research_problem(plan: BlueprintData, found: Array[StringName], researched: Array[StringName],
		storage: Dictionary[StringName, int]) -> String:
	if plan.id in researched:
		return "Déjà étudié."
	if not plan.id in found:
		return "Plan pas encore trouvé."
	var missing: PackedStringArray = []
	for required: StringName in plan.requires:
		if not required in researched:
			missing.append(get_plan(required).display_name)
	if not missing.is_empty():
		return "Étudie d'abord : " + ", ".join(missing)
	if not TrainRules.missing(plan.research_cost, storage).is_empty():
		return "Il manque des matériaux dans le stock."
	return ""


## Noms de ce que le plan débloque (équipements, recettes, voitures).
static func unlocks(plan_id: StringName) -> PackedStringArray:
	var names: PackedStringArray = []
	var plan: BlueprintData = get_plan(plan_id)
	if plan and not plan.effect_text.is_empty():
		names.append(plan.effect_text)
	for item: ItemData in ItemCatalog.ALL:
		if item.plan == plan_id:
			names.append(item.display_name)
	for recipe: RecipeData in RecipeCatalog.ALL:
		if recipe.plan == plan_id:
			names.append(recipe.display_name)
	for wagon: WagonData in GameState.WAGON_TYPES:
		if wagon.plan == plan_id:
			names.append("voiture " + wagon.display_name)
		for level: int in range(2, wagon.max_level() + 1):
			if wagon.upgrade_to(level).plan == plan_id:
				names.append("%s niv. %d" % [wagon.display_name, level])
	return names
