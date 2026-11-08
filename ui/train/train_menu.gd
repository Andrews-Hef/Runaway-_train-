extends CanvasLayer
## Menu du train : stock, atelier (fabrication), équipement, équipage, train (construction),
## machines, plans, infirmerie, chaudière.
##
## Un seul panneau à onglets. Chaque meuble du train l'ouvre sur SON onglet, seul :
## l'établi ne donne que l'atelier. Une fois le plan Interphone étudié, les postes
## sont reliés et tous les onglets s'affichent depuis n'importe quel meuble.
##
## Peu de texte : chaque onglet montre des cases (ressources, recettes, voitures, plans)
## et des pastilles chiffrées. La case choisie s'explique dans la barre du bas, avec ses
## boutons (Fabriquer, Construire, Étudier...) ; le reste est dans les infobulles.
## Il lit et modifie GameState, rien d'autre.

signal closed

enum Tab { STOCK, WORKSHOP, EQUIPMENT, CREW, TRAIN, MACHINES, PLANS, INFIRMARY, BOILER }

const GOOD: Color = MenuKit.GOOD
const BAD: Color = MenuKit.BAD
const MUTED: Color = MenuKit.MUTED
const GOLD: Color = MenuKit.GOLD

const LOCK: Texture2D = preload("res://assets/ui/icons/lock.png")
const CHECK: Texture2D = preload("res://assets/ui/icons/check.png")
const PLUS: Texture2D = preload("res://assets/ui/icons/plus.png")
const CRATE: Texture2D = preload("res://assets/ui/icons/crate.png")
const BED: Texture2D = preload("res://assets/ui/icons/bed.png")
const WAGON: Texture2D = preload("res://assets/ui/icons/wagon.png")
const HAMMER: Texture2D = preload("res://assets/ui/icons/hammer.png")
const CROSS: Texture2D = preload("res://assets/ui/icons/cross.png")
const PLAN: Texture2D = preload("res://assets/ui/icons/plan.png")
const STAR: Texture2D = preload("res://assets/ui/icons/order.png")
const PARTNER: Texture2D = preload("res://assets/ui/icons/recruit.png")
const HEALTH: Texture2D = preload("res://assets/ui/icons/health.png")
const SPORE: Texture2D = preload("res://assets/ui/icons/infection.png")
const OUTFIT: Texture2D = preload("res://assets/ui/icons/items/outfit_padded.png")
const COAL: Texture2D = preload("res://assets/ui/icons/coal.png")
const MACHINE_ICONS: Array[Texture2D] = [preload("res://assets/ui/icons/sprout.png"), preload("res://assets/ui/icons/tubes.png")]

const MISSING_MATERIALS: String = "Il manque des matériaux dans le stock."

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
@onready var _boiler_list: VBoxContainer = %BoilerList
@onready var _detail_panel: PanelContainer = %DetailPanel
@onready var _detail: HBoxContainer = %Detail
@onready var _close: Button = %Close
@onready var _hint: Label = %Hint

## Case choisie dans chaque onglet (Tab → ressource, recette, voiture, plan, équipier...).
var _selection: Dictionary[int, Variant] = {}
## Les cases de chaque onglet : on les surligne sans tout reconstruire.
var _cells: Dictionary[int, Array] = {}
## Patient choisi à l'infirmerie : null = toi.
var _patient: CrewMember
## Fiche de l'équipier choisi (jauges, stats, équipement), sous les portraits.
var _crew_sheet: HBoxContainer


func _ready() -> void:
	_root.visible = false
	_close.pressed.connect(close)
	for signal_name: StringName in [&"storage_changed", &"equipment_changed", &"crew_changed", &"train_changed", &"career_changed",
			&"infection_changed", &"plans_changed", &"condition_changed", &"energy_changed"]:
		# Différé : un bouton ne doit pas être détruit pendant son propre clic.
		GameState.connect(signal_name, _refresh, CONNECT_DEFERRED)
	_tabs.tab_changed.connect(func(_tab: int) -> void: _fill_detail())
	_tabs.set_tab_title(Tab.STOCK, "Stock")
	_tabs.set_tab_title(Tab.WORKSHOP, "Atelier")
	_tabs.set_tab_title(Tab.EQUIPMENT, "Équiper")
	_tabs.set_tab_title(Tab.CREW, "Équipage")
	_tabs.set_tab_title(Tab.TRAIN, "Train")
	_tabs.set_tab_title(Tab.MACHINES, "Machines")
	_tabs.set_tab_title(Tab.PLANS, "Plans")
	_tabs.set_tab_title(Tab.INFIRMARY, "Infirmerie")
	_tabs.set_tab_title(Tab.BOILER, "Chaudière")


func _unhandled_input(event: InputEvent) -> void:
	if _root.visible and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause")):
		close()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _root.visible


func open(tab: Tab) -> void:
	var linked: bool = GameState.stations_linked()
	# Tout montrer, choisir l'onglet, puis cacher les autres : on ne peut ni choisir un
	# onglet caché, ni cacher l'onglet choisi.
	for i: int in _tabs.get_tab_count():
		_tabs.set_tab_hidden(i, false)
	_tabs.current_tab = tab
	for i: int in _tabs.get_tab_count():
		_tabs.set_tab_hidden(i, not linked and i != tab)
	_refresh()
	_hint.visible = not linked
	_root.visible = true
	# Manette, clavier : on part de la case choisie (sinon du bouton Fermer).
	if not _focus_cell(tab, _selection.get(tab)):
		MenuKit.focus_later(_close)


func close() -> void:
	if not _root.visible:
		return
	_root.visible = false
	closed.emit()


## Reconstruit tous les onglets. Le focus reste sur la même case (ou sur la barre de détail)
## pour qu'une manette ne se perde pas après « Fabriquer ».
func _refresh() -> void:
	var focus_key: Variant = null
	var focus_on_cell: bool = false
	var focus_in_detail: bool = false
	var owner: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if owner and _root.is_ancestor_of(owner):
		if owner.get_parent() is SlotCell:
			focus_on_cell = true
			focus_key = (owner.get_parent() as SlotCell).key
		elif _detail.is_ancestor_of(owner):
			focus_in_detail = true
	_cells.clear()
	_fill_stock()
	_fill_workshop()
	_fill_equipment()
	_fill_crew()
	_fill_train()
	_fill_machines()
	_fill_plans()
	_fill_infirmary()
	_fill_boiler()
	_fill_detail()
	if focus_on_cell:
		_focus_cell(_tabs.current_tab, focus_key)
	elif focus_in_detail:
		_focus_detail()


