extends CanvasLayer
## Menu du train : stock, atelier (fabrication), équipement, équipage, train (construction),
## machines, plans, infirmerie.
##
## Un seul panneau à onglets. Chaque meuble du train l'ouvre sur SON onglet, seul :
## l'établi ne donne que l'atelier. Une fois le plan Interphone étudié, les postes
## sont reliés et tous les onglets s'affichent depuis n'importe quel meuble.
## Il lit et modifie GameState, rien d'autre.

signal closed

enum Tab { STOCK, WORKSHOP, EQUIPMENT, CREW, TRAIN, MACHINES, PLANS, INFIRMARY }

const GOOD: Color = MenuKit.GOOD
const BAD: Color = MenuKit.BAD
const MUTED: Color = MenuKit.MUTED
const GOLD: Color = MenuKit.GOLD

@onready var _root: Control = $Root
@onready var _tabs: TabContainer = %Tabs
@onready var _stock_list: VBoxContainer = %StockList
@onready var _workshop_list: VBoxContainer = %WorkshopList
@onready var _equipment_list: VBoxContainer = %EquipmentList
@onready var _crew_list: VBoxContainer = %CrewList
@onready var _train_list: VBoxContainer = %TrainList
@onready var _machines_list: VBoxContainer = %MachinesList
@onready var _plans_list: VBoxContainer = %PlansList
@onready var _infirmary_list: VBoxContainer = %InfirmaryList
@onready var _close: Button = %Close
@onready var _hint: Label = %Hint


func _ready() -> void:
	_root.visible = false
	_close.pressed.connect(close)
	for signal_name: StringName in [&"storage_changed", &"equipment_changed", &"crew_changed", &"train_changed", &"career_changed",
			&"infection_changed", &"plans_changed"]:
		# Différé : un bouton ne doit pas être détruit pendant son propre clic.
		GameState.connect(signal_name, _refresh, CONNECT_DEFERRED)
	_tabs.set_tab_title(Tab.STOCK, "Stock")
	_tabs.set_tab_title(Tab.WORKSHOP, "Atelier")
	_tabs.set_tab_title(Tab.EQUIPMENT, "Équiper")
	_tabs.set_tab_title(Tab.CREW, "Équipage")
	_tabs.set_tab_title(Tab.TRAIN, "Train")
	_tabs.set_tab_title(Tab.MACHINES, "Machines")
	_tabs.set_tab_title(Tab.PLANS, "Plans")
	_tabs.set_tab_title(Tab.INFIRMARY, "Infirmerie")


func _unhandled_input(event: InputEvent) -> void:
	if _root.visible and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause")):
		close()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _root.visible


func open(tab: Tab) -> void:
	_refresh()
	var linked: bool = GameState.stations_linked()
	_tabs.current_tab = tab
	for i: int in _tabs.get_tab_count():
		_tabs.set_tab_hidden(i, not linked and i != tab)
	_hint.visible = not linked
	_root.visible = true
	_close.grab_focus.call_deferred()


func close() -> void:
	if not _root.visible:
		return
	_root.visible = false
	closed.emit()


func _refresh() -> void:
	_fill_stock()
	_fill_workshop()
	_fill_equipment()
	_fill_crew()
	_fill_train()
	_fill_machines()
	_fill_plans()
	_fill_infirmary()


# --- Stock ------------------------------------------------------------------------

func _fill_stock() -> void:
	MenuKit.clear(_stock_list)
	var full: bool = GameState.storage_free() == 0
	_stock_list.add_child(MenuKit.label("Places : %d/%d" % [GameState.storage_total(), GameState.storage_capacity()], BAD if full else GOLD))
	if full:
		_stock_list.add_child(MenuKit.label("Stock plein : construis un wagon de stock (plans du train, dans la cabine).", BAD))
	for loot: LootData in GameState.LOOT_TYPES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 4)
		var icon := TextureRect.new()
		icon.texture = loot.icon
		icon.custom_minimum_size = Vector2(12.0, 12.0)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		row.add_child(MenuKit.label("%s : %d" % [loot.display_name, GameState.storage_amount(loot.id)]))
		_stock_list.add_child(row)
	_stock_list.add_child(MenuKit.label("Équipements à bord : %d" % GameState.owned_items.size(), MUTED))


