extends CanvasLayer
## Menu du train : stock, atelier (fabrication), équipement, équipage, train (construction).
##
## Un seul panneau à onglets ; chaque meuble du train l'ouvre sur son onglet.
## Il lit et modifie GameState, rien d'autre.

signal closed

enum Tab { STOCK, WORKSHOP, EQUIPMENT, CREW, TRAIN, GRADE }

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
@onready var _grade_list: VBoxContainer = %GradeList
@onready var _close: Button = %Close


func _ready() -> void:
	_root.visible = false
	_close.pressed.connect(close)
	for signal_name: StringName in [&"storage_changed", &"equipment_changed", &"crew_changed", &"train_changed", &"career_changed"]:
		# Différé : un bouton ne doit pas être détruit pendant son propre clic.
		GameState.connect(signal_name, _refresh, CONNECT_DEFERRED)
	_tabs.set_tab_title(Tab.STOCK, "Stock")
	_tabs.set_tab_title(Tab.WORKSHOP, "Atelier")
	_tabs.set_tab_title(Tab.EQUIPMENT, "Équipement")
	_tabs.set_tab_title(Tab.CREW, "Équipage")
	_tabs.set_tab_title(Tab.TRAIN, "Train")
	_tabs.set_tab_title(Tab.GRADE, "Grade")


func _unhandled_input(event: InputEvent) -> void:
	if _root.visible and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause")):
		close()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _root.visible


func open(tab: Tab) -> void:
	_refresh()
	_tabs.current_tab = tab
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
	_fill_grade()


# --- Stock ------------------------------------------------------------------------

func _fill_stock() -> void:
	MenuKit.clear(_stock_list)
	var full: bool = GameState.storage_free() == 0
	_stock_list.add_child(MenuKit.label("Places : %d/%d" % [GameState.storage_total(), GameState.storage_capacity()], BAD if full else GOLD))
	if full:
		_stock_list.add_child(MenuKit.label("Stock plein : construis un wagon de stock (onglet Train).", BAD))
	for loot: LootData in GameState.LOOT_TYPES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 4)
		var swatch := ColorRect.new()
		swatch.color = loot.color
		swatch.custom_minimum_size = Vector2(6.0, 6.0)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		row.add_child(MenuKit.label("%s : %d" % [loot.display_name, GameState.storage_amount(loot.id)]))
		_stock_list.add_child(row)
	_stock_list.add_child(MenuKit.label("Équipements à bord : %d" % GameState.owned_items.size(), MUTED))


# --- Atelier ----------------------------------------------------------------------

func _fill_workshop() -> void:
	MenuKit.clear(_workshop_list)
	for item: ItemData in ItemCatalog.craftables():
		var owned: bool = item in GameState.owned_items
		var lacking := Crafting.missing(item, GameState.storage)
		var row := HBoxContainer.new()
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


# --- Équipement -------------------------------------------------------------------

func _fill_equipment() -> void:
	MenuKit.clear(_equipment_list)
	var loadout: Loadout = GameState.loadout
	_equipment_list.add_child(MenuKit.label(loadout.describe(), GOLD))
	for slot: int in ItemData.Slot.values():
		var options: Array[ItemData] = GameState.owned_for_slot(slot)
		var current: ItemData = loadout.get_item(slot)
		var row := HBoxContainer.new()
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
		_crew_list.add_child(MenuKit.label("Plus de place : construis un dortoir (onglet Train) pour recruter.", BAD))
	if GameState.crew.is_empty():
		_crew_list.add_child(MenuKit.label("Personne à bord pour l'instant.", MUTED))
		_crew_list.add_child(MenuKit.label("Recrute des survivants dans les refuges pendant les sorties.", MUTED))
		return
	for member: CrewMember in GameState.crew:
		_crew_list.add_child(MenuKit.label("%s — %s" % [member.display_name, member.role_label]))


# --- Grade ------------------------------------------------------------------------

func _fill_grade() -> void:
	MenuKit.clear(_grade_list)
	var grade: GradeData = GameState.grade()
	var next: GradeData = Career.next_grade(GameState.grade_index())
	_grade_list.add_child(MenuKit.label("%s — %s" % [grade.display_name, grade.description], GOLD))
	if next:
		_grade_list.add_child(MenuKit.label("Mérite : %d/%d avant %s" % [GameState.merit, next.merit_needed, next.display_name], MUTED))
	else:
		_grade_list.add_child(MenuKit.label("Mérite : %d (grade le plus haut)" % GameState.merit, MUTED))
	var order: CaptainOrders.Order = GameState.current_order
	_grade_list.add_child(MenuKit.label("Ordre pour l'arrêt n°%d : %s (+%d mérite)" % [GameState.stop_number, order.text(), order.data.merit] if order \
		else "Pas d'ordre : le prochain arrêt est une gare refuge.", Color.WHITE))
	# Promotion en attente : on peut choisir son talent ici aussi.
	if not GameState.pending_promotions.is_empty():
		var promotion: GradeData = GameState.pending_promotions[0]
		_grade_list.add_child(MenuKit.label("Promu %s : choisis un talent." % promotion.display_name, GOOD))
		for perk: PerkData in promotion.perks:
			_grade_list.add_child(MenuKit.row(perk.display_name, "%s — %s" % [perk.describe_effects(), perk.description], GOOD,
				"Choisir", false, func() -> void: GameState.choose_perk(perk)))
	if GameState.perks.is_empty():
		_grade_list.add_child(MenuKit.label("Pas encore de talent : remplis les ordres du capitaine et élimine des ennemis pour monter en grade.", MUTED))
	for perk: PerkData in GameState.perks:
		_grade_list.add_child(MenuKit.label("%s : %s" % [perk.display_name, perk.describe_effects()], Color.WHITE))


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
		var problem: TrainRules.Problem = TrainRules.build_problem(wagon, GameState.train, GameState.locomotive_level, GameState.storage)
		var detail: String = "Coût : " + MenuKit.describe_amounts(wagon.cost)
		if problem == TrainRules.Problem.NO_TRACTION:
			detail = TrainRules.PROBLEM_TEXTS[problem]
		_train_list.add_child(MenuKit.row(
			"%s (%s)" % [wagon.display_name, wagon.describe_effects()], detail,
			GOOD if problem == TrainRules.Problem.NONE else BAD,
			"Construire", problem != TrainRules.Problem.NONE, func() -> void: GameState.build_wagon(wagon)))