# --- Cases et sélection -------------------------------------------------------------

## Une case de l'onglet `tab` qui représente `key` : la toucher l'explique en bas.
func _cell(tab: Tab, texture: Texture2D, key: Variant, tip: String, count: String = "") -> SlotCell:
	var cell := SlotCell.create(texture, count, tip)
	cell.key = key
	cell.chosen.connect(_select.bind(tab, key))
	cell.focused.connect(_select.bind(tab, key))
	if not _cells.has(tab):
		_cells[tab] = []
	_cells[tab].append(cell)
	return cell


func _select(tab: Tab, key: Variant) -> void:
	_selection[tab] = key
	_highlight(tab)
	if tab == Tab.CREW:
		_fill_crew_sheet()
	if tab == _tabs.current_tab:
		_fill_detail()


func _highlight(tab: Tab) -> void:
	for cell: SlotCell in _cells.get(tab, []):
		cell.set_selected(is_same(cell.key, _selection.get(tab)))


## Garde la case choisie si elle existe encore, sinon `preferred`, sinon la première.
func _ensure_selection(tab: Tab, preferred: Variant = null) -> void:
	var keys: Array = _cells.get(tab, []).map(func(cell: SlotCell) -> Variant: return cell.key)
	var current: Variant = _selection.get(tab)
	if not keys.any(func(key: Variant) -> bool: return is_same(key, current)):
		if preferred != null and keys.any(func(key: Variant) -> bool: return is_same(key, preferred)):
			_selection[tab] = preferred
		else:
			_selection[tab] = keys[0] if not keys.is_empty() else null
	_highlight(tab)


func _focus_cell(tab: int, key: Variant) -> bool:
	for cell: SlotCell in _cells.get(tab, []):
		if is_same(cell.key, key):
			MenuKit.focus_later(cell.button)
			return true
	return false


func _focus_detail() -> void:
	for node: Node in _detail.find_children("*", "Button", true, false):
		if not (node as Button).disabled:
			MenuKit.focus_later(node as Button)
			return
	MenuKit.focus_later(_close)


## La barre du bas : ce que la case choisie représente, et ce qu'on peut en faire.
func _fill_detail() -> void:
	MenuKit.clear(_detail)
	var key: Variant = _selection.get(_tabs.current_tab)
	match _tabs.current_tab:
		Tab.STOCK:
			_detail_stock(key)
		Tab.WORKSHOP:
			_detail_workshop(key)
		Tab.CREW:
			_detail_crew(key)
		Tab.TRAIN:
			_detail_train(key)
		Tab.PLANS:
			_detail_plan(key)
		Tab.INFIRMARY:
			_detail_infirmary(key)
		Tab.BOILER:
			_detail_boiler(key)
	_detail_panel.visible = _detail.get_child_count() > 0


static func _bar(value: float, color: Color, width: float) -> StageBar:
	var bar := StageBar.new()
	bar.custom_minimum_size = Vector2(width, 4.0)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.fill_color = color
	bar.value = value
	return bar


static func _plan_name(plan_id: StringName) -> String:
	var plan: BlueprintData = BlueprintCatalog.get_plan(plan_id)
	return plan.display_name if plan else String(plan_id)


## Une recette ou un équipement encore inconnu : quel plan étudier.
func _detail_locked(plan_id: StringName) -> void:
	MenuKit.detail_info(_detail, LOCK, "Recette inconnue", "Plan à étudier : %s (table des plans)." % _plan_name(plan_id))


# --- Stock ------------------------------------------------------------------------

func _fill_stock() -> void:
	MenuKit.clear(_stock_list)
	var total: int = GameState.storage_total()
	var capacity: int = GameState.storage_capacity()
	var full: bool = GameState.storage_free() == 0
	var head := MenuKit.header()
	head.add_child(MenuKit.chip(CRATE, "%d/%d" % [total, capacity], BAD if full else Color.WHITE, "Places dans le stock du train"))
	head.add_child(_bar(float(total) / maxf(capacity, 1.0), BAD if full else GOLD, 90.0))
	if full:
		head.add_child(MenuKit.label("Plein : construis une voiture de stock", BAD))
	head.add_child(MenuKit.chip(OUTFIT, str(GameState.owned_items.size()), MUTED, "Équipements à bord (dans l'inventaire)"))
	_stock_list.add_child(head)
	var grid := MenuKit.grid()
	for loot: LootData in GameState.LOOT_TYPES:
		var amount: int = GameState.storage_amount(loot.id)
		grid.add_child(_cell(Tab.STOCK, loot.icon, loot, "%s : %d" % [loot.display_name, amount],
			str(amount) if amount > 0 else "").set_dim(amount == 0))
	_stock_list.add_child(grid)
	_ensure_selection(Tab.STOCK)


func _detail_stock(key: Variant) -> void:
	if not key is LootData:
		return
	var loot: LootData = key
	MenuKit.detail_info(_detail, loot.icon, "%s ×%d" % [loot.display_name, GameState.storage_amount(loot.id)], loot.describe())


# --- Atelier ----------------------------------------------------------------------

func _fill_workshop() -> void:
	MenuKit.clear(_workshop_list)
	_workshop_list.add_child(MenuKit.section("Équipement"))
	var items := MenuKit.grid()
	for item: ItemData in ItemCatalog.craftables():
		if not GameState.is_known(item.plan):
			items.add_child(_cell(Tab.WORKSHOP, LOCK, item, "Recette inconnue"))
			continue
		var cell := _cell(Tab.WORKSHOP, item.icon, item, item.display_name)
		if item in GameState.owned_items:
			cell.set_corner(CHECK)
		elif not Crafting.missing(item, GameState.storage).is_empty():
			cell.set_dim(true)
		items.add_child(cell)
	_workshop_list.add_child(items)
	# Transformations : ferraille en plaques, sève en produits chimiques...
	_workshop_list.add_child(MenuKit.section("Transformer"))
	_workshop_list.add_child(_recipe_grid(Tab.WORKSHOP, RecipeData.Station.WORKBENCH))
	_ensure_selection(Tab.WORKSHOP)