# --- Atelier ----------------------------------------------------------------------

func _fill_workshop() -> void:
	MenuKit.clear(_workshop_list)
	var hidden: int = 0
	_workshop_list.add_child(MenuKit.label("Équipement", GOLD))
	for item: ItemData in ItemCatalog.craftables():
		if not GameState.is_known(item.plan):
			hidden += 1
			continue
		var owned: bool = item in GameState.owned_items
		var lacking := Crafting.missing(item, GameState.storage)
		var row := HBoxContainer.new()
		row.add_child(MenuKit.icon(item.icon, 24.0))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override(&"separation", 0)
		info.add_child(MenuKit.label("%s (%s) — %s" % [item.display_name, item.slot_name(), item.describe_effects()]))
		info.add_child(MenuKit.label("Coût : " + MenuKit.describe_amounts(item.recipe), MUTED if owned else (GOOD if lacking.is_empty() else BAD)))
		row.add_child(info)
		var button := Button.new()
		button.custom_minimum_size = Vector2(64.0, 18.0)
		if owned:
			button.text = "Possédé"
			button.disabled = true
		else:
			button.text = "Fabriquer"
			button.disabled = not lacking.is_empty()
			button.pressed.connect(func() -> void: GameState.craft(item))
		row.add_child(button)
		_workshop_list.add_child(row)
	# Transformations : ferraille en plaques, sève en produits chimiques...
	var recipes: Array[RecipeData] = RecipeCatalog.for_station(RecipeData.Station.WORKBENCH)
	_workshop_list.add_child(MenuKit.label("Transformer", GOLD))
	for recipe: RecipeData in recipes:
		if not GameState.is_known(recipe.plan):
			hidden += 1
			continue
		_workshop_list.add_child(_recipe_row(recipe, "Transformer"))
	if hidden > 0:
		_workshop_list.add_child(MenuKit.label("%d recette(s) encore inconnue(s) : trouve des plans et étudie-les (table des plans)." % hidden, MUTED))


# --- Équipement -------------------------------------------------------------------

func _fill_equipment() -> void:
	MenuKit.clear(_equipment_list)
	var loadout: Loadout = GameState.loadout
	_equipment_list.add_child(MenuKit.label(loadout.describe(), GOLD))
	for slot: int in ItemData.Slot.values():
		var options: Array[ItemData] = GameState.owned_for_slot(slot)
		var current: ItemData = loadout.get_item(slot)
		var row := HBoxContainer.new()
		var picture := MenuKit.icon(current.icon if current else null, 24.0)
		row.add_child(picture)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override(&"separation", 0)
		var name_text: String = current.display_name if current else "rien"
		info.add_child(MenuKit.label("%s : %s" % [ItemData.SLOT_NAMES[slot], name_text]))
		info.add_child(MenuKit.label(current.describe_effects() if current else "Fabrique-en un à l'atelier.", MUTED))
		row.add_child(info)
		var button := Button.new()
		button.custom_minimum_size = Vector2(64.0, 18.0)
		button.text = "Changer (%d)" % options.size()
		button.disabled = options.size() < 2
		button.pressed.connect(func() -> void: _cycle(slot))
		row.add_child(button)
		_equipment_list.add_child(row)


## Passe à l'équipement suivant possédé pour cet emplacement.
func _cycle(slot: int) -> void:
	var options: Array[ItemData] = GameState.owned_for_slot(slot)
	if options.is_empty():
		return
	var index: int = options.find(GameState.loadout.get_item(slot))
	GameState.equip(options[(index + 1) % options.size()])


# --- Équipage ---------------------------------------------------------------------

func _fill_crew() -> void:
	MenuKit.clear(_crew_list)
	var full: bool = GameState.free_beds() == 0
	_crew_list.add_child(MenuKit.label("Couchettes : %d/%d" % [GameState.crew.size(), GameState.beds()], BAD if full else GOLD))
	if full:
		_crew_list.add_child(MenuKit.label("Plus de place : construis un dortoir (plans du train, dans la cabine) pour recruter.", BAD))
	if GameState.crew.is_empty():
		_crew_list.add_child(MenuKit.label("Personne à bord pour l'instant.", MUTED))
		_crew_list.add_child(MenuKit.label("Recrute des survivants dans les refuges pendant les sorties.", MUTED))
		return
	for member: CrewMember in GameState.crew:
		_crew_list.add_child(MenuKit.label("%s — %s" % [member.display_name, member.role_label]))


## Une recette de transformation : coût → produit, avec la raison si c'est impossible.
func _recipe_row(recipe: RecipeData, verb: String) -> HBoxContainer:
	var problem: String = GameState.recipe_problem(recipe)
	var detail: String = "%s → %s" % [MenuKit.describe_amounts(recipe.cost), MenuKit.describe_amounts(recipe.output)]
	if not problem.is_empty() and problem != "Il manque des matériaux dans le stock.":
		detail += " · " + problem
	return MenuKit.row(recipe.display_name, detail, GOOD if problem.is_empty() else BAD, verb, not problem.is_empty(),
		func() -> void: GameState.make_recipe(recipe))


# --- Plans -------------------------------------------------------------------------

func _fill_plans() -> void:
	MenuKit.clear(_plans_list)
	var unknown: int = BlueprintCatalog.ALL.size() - GameState.found_plans.size() - GameState.researched_plans.size()
	_plans_list.add_child(MenuKit.label("Étudie les plans trouvés pour débloquer recettes, outils et voitures.", MUTED))
	if GameState.found_plans.is_empty():
		_plans_list.add_child(MenuKit.label("Aucun plan à étudier : fouille les caisses et les armoires, ou achète-en aux marchands et en gare.", MUTED))
	for plan_id: StringName in GameState.found_plans:
		var plan: BlueprintData = BlueprintCatalog.get_plan(plan_id)
		var problem: String = BlueprintCatalog.research_problem(plan, GameState.found_plans, GameState.researched_plans, GameState.storage)
		var detail: String = "Débloque : %s · Coût : %s" % [", ".join(BlueprintCatalog.unlocks(plan.id)), MenuKit.describe_amounts(plan.research_cost)]
		if not problem.is_empty() and problem != "Il manque des matériaux dans le stock.":
			detail += " · " + problem
		_plans_list.add_child(MenuKit.row("Plan : " + plan.display_name, detail, GOOD if problem.is_empty() else BAD,
			"Étudier", not problem.is_empty(), func() -> void: GameState.research(plan)))
	if not GameState.researched_plans.is_empty():
		_plans_list.add_child(MenuKit.label("Étudiés", GOLD))
		for plan_id: StringName in GameState.researched_plans:
			var plan: BlueprintData = BlueprintCatalog.get_plan(plan_id)
			_plans_list.add_child(MenuKit.label("%s : %s" % [plan.display_name, ", ".join(BlueprintCatalog.unlocks(plan.id))], Color.WHITE))
	if unknown > 0:
		_plans_list.add_child(MenuKit.label("%d plan(s) encore à trouver." % unknown, MUTED))


# --- Infirmerie --------------------------------------------------------------------