## Les recettes d'un poste en cases : le produit et sa quantité (cadenas si inconnue).
func _recipe_grid(tab: Tab, station: RecipeData.Station) -> HFlowContainer:
	var grid := MenuKit.grid()
	for recipe: RecipeData in RecipeCatalog.for_station(station):
		if not GameState.is_known(recipe.plan):
			grid.add_child(_cell(tab, LOCK, recipe, "Recette inconnue"))
			continue
		var amount: int = 0
		for value: int in recipe.output.values():
			amount += value
		grid.add_child(_cell(tab, _recipe_icon(recipe), recipe, recipe.display_name, str(amount) if amount > 1 else "")
			.set_dim(not GameState.recipe_problem(recipe).is_empty()))
	return grid


static func _recipe_icon(recipe: RecipeData) -> Texture2D:
	for id: StringName in recipe.output:
		var loot: LootData = MenuKit.loot(id)
		if loot:
			return loot.icon
	return null


func _detail_workshop(key: Variant) -> void:
	if key is RecipeData:
		_detail_recipe(key as RecipeData, "Transformer")
		return
	if not key is ItemData:
		return
	var item: ItemData = key
	if not GameState.is_known(item.plan):
		_detail_locked(item.plan)
		return
	MenuKit.detail_info(_detail, item.icon, "%s · %s" % [item.display_name, item.slot_name()], item.describe_effects())
	if item in GameState.owned_items:
		_detail.add_child(MenuKit.label("Possédé", GOOD))
		return
	var lacking: Dictionary[StringName, int] = Crafting.missing(item, GameState.storage)
	_detail.add_child(MenuKit.cost_row(item.recipe, GameState.storage))
	_detail.add_child(MenuKit.action("Fabriquer", func() -> void: GameState.craft(item), not lacking.is_empty(),
		"Il manque : " + MenuKit.describe_amounts(lacking)))


## Une recette : ce qu'on donne → ce qu'on obtient, et la raison si c'est impossible.
func _detail_recipe(recipe: RecipeData, verb: String) -> void:
	if not GameState.is_known(recipe.plan):
		_detail_locked(recipe.plan)
		return
	var problem: String = GameState.recipe_problem(recipe)
	var note: String = problem if problem != MISSING_MATERIALS else ""
	MenuKit.detail_info(_detail, _recipe_icon(recipe), recipe.display_name, note, BAD)
	_detail.add_child(MenuKit.recipe_row(recipe.cost, recipe.output, GameState.storage))
	_detail.add_child(MenuKit.action(verb, func() -> void: GameState.make_recipe(recipe), not problem.is_empty(), problem))


# --- Équipement -------------------------------------------------------------------

func _fill_equipment() -> void:
	MenuKit.clear(_equipment_list)
	var worn := HBoxContainer.new()
	worn.add_theme_constant_override(&"separation", 2)
	for slot: ItemData.Slot in ItemData.Slot.values():
		var item: ItemData = GameState.loadout.get_item(slot)
		var tip: String = "%s : %s" % [ItemData.SLOT_NAMES[slot], item.display_name if item else "rien"]
		worn.add_child(SlotCell.create(item.icon if item else null, "", tip, false))
	_equipment_list.add_child(worn)
	_equipment_list.add_child(MenuKit.label("Il se change dans l'inventaire (touche I, ou le bouton Sac).", MUTED))
	var open_inventory := MenuKit.action("Ouvrir l'inventaire", func() -> void:
		close()
		GameMenu.open_inventory())
	open_inventory.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_equipment_list.add_child(open_inventory)


# --- Équipage ---------------------------------------------------------------------

func _fill_crew() -> void:
	MenuKit.clear(_crew_list)
	var full: bool = GameState.free_beds() == 0
	var head := MenuKit.header()
	head.add_child(MenuKit.chip(BED, "%d/%d" % [GameState.crew.size(), GameState.beds()], BAD if full else Color.WHITE,
		"Couchettes occupées" + (" : construis un dortoir pour recruter" if full else "")))
	# L'équipier de sortie : il fouille de son côté à chaque arrêt et rapporte sa part.
	var partner: CrewMember = GameState.companion if GameState.companion in GameState.crew else null
	if GameState.can(&"companion"):
		head.add_child(MenuKit.chip(PARTNER, "Sortie : " + (partner.display_name if partner else "seul"), GOLD if partner else MUTED,
			"Équipier de sortie : il descend avec toi à chaque arrêt, fouille de son côté (hors de vue) et te rejoint au train avec sa part."))
	if not GameState.can(&"crew"):
		head.add_child(MenuKit.chip(LOCK, Career.required_grade(&"crew"), MUTED,
			GameState.locked_text(&"crew") + " : il met au repos les épuisés et isole les infectés. Tu peux remplir leurs demandes."))
	_crew_list.add_child(head)
	if GameState.crew.is_empty():
		_crew_list.add_child(MenuKit.label("Personne à bord : recrute des survivants dans les refuges.", MUTED))
		_ensure_selection(Tab.CREW)
		return
	var grid := MenuKit.grid()
	grid.add_theme_constant_override(&"h_separation", 4)
	for member: CrewMember in GameState.crew:
		grid.add_child(_crew_tile(member))
	_crew_list.add_child(grid)
	_crew_sheet = HBoxContainer.new()
	_crew_sheet.name = "CrewSheet"
	_crew_sheet.add_theme_constant_override(&"separation", 12)
	_crew_list.add_child(_crew_sheet)
	_ensure_selection(Tab.CREW)
	_fill_crew_sheet()


## La fiche de l'équipier choisi : ses jauges, ses stats, ce qu'il porte.
func _fill_crew_sheet() -> void:
	if not is_instance_valid(_crew_sheet):
		return
	MenuKit.clear(_crew_sheet)
	var member: CrewMember = _selection.get(Tab.CREW) as CrewMember
	if member == null:
		return
	var gauges := GridContainer.new()
	gauges.columns = 2
	gauges.add_theme_constant_override(&"h_separation", 8)
	gauges.add_theme_constant_override(&"v_separation", 2)
	gauges.add_child(_gauge("Vie %d" % member.health, member.health / 100.0, Color(0.86, 0.27, 0.24)))
	gauges.add_child(_gauge("Infection " + member.infection_text(), member.visible_infection() / 100.0, Color(0.75, 0.42, 1.0)))
	gauges.add_child(_gauge("Fatigue %d" % member.fatigue, member.fatigue / 100.0, Color(0.85, 0.68, 0.3)))
	gauges.add_child(_gauge("Confiance %d" % member.trust, member.trust / 100.0, Color(0.45, 0.7, 0.95)))
	_crew_sheet.add_child(gauges)
	_crew_sheet.add_child(MenuKit.stats_grid(member))
	var gear := VBoxContainer.new()
	gear.add_theme_constant_override(&"separation", 2)
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override(&"separation", 2)
	for slot: ItemData.Slot in ItemData.Slot.values():
		var item: ItemData = member.loadout.get_item(slot)
		slots.add_child(SlotCell.create(item.icon if item else null, "", "%s : %s" % [
			ItemData.SLOT_NAMES[slot], item.display_name if item else "rien"], false, Vector2(22.0, 22.0)))
	gear.add_child(slots)
	gear.add_child(MenuKit.label("Armure %d · Prot. %d %% · Dégâts %d" % [member.loadout.armor(),
		roundi(member.loadout.protection() * 100.0), member.loadout.damage()], MUTED))
	_crew_sheet.add_child(gear)


## Un équipier : son portrait, une marque d'état, son nom, sa vie.
func _crew_tile(member: CrewMember) -> VBoxContainer:
	var tile := VBoxContainer.new()
	tile.add_theme_constant_override(&"separation", 1)
	tile.custom_minimum_size = Vector2(46.0, 0.0)
	var cell := _cell(Tab.CREW, CrewLooks.portrait(member.look), member, "%s (%s)" % [member.full_name(), member.role_label])
	cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var mark: Texture2D = _crew_mark(member)
	if mark:
		cell.set_corner(mark)
	tile.add_child(cell)
	# L'équipier de sortie a son nom en doré.
	var name_label := MenuKit.label(member.display_name, GOLD if member == GameState.companion else Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	tile.add_child(name_label)
	var bar := _bar(member.health / 100.0, Color(0.86, 0.27, 0.24), 30.0)
	bar.custom_minimum_size.y = 3.0
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.add_child(bar)
	return tile


## La marque la plus utile d'un coup d'œil : isolé, infecté, au repos, ou une demande.
static func _crew_mark(member: CrewMember) -> Texture2D:
	if member.quarantined:
		return CROSS
	if member.visible_infection() > 0:
		return SPORE
	if member.resting:
		return BED
	if member.has_request():
		return STAR
	return null


func _detail_crew(key: Variant) -> void:
	if not key is CrewMember:
		return
	var member: CrewMember = key
	_detail.add_child(MenuKit.icon(CrewLooks.portrait(member.look), SlotCell.ICON))
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", 2)
	_detail.add_child(column)
	var tags: PackedStringArray = CrewLife.status(member)
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 8)
	line.add_child(MenuKit.label("%s · %s%s" % [member.full_name(), member.role_label,
		(" · " + ", ".join(tags)) if not tags.is_empty() else ""], GOLD))
	column.add_child(line)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override(&"h_separation", 3)
	actions.add_theme_constant_override(&"v_separation", 2)
	column.add_child(actions)
	if member.has_request():
		# Sa demande : ce qu'il veut en cases quand c'est du stock, sa phrase en infobulle.
		var request := HBoxContainer.new()
		request.add_theme_constant_override(&"separation", 3)
		request.tooltip_text = CrewRequests.text(member)
		request.mouse_filter = Control.MOUSE_FILTER_STOP
		request.add_child(MenuKit.icon(STAR, 12.0))
		if member.request_kind == &"deliver":
			request.add_child(MenuKit.cost_row(CrewRequests.cost(member), GameState.storage))
		else:
			request.add_child(MenuKit.label(CrewRequests.text(member), Color(0.95, 0.88, 0.65)))
		request.add_child(MenuKit.label("%d trajet(s)" % member.request_left, MUTED))
		actions.add_child(request)
		if member.request_kind == &"deliver":
			actions.add_child(MenuKit.action("Donner", func() -> void: GameState.fulfil_request(member),
				not GameState.can_fulfil_request(member), "Il manque des matériaux dans le stock."))
	# L'équiper : dans l'inventaire, ouvert sur lui.
	actions.add_child(MenuKit.action("Équiper", func() -> void:
		close()
		GameMenu.open_inventory(GameMenu.InventoryTab.ITEMS, member)))
	# L'emmener en sortie (Caporal) : il fouille de son côté, hors de vue.
	var is_partner: bool = member == GameState.companion
	actions.add_child(MenuKit.action("Ne plus l'emmener" if is_partner else "Emmener en sortie",
		func() -> void: GameState.set_companion(null if is_partner else member), not GameState.can(&"companion"),
		GameState.locked_text(&"companion") if not GameState.can(&"companion")
			else "Il descend avec toi à chaque arrêt, fouille de son côté et te rejoint au train avec sa part."))
	# Diriger l'équipage : à partir de Sergent (avant, le capitaine décide).
	var command: bool = GameState.can(&"crew")
	var locked: String = GameState.locked_text(&"crew") if not command else ""
	actions.add_child(MenuKit.action("Panser", func() -> void: GameState.bandage(member),
		not command or not GameState.can_bandage(member), locked if not command else "1 tissu : soigne ses blessures"))
	var medicine: LootData = GameState.medicine_for_crew()
	actions.add_child(MenuKit.action("Soigner", func() -> void: GameState.medicate(member),
		not command or medicine == null or (member.infection_known and member.infection == 0),
		locked if not command else ("Donner : " + medicine.display_name.to_lower() if medicine else "Pas de médicament dans le stock")))
	actions.add_child(MenuKit.action("Au travail" if member.resting else "Repos", func() -> void: GameState.toggle_rest(member),
		not command, locked))
	actions.add_child(MenuKit.action("Libérer" if member.quarantined else "Isoler", func() -> void: GameState.toggle_quarantine(member),
		not command or not GameState.can_quarantine(member), locked if not command else "Quarantaine à l'infirmerie : il ne contamine plus personne"))
	# Renvoyer : on confirme d'un second clic (pas de renvoi par erreur).
	var confirm: bool = member.get_meta(&"confirm_dismiss", false)
	actions.add_child(MenuKit.action("Confirmer ?" if confirm else "Renvoyer", func() -> void:
		if member.get_meta(&"confirm_dismiss", false):
			member.remove_meta(&"confirm_dismiss")
			GameState.dismiss(member)
		else:
			member.set_meta(&"confirm_dismiss", true)
			_fill_detail.call_deferred(), not command, locked if not command else "Il descend au prochain arrêt"))


static func _gauge(text: String, value: float, color: Color) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 1)
	box.add_child(MenuKit.label(text, MUTED))
	box.add_child(_bar(value, color, 64.0))
	return box