func _fill_infirmary() -> void:
	MenuKit.clear(_infirmary_list)
	_infirmary_list.add_child(MenuKit.label("Infection : " + Infection.describe(GameState.infection), Infection.color(GameState.infection)))
	_infirmary_list.add_child(MenuKit.label("Elle ne baisse pas toute seule. À 100 %, tu rejoins la ruche.", MUTED))
	var any_medicine: bool = false
	for loot: LootData in GameState.LOOT_TYPES:
		if not loot.is_medicine():
			continue
		var amount: int = GameState.storage_amount(loot.id)
		if amount <= 0:
			continue
		any_medicine = true
		_infirmary_list.add_child(MenuKit.row("%s (×%d)" % [loot.display_name, amount], "Infection −%d %%" % roundi(loot.cure * 100.0),
			GOOD, "Prendre", GameState.infection <= 0.0, func() -> void: GameState.take_medicine(loot)))
	if not any_medicine:
		_infirmary_list.add_child(MenuKit.label("Aucun médicament à bord : fouille les caisses et les armoires, ou achète-en en gare.", MUTED))
	_infirmary_list.add_child(MenuKit.label("Médicaments spéciaux", GOLD))
	if not GameState.has_wagon(&"infirmary"):
		_infirmary_list.add_child(MenuKit.label("Construis une infirmerie (plans du train, dans la cabine) pour les préparer.", MUTED))
	var hidden: int = 0
	for recipe: RecipeData in RecipeCatalog.for_station(RecipeData.Station.INFIRMARY):
		if not GameState.is_known(recipe.plan):
			hidden += 1
			continue
		_infirmary_list.add_child(_recipe_row(recipe, "Préparer"))
	if hidden > 0:
		_infirmary_list.add_child(MenuKit.label("%d préparation(s) encore inconnue(s) : il faut des plans (Pharmacie…)." % hidden, MUTED))


# --- Machines ---------------------------------------------------------------------

## Serre et laboratoire : ce qu'ils produisent à chaque trajet, et le dernier bilan.
func _fill_machines() -> void:
	MenuKit.clear(_machines_list)
	_machines_list.add_child(MenuKit.label("Les machines tournent pendant chaque trajet, avec ce qu'il y a dans le stock.", MUTED))
	var shown: Array[StringName] = []
	for wagon: WagonData in GameState.train:
		if wagon.id in shown:
			continue
		var level: int = GameState.wagon_level(wagon.id)
		var production: Dictionary[StringName, int] = wagon.production_at(level)
		if production.is_empty():
			continue
		shown.append(wagon.id)
		var count: int = GameState.wagon_count(wagon.id)
		var title: String = "%s niv. %d" % [wagon.display_name, level] + (" (×%d voitures)" % count if count > 1 else "")
		var detail: String = "Chaque trajet : %s" % MenuKit.describe_amounts(production)
		var ready: bool = true
		if not wagon.production_cost.is_empty():
			detail += " · consomme %s" % MenuKit.describe_amounts(wagon.production_cost)
			ready = TrainRules.missing(wagon.production_cost, GameState.storage).is_empty()
			if not ready:
				detail += " · il en manque dans le stock"
		var info := VBoxContainer.new()
		info.add_theme_constant_override(&"separation", 0)
		info.add_child(MenuKit.label(title))
		info.add_child(MenuKit.label(detail, GOOD if ready else BAD))
		_machines_list.add_child(info)
	if shown.is_empty():
		_machines_list.add_child(MenuKit.label("Aucune machine à bord : une serre (plan Horticulture) ou un laboratoire (plan Distillerie) se construisent dans la cabine.", MUTED))
	if not GameState.last_production.is_empty():
		_machines_list.add_child(MenuKit.label("Dernier trajet : +" + MenuKit.describe_amounts(GameState.last_production), GOLD))


# --- Train ------------------------------------------------------------------------