# --- Train ------------------------------------------------------------------------

func _fill_train() -> void:
	MenuKit.clear(_train_list)
	var head := MenuKit.header()
	head.add_child(MenuKit.chip(WAGON, "%d/%d" % [GameState.train.size(), GameState.max_cars()], Color.WHITE,
		"Voitures attelées / ce que la locomotive peut tirer"))
	head.add_child(MenuKit.chip(BED, "%d/%d" % [GameState.crew.size(), GameState.beds()], Color.WHITE, "Couchettes"))
	head.add_child(MenuKit.chip(CRATE, "%d/%d" % [GameState.storage_total(), GameState.storage_capacity()], Color.WHITE, "Stock"))
	head.add_child(MenuKit.chip(HAMMER, "%d %%" % roundi(GameState.train_condition * 100.0), _condition_color(),
		"État du train : %s.\nChaque mécanicien répare %d %% par trajet (%d au plus). Réparation complète au dépôt des gares refuges." % [
			GameState.describe_condition(), roundi(GameState.MECHANIC_REPAIR * 100.0), GameState.MAX_MECHANICS]))
	if not GameState.can(&"build"):
		head.add_child(MenuKit.chip(LOCK, Career.required_grade(&"build"), MUTED, GameState.locked_text(&"build")))
	_train_list.add_child(head)

	# Le train, de la queue à la tête : places libres (on attelle en queue), voitures, cabine.
	_train_list.add_child(MenuKit.section("Le train"))
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override(&"separation", 2)
	for i: int in maxi(GameState.max_cars() - GameState.train.size(), 0):
		strip.add_child(_cell(Tab.TRAIN, PLUS, &"free", "Place libre").set_dim(true))
	var cabin: WagonData = null
	for wagon: WagonData in GameState.train:
		var level: int = GameState.wagon_level(wagon.id)
		# Le niveau ne s'affiche qu'une fois la voiture agrandie.
		var cell := _cell(Tab.TRAIN, wagon.icon, wagon, "%s niv. %d" % [wagon.display_name, level],
			str(level) if level > 1 else "")
		cell.set_count_color(GOLD)
		strip.add_child(cell)
		if wagon.id == &"cabin":
			cabin = wagon
	_train_list.add_child(strip)

	# Voitures à construire : elles s'attellent en queue.
	_train_list.add_child(MenuKit.section("Construire"))
	var grid := MenuKit.grid()
	for wagon: WagonData in GameState.BUILDABLE_WAGONS:
		var problem: TrainRules.Problem = _build_problem(wagon)
		if problem == TrainRules.Problem.ALREADY_THERE:
			continue # déjà dans le train (voiture unique)
		var known: bool = problem != TrainRules.Problem.NEEDS_PLAN
		grid.add_child(_cell(Tab.TRAIN, wagon.icon if known else LOCK, StringName("build:" + wagon.id),
			wagon.display_name if known else "Plan à trouver").set_dim(known and (problem != TrainRules.Problem.NONE or not GameState.can(&"build"))))
	if grid.get_child_count() == 0:
		_train_list.add_child(MenuKit.label("Toutes les voitures sont construites.", MUTED))
	else:
		_train_list.add_child(grid)
	_ensure_selection(Tab.TRAIN, cabin)


static func _condition_color() -> Color:
	var state: int = GameState.condition()
	if state == GameState.Condition.CRITICAL:
		return BAD
	if state == GameState.Condition.DAMAGED:
		return GOLD
	return GOOD if GameState.train_condition >= 1.0 else Color.WHITE


static func _build_problem(wagon: WagonData) -> TrainRules.Problem:
	return TrainRules.build_problem(wagon, GameState.train, GameState.locomotive_level, GameState.storage, GameState.is_known(wagon.plan))


static func _wagon_type(id: String) -> WagonData:
	for wagon: WagonData in GameState.WAGON_TYPES:
		if String(wagon.id) == id:
			return wagon
	return null


func _detail_train(key: Variant) -> void:
	if key is StringName and key == &"free":
		MenuKit.detail_info(_detail, PLUS, "Place libre", "Choisis une voiture à construire en dessous : elle s'attelle en queue.")
	elif key is StringName and String(key).begins_with("build:"):
		_detail_build(_wagon_type(String(key).trim_prefix("build:")))
	elif key is WagonData:
		if (key as WagonData).id == &"cabin":
			_detail_locomotive(key as WagonData)
		else:
			_detail_wagon(key as WagonData)


func _detail_build(wagon: WagonData) -> void:
	if wagon == null:
		return
	var problem: TrainRules.Problem = _build_problem(wagon)
	var can_build: bool = GameState.can(&"build")
	if problem == TrainRules.Problem.NEEDS_PLAN:
		MenuKit.detail_info(_detail, LOCK, "Voiture inconnue", "Plan à étudier : %s (table des plans)." % _plan_name(wagon.plan))
		return
	var text: String = wagon.describe_effects()
	var why: String = ""
	if problem == TrainRules.Problem.NO_TRACTION:
		why = TrainRules.PROBLEM_TEXTS[problem]
	elif problem != TrainRules.Problem.NONE:
		why = MISSING_MATERIALS
	if not can_build:
		why = GameState.locked_text(&"build")
	MenuKit.detail_info(_detail, wagon.icon, wagon.display_name, text if problem != TrainRules.Problem.NO_TRACTION else why,
		BAD if problem == TrainRules.Problem.NO_TRACTION else MUTED)
	_detail.add_child(MenuKit.cost_row(wagon.cost, GameState.storage))
	_detail.add_child(MenuKit.action("Construire", func() -> void: GameState.build_wagon(wagon),
		problem != TrainRules.Problem.NONE or not can_build, why))


func _detail_wagon(wagon: WagonData) -> void:
	var level: int = GameState.wagon_level(wagon.id)
	var count: int = GameState.wagon_count(wagon.id)
	var title: String = "%s niv. %d" % [wagon.display_name, level] + (" · ×%d voitures" % count if count > 1 else "")
	var next: WagonUpgrade = wagon.upgrade_to(level + 1)
	if next == null:
		MenuKit.detail_info(_detail, wagon.icon, title, wagon.describe_effects() + (" · niveau maximum" if not wagon.upgrades.is_empty() else ""))
		return
	var problem: TrainRules.Problem = GameState.upgrade_wagon_problem(wagon)
	var text: String = "Niv. %d : %s" % [level + 1, next.describe()]
	if problem == TrainRules.Problem.NEEDS_PLAN:
		MenuKit.detail_info(_detail, wagon.icon, title, text + " · plan à étudier : " + _plan_name(next.plan))
		return
	MenuKit.detail_info(_detail, wagon.icon, title, text)
	var why: String = MISSING_MATERIALS if problem != TrainRules.Problem.NONE else ""
	if not GameState.can(&"build"):
		why = GameState.locked_text(&"build")
	_detail.add_child(MenuKit.cost_row(TrainRules.upgrade_cost(wagon, level + 1, count), GameState.storage))
	_detail.add_child(MenuKit.action("Agrandir", func() -> void: GameState.upgrade_wagon(wagon),
		problem != TrainRules.Problem.NONE or not GameState.can(&"build"), why))


## La cabine : la locomotive (combien de voitures elle tire), l'état du train, la réparation.
func _detail_locomotive(cabin: WagonData) -> void:
	var next: LocomotiveLevel = TrainRules.next_level(GameState.locomotive_level)
	var text: String = "Tire %d voitures · train %s" % [GameState.max_cars(), GameState.describe_condition()]
	if next:
		text += " · renfort au dépôt de la gare refuge (arrêt n°%d)" % GameState.next_refuge_stop()
	MenuKit.detail_info(_detail, cabin.icon, "Cabine · locomotive niv. %d" % GameState.locomotive_level, text,
		BAD if GameState.condition() != GameState.Condition.GOOD else MUTED)
	if GameState.train_condition < 1.0:
		_detail.add_child(MenuKit.cost_row(GameState.REPAIR_COST, GameState.storage))
		_detail.add_child(MenuKit.action("Réparer +%d %%" % roundi(GameState.REPAIR_STEP * 100.0), func() -> void: GameState.repair_train(),
			not GameState.can_repair_train(), MISSING_MATERIALS))


# --- Machines ---------------------------------------------------------------------

## Serre et laboratoire : ce qu'ils consomment → produisent à chaque trajet, et l'historique.
func _fill_machines() -> void:
	MenuKit.clear(_machines_list)
	var head := MenuKit.header()
	head.add_child(MenuKit.chip(HAMMER, "%d %%" % roundi(GameState.train_condition * 100.0), _condition_color(),
		"Sous %d %%, le train n'a plus de courant : les machines s'arrêtent." % roundi(GameState.TRAIN_DAMAGED * 100.0)))
	head.add_child(MenuKit.label("Elles tournent à chaque trajet, avec le stock.", MUTED))
	_machines_list.add_child(head)
	var machines: Array[WagonData] = GameState.machine_wagons()
	if machines.is_empty():
		var none := HBoxContainer.new()
		none.add_theme_constant_override(&"separation", 2)
		for texture: Texture2D in MACHINE_ICONS:
			none.add_child(SlotCell.create(texture, "", "", false).set_dim(true))
		var text := MenuKit.label("Aucune machine : serre (plan Horticulture) ou laboratoire (plan Distillerie), à construire dans l'onglet Train.", MUTED)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		none.add_child(text)
		_machines_list.add_child(none)
		return
	var cards := HFlowContainer.new()
	cards.add_theme_constant_override(&"h_separation", 4)
	cards.add_theme_constant_override(&"v_separation", 4)
	for wagon: WagonData in machines:
		cards.add_child(_machine_card(wagon))
	_machines_list.add_child(cards)
	if not GameState.production_log.is_empty():
		_machines_list.add_child(MenuKit.section("Derniers trajets"))
		_machines_list.add_child(_production_table())


func _machine_card(wagon: WagonData) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"InsetPanel"
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	card.add_child(box)
	var level: int = GameState.wagon_level(wagon.id)
	box.add_child(SlotCell.create(wagon.icon, str(level) if level > 1 else "", "%s niv. %d" % [wagon.display_name, level], false).set_count_color(GOLD))
	var info := VBoxContainer.new()
	info.add_theme_constant_override(&"separation", 1)
	box.add_child(info)
	var problem: String = GameState.machine_problem(wagon)
	var runs: int = GameState.machine_runs_left(wagon)
	var state: String = "En marche"
	var color: Color = GOOD
	if not problem.is_empty():
		state = "À l'arrêt : " + problem
		color = BAD
	elif runs >= 0 and runs <= 1:
		state = "Stock : encore %d trajet" % runs
		color = GOLD
	elif runs > 1:
		state = "En marche · stock pour %d trajets" % runs
	var title := HBoxContainer.new()
	title.add_theme_constant_override(&"separation", 6)
	title.add_child(MenuKit.label(wagon.display_name))
	title.add_child(MenuKit.label(state, color))
	info.add_child(title)
	info.add_child(MenuKit.recipe_row(wagon.production_cost, wagon.production_at(level), GameState.storage))
	return card


## Trajet · produit · consommé · état : les derniers trajets, le plus récent en haut.
func _production_table() -> GridContainer:
	var table := GridContainer.new()
	table.columns = 4
	table.add_theme_constant_override(&"h_separation", 8)
	table.add_theme_constant_override(&"v_separation", 1)
	for title: String in ["Trajet", "Produit", "Consommé", "État"]:
		table.add_child(MenuKit.label(title, MUTED))
	for entry: Dictionary in GameState.production_log:
		var produced: Dictionary[StringName, int] = entry.get("produced", {} as Dictionary[StringName, int])
		var consumed: Dictionary[StringName, int] = entry.get("consumed", {} as Dictionary[StringName, int])
		var note: String = entry.get("note", "")
		table.add_child(MenuKit.label("→ arrêt %d" % int(entry.get("stop", 0))))
		table.add_child(MenuKit.cost_row(produced) if not produced.is_empty() else MenuKit.label("—", MUTED))
		table.add_child(MenuKit.cost_row(consumed) if not consumed.is_empty() else MenuKit.label("—", MUTED))
		table.add_child(MenuKit.label(note if not note.is_empty() else "Tout tourne", BAD if not note.is_empty() else GOOD))
	return table


# --- Plans -------------------------------------------------------------------------