func _fill_train() -> void:
	MenuKit.clear(_train_list)
	var names: PackedStringArray = []
	for wagon: WagonData in GameState.train:
		names.append(wagon.display_name)
	_train_list.add_child(MenuKit.label("Voitures : %d/%d — %s" % [GameState.train.size(), GameState.max_cars(), " · ".join(names)], GOLD))
	_train_list.add_child(MenuKit.label("Couchettes : %d/%d · Stock : %d/%d" % [
		GameState.crew.size(), GameState.beds(), GameState.storage_total(), GameState.storage_capacity()], MUTED))

	# Locomotive : elle fixe le nombre de voitures. Le renfort se fait au dépôt d'une gare refuge.
	var next: LocomotiveLevel = TrainRules.next_level(GameState.locomotive_level)
	var loco_title: String = "Locomotive niv. %d — tire %d voitures" % [GameState.locomotive_level, GameState.max_cars()]
	var loco_detail: String = "Niveau maximum."
	if next:
		loco_detail = "Renfort (niv. %d, %d voitures) au dépôt de la prochaine gare refuge : arrêt n°%d." % [
			next.level, next.max_cars, GameState.next_refuge_stop()]
	_train_list.add_child(MenuKit.row(loco_title, loco_detail, MUTED, "Au dépôt", true, Callable()))

	# Voitures à construire : elles s'attellent en queue.
	for wagon: WagonData in GameState.BUILDABLE_WAGONS:
		var plan_known: bool = GameState.is_known(wagon.plan)
		var problem: TrainRules.Problem = TrainRules.build_problem(wagon, GameState.train, GameState.locomotive_level,
			GameState.storage, plan_known)
		if problem == TrainRules.Problem.ALREADY_THERE:
			continue # déjà dans le train (voiture unique)
		var detail: String = "Coût : " + MenuKit.describe_amounts(wagon.cost)
		if problem == TrainRules.Problem.NO_TRACTION:
			detail = TrainRules.PROBLEM_TEXTS[problem]
		elif problem == TrainRules.Problem.NEEDS_PLAN:
			detail = "Plan à étudier : " + BlueprintCatalog.get_plan(wagon.plan).display_name
		_train_list.add_child(MenuKit.row(
			"%s (%s)" % [wagon.display_name, wagon.describe_effects()], detail,
			GOOD if problem == TrainRules.Problem.NONE else BAD,
			"Construire", problem != TrainRules.Problem.NONE, func() -> void: GameState.build_wagon(wagon)))

	# Agrandir : chaque type de voiture du train, au niveau suivant (toutes ses voitures).
	var shown: Array[StringName] = []
	for wagon: WagonData in GameState.train:
		if wagon.upgrades.is_empty() or wagon.id in shown:
			continue
		shown.append(wagon.id)
		if shown.size() == 1:
			_train_list.add_child(MenuKit.label("Agrandir", GOLD))
		var level: int = GameState.wagon_level(wagon.id)
		var count: int = GameState.wagon_count(wagon.id)
		var title: String = "%s niv. %d" % [wagon.display_name, level]
		if count > 1:
			title += " (×%d voitures)" % count
		var next_upgrade: WagonUpgrade = wagon.upgrade_to(level + 1)
		if next_upgrade == null:
			_train_list.add_child(MenuKit.row(title, "Niveau maximum.", MUTED, "Max", true, Callable()))
			continue
		var problem: TrainRules.Problem = GameState.upgrade_wagon_problem(wagon)
		var detail: String = "Niv. %d : %s · Coût : %s" % [level + 1, next_upgrade.describe(),
			MenuKit.describe_amounts(TrainRules.upgrade_cost(wagon, level + 1, count))]
		if problem == TrainRules.Problem.NEEDS_PLAN:
			detail = "Niv. %d : %s · Plan à étudier : %s" % [level + 1, next_upgrade.describe(), BlueprintCatalog.get_plan(next_upgrade.plan).display_name]
		_train_list.add_child(MenuKit.row(title, detail, GOOD if problem == TrainRules.Problem.NONE else BAD,
			"Agrandir", problem != TrainRules.Problem.NONE, func() -> void: GameState.upgrade_wagon(wagon)))