func _fill_plans() -> void:
	MenuKit.clear(_plans_list)
	var researched: int = GameState.researched_plans.size()
	var found: int = GameState.found_plans.size()
	var head := MenuKit.header()
	head.add_child(MenuKit.chip(CHECK, str(researched), GOOD, "Plans étudiés"))
	head.add_child(MenuKit.chip(PLAN, str(found), GOLD if found > 0 else MUTED, "Plans trouvés, à étudier ici"))
	head.add_child(MenuKit.chip(LOCK, str(BlueprintCatalog.ALL.size() - researched - found), MUTED,
		"Plans à trouver : caisses, armoires, marchands, gares"))
	_plans_list.add_child(head)
	var paper := BlueprintPaper.new()
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override(&"h_separation", 4)
	grid.add_theme_constant_override(&"v_separation", 3)
	paper.add_child(grid)
	var first_found: BlueprintData = null
	for plan: BlueprintData in BlueprintCatalog.ALL:
		grid.add_child(_plan_tile(plan))
		if first_found == null and plan.id in GameState.found_plans:
			first_found = plan
	_plans_list.add_child(paper)
	_ensure_selection(Tab.PLANS, first_found)


## Un plan sur la feuille : l'icône de ce qu'il débloque, son nom ; coche s'il est étudié,
## « ! » s'il attend d'être étudié, cadenas s'il reste à trouver.
func _plan_tile(plan: BlueprintData) -> VBoxContainer:
	var tile := VBoxContainer.new()
	tile.add_theme_constant_override(&"separation", 0)
	tile.custom_minimum_size = Vector2(78.0, 0.0)
	var researched: bool = plan.id in GameState.researched_plans
	var found: bool = plan.id in GameState.found_plans
	var cell := _cell(Tab.PLANS, BlueprintCatalog.icon(plan.id), plan, plan.display_name, "!" if found else "")
	cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if researched:
		cell.set_corner(CHECK)
	elif found:
		cell.set_count_color(BlueprintPaper.GOLD)
	else:
		cell.set_dim(true).set_corner(LOCK)
	tile.add_child(cell)
	var name_label := MenuKit.label(plan.display_name,
		BlueprintPaper.GOLD if researched else (BlueprintPaper.INK if found else Color(BlueprintPaper.INK, 0.5)))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile.add_child(name_label)
	return tile


func _detail_plan(key: Variant) -> void:
	if not key is BlueprintData:
		return
	var plan: BlueprintData = key
	var unlocks: String = "Débloque : " + ", ".join(BlueprintCatalog.unlocks(plan.id))
	var icon: Texture2D = BlueprintCatalog.icon(plan.id)
	if plan.id in GameState.researched_plans:
		MenuKit.detail_info(_detail, icon, plan.display_name + " · étudié", unlocks)
		return
	if not plan.id in GameState.found_plans:
		MenuKit.detail_info(_detail, LOCK, plan.display_name + " · à trouver",
			unlocks + " · dans les caisses, les armoires, chez les marchands, en gare.")
		return
	var text: String = unlocks
	if not plan.requires.is_empty():
		var names: PackedStringArray = []
		for required: StringName in plan.requires:
			names.append(_plan_name(required))
		text += " · prérequis : " + ", ".join(names)
	var problem: String = BlueprintCatalog.research_problem(plan, GameState.found_plans, GameState.researched_plans, GameState.storage)
	MenuKit.detail_info(_detail, icon, plan.display_name + " · à étudier", text)
	_detail.add_child(MenuKit.cost_row(plan.research_cost, GameState.storage))
	_detail.add_child(MenuKit.action("Étudier", func() -> void: GameState.research(plan), not problem.is_empty(), problem))


# --- Infirmerie --------------------------------------------------------------------

func _fill_infirmary() -> void:
	MenuKit.clear(_infirmary_list)
	if _patient and not _patient in GameState.crew:
		_patient = null
	# Le patient : toi ou un équipier. Les médicaments s'expliquent pour lui.
	var patients := HBoxContainer.new()
	patients.add_theme_constant_override(&"separation", 2)
	patients.add_child(_patient_button(null))
	for member: CrewMember in GameState.crew:
		patients.add_child(_patient_button(member))
	_infirmary_list.add_child(patients)
	var value: float = GameState.infection if _patient == null else _patient.visible_infection() / 100.0
	var gauge := HBoxContainer.new()
	gauge.add_theme_constant_override(&"separation", 4)
	gauge.add_child(MenuKit.icon(SPORE, 12.0))
	var bar := _bar(value, Infection.color(value), 150.0)
	bar.custom_minimum_size.y = 6.0
	bar.marks = Infection.stage_marks() if _patient == null else ([] as Array[float])
	gauge.add_child(bar)
	var text: String = Infection.describe(GameState.infection) if _patient == null else \
		"%s · infection %s" % [_patient.display_name, _patient.infection_text()]
	gauge.add_child(MenuKit.label(text, Infection.color(value) if value > 0.0 else MUTED))
	_infirmary_list.add_child(gauge)

	_infirmary_list.add_child(MenuKit.section("Pharmacie"))
	var pharmacy := MenuKit.grid()
	for loot: LootData in GameState.LOOT_TYPES:
		if loot.is_medicine():
			var amount: int = GameState.storage_amount(loot.id)
			pharmacy.add_child(_cell(Tab.INFIRMARY, loot.icon, loot, "%s : %d" % [loot.display_name, amount],
				str(amount) if amount > 0 else "").set_dim(amount == 0))
	_infirmary_list.add_child(pharmacy)

	var recipes: HFlowContainer = _recipe_grid(Tab.INFIRMARY, RecipeData.Station.INFIRMARY)
	if recipes.get_child_count() > 0:
		_infirmary_list.add_child(MenuKit.section("Préparer"))
		_infirmary_list.add_child(recipes)
	if GameState.has_wagon(&"infirmary"):
		_infirmary_list.add_child(MenuKit.section("Quarantaine %d/%d" % [GameState.quarantined_count(), GameState.QUARANTINE_BEDS]))
		var beds := HBoxContainer.new()
		beds.add_theme_constant_override(&"separation", 2)
		var isolated: Array[CrewMember] = []
		for member: CrewMember in GameState.crew:
			if member.quarantined:
				isolated.append(member)
		for i: int in GameState.QUARANTINE_BEDS:
			if i < isolated.size():
				beds.add_child(_cell(Tab.INFIRMARY, CrewLooks.portrait(isolated[i].look), isolated[i], isolated[i].display_name + " (isolé)"))
			else:
				beds.add_child(_cell(Tab.INFIRMARY, BED, &"bed", "Lit libre").set_dim(true))
		_infirmary_list.add_child(beds)
	else:
		_infirmary_list.add_child(MenuKit.label("Une infirmerie (onglet Train) prépare des remèdes et isole les malades.", MUTED))
	_ensure_selection(Tab.INFIRMARY)


func _patient_button(member: CrewMember) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.button_pressed = is_same(_patient, member)
	button.text = "Toi %d %%" % roundi(GameState.infection * 100.0) if member == null else \
		"%s %s" % [member.display_name, member.infection_text()]
	button.tooltip_text = "Soigner : toi" if member == null else "Soigner : " + member.describe()
	button.custom_minimum_size = Vector2(0.0, 16.0)
	button.pressed.connect(_set_patient.bind(member), CONNECT_DEFERRED)
	return button


func _set_patient(member: CrewMember) -> void:
	_patient = member
	_cells.erase(Tab.INFIRMARY)
	_fill_infirmary()
	_fill_detail()


func _detail_infirmary(key: Variant) -> void:
	if key is RecipeData:
		_detail_recipe(key as RecipeData, "Préparer")
	elif key is LootData:
		_detail_medicine(key as LootData)
	elif key is CrewMember:
		var member: CrewMember = key
		MenuKit.detail_info(_detail, CrewLooks.portrait(member.look), "%s · isolé" % member.display_name,
			"Infection %s · il ne contamine plus personne et ne travaille pas." % member.infection_text())
		_detail.add_child(MenuKit.action("Libérer", func() -> void: GameState.toggle_quarantine(member),
			not GameState.can(&"crew"), GameState.locked_text(&"crew")))
	elif key is StringName and key == &"bed":
		MenuKit.detail_info(_detail, BED, "Lit libre", "Choisis un équipier en haut pour l'isoler.")
		if _patient:
			var patient: CrewMember = _patient
			_detail.add_child(MenuKit.action("Isoler " + patient.display_name, func() -> void: GameState.toggle_quarantine(patient),
				not GameState.can(&"crew") or not GameState.can_quarantine(patient), GameState.locked_text(&"crew")))


func _detail_medicine(medicine: LootData) -> void:
	var amount: int = GameState.storage_amount(medicine.id)
	var title: String = "%s ×%d" % [medicine.display_name, amount]
	if _patient == null:
		var cure: float = GameState.medicine_cure(medicine)
		var now: int = roundi(GameState.infection * 100.0)
		MenuKit.detail_info(_detail, medicine.icon, title, "Infection −%d %% · toi : %d %% → %d %%" % [
			roundi(cure * 100.0), now, maxi(now - roundi(cure * 100.0), 0)])
		_detail.add_child(MenuKit.action("Prendre", func() -> void: GameState.take_medicine(medicine),
			amount <= 0 or GameState.infection <= 0.0, "Rien à soigner" if GameState.infection <= 0.0 else "Plus en stock"))
		return
	var member: CrewMember = _patient
	MenuKit.detail_info(_detail, medicine.icon, title, "Infection −%d %% · %s : %s" % [
		roundi(medicine.cure * 100.0), member.display_name, member.infection_text()])
	var command: bool = GameState.can(&"crew")
	_detail.add_child(MenuKit.action("Donner à " + member.display_name, func() -> void: GameState.medicate(member, medicine),
		not command or amount <= 0 or (member.infection_known and member.infection == 0),
		GameState.locked_text(&"crew") if not command else ("Plus en stock" if amount <= 0 else "Il n'est pas infecté")))


# --- Chaudière -----------------------------------------------------------------------

## La réserve d'énergie, les trajets qu'elle permet, le risque de panne ; on y charge le
## bois et le charbon du stock.
func _fill_boiler() -> void:
	MenuKit.clear(_boiler_list)
	var trips: int = GameState.trips_left()
	var color: Color = GOOD if trips >= 2 else (GOLD if trips == 1 else BAD)
	var head := MenuKit.header()
	head.add_child(MenuKit.chip(COAL, "%d/%d" % [GameState.energy, GameState.energy_capacity()], color,
		"Énergie dans la chaudière"))
	head.add_child(_bar(float(GameState.energy) / maxf(GameState.energy_capacity(), 1.0), color, 90.0))
	head.add_child(MenuKit.chip(WAGON, "%d trajet(s)" % trips, color,
		"Un trajet brûle %d d'énergie (%d voitures). Sans assez d'énergie : panne sèche en pleine voie." % [
			GameState.trip_energy(), GameState.train.size()]))
	var chance: int = roundi(GameState.breakdown_chance() * 100.0)
	head.add_child(MenuKit.chip(HAMMER, "panne %d %%" % chance, BAD if chance >= 15 else MUTED,
		"Risque de panne moteur au prochain trajet : plus le train est abîmé, plus il casse. Chaque mécanicien au travail le réduit."))
	_boiler_list.add_child(head)
	if GameState.is_incident_stop():
		var warning := MenuKit.label(GameState.incident_text(), BAD)
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_boiler_list.add_child(warning)
	elif trips == 0:
		_boiler_list.add_child(MenuKit.label("Pas assez pour le prochain trajet : charge la chaudière !", BAD))
	_boiler_list.add_child(MenuKit.section("Charger"))
	var grid := MenuKit.grid()
	for fuel: LootData in GameState.fuel_types():
		var amount: int = GameState.storage_amount(fuel.id)
		grid.add_child(_cell(Tab.BOILER, fuel.icon, fuel, "%s : %d en stock" % [fuel.display_name, amount],
			str(amount) if amount > 0 else "").set_dim(amount == 0))
	_boiler_list.add_child(grid)
	_ensure_selection(Tab.BOILER)


func _detail_boiler(key: Variant) -> void:
	if not key is LootData:
		return
	var fuel: LootData = key
	var amount: int = GameState.storage_amount(fuel.id)
	var room: int = GameState.loadable_fuel(fuel)
	var full: bool = GameState.energy >= GameState.energy_capacity()
	MenuKit.detail_info(_detail, fuel.icon, "%s ×%d" % [fuel.display_name, amount],
		"+%d d'énergie chacun%s" % [fuel.fuel, " · chaudière pleine" if full else (" · place pour %d" % room if room < amount else "")])
	var why: String = "Chaudière pleine" if full else ("Plus en stock" if amount == 0 else "Pas assez de place")
	_detail.add_child(MenuKit.action("Charger 1", func() -> void: GameState.load_fuel(fuel, 1), room <= 0, why))
	_detail.add_child(MenuKit.action("Charger %d" % room if room > 1 else "Tout charger", func() -> void: GameState.load_fuel(fuel, room),
		room <= 1, why))
