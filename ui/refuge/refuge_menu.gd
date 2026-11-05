extends CanvasLayer
## Menu d'une gare refuge : comptoir d'échange, bureau de recrutement (quarantaine),
## dépôt (renfort de la locomotive). Tout se paie avec le stock du train.
##
## Il garde la mémoire du passage en cours : une recrue ne se prend qu'une fois.

signal closed

enum Tab { TRADE, RECRUIT, DEPOT }

@onready var _root: Control = $Root
@onready var _tabs: TabContainer = %Tabs
@onready var _title: Label = %Title
@onready var _trade_list: VBoxContainer = %TradeList
@onready var _recruit_list: VBoxContainer = %RecruitList
@onready var _depot_list: VBoxContainer = %DepotList
@onready var _close: Button = %Close

var refuge: RefugeData
## Offres déjà prises pendant ce passage (recrues).
var _done: Array[RefugeOffer] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_root.visible = false
	_close.pressed.connect(close)
	for signal_name: StringName in [&"storage_changed", &"crew_changed", &"train_changed", &"condition_changed"]:
		# Différé : un bouton ne doit pas être détruit pendant son propre clic.
		GameState.connect(signal_name, _refresh, CONNECT_DEFERRED)
	_tabs.set_tab_title(Tab.TRADE, "Comptoir")
	_tabs.set_tab_title(Tab.RECRUIT, "Recrutement")
	_tabs.set_tab_title(Tab.DEPOT, "Dépôt")


func setup(refuge_data: RefugeData, rng_seed: int) -> void:
	refuge = refuge_data
	_rng.seed = rng_seed
	_done.clear()


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


## Prend une offre (bouton). Renvoie false si elle n'est pas possible.
func take(offer: RefugeOffer) -> bool:
	if not GameState.use_refuge_offer(offer, _rng, offer in _done):
		return false
	if offer.recruits():
		_done.append(offer)
		_refresh.call_deferred()
	return true


func _refresh() -> void:
	if refuge == null:
		return
	_title.text = refuge.display_name
	_fill_offers(_trade_list, refuge.trades, "Échanger")
	_fill_offers(_recruit_list, refuge.recruits, "Recruter")
	_recruit_list.add_child(MenuKit.label("Couchettes : %d/%d · Les recrues de la gare sortent de quarantaine : jamais infectées." % [
		GameState.crew.size(), GameState.beds()], MenuKit.MUTED))
	_fill_depot()


func _fill_offers(list: VBoxContainer, offers: Array[RefugeOffer], verb: String) -> void:
	MenuKit.clear(list)
	list.add_child(MenuKit.label("Stock du train : %d/%d" % [GameState.storage_total(), GameState.storage_capacity()], MenuKit.GOLD))
	for offer: RefugeOffer in offers:
		var problem: RefugeRules.Problem = RefugeRules.problem(offer, GameState.storage, GameState.storage_free(),
			GameState.free_beds(), offer in _done or GameState.knows_plan(offer.reward_plan), GameState.can(&"recruit"))
		var detail: String = "Donne : " + MenuKit.describe_amounts(offer.cost)
		if not offer.reward.is_empty():
			detail += " · Reçois : " + MenuKit.describe_amounts(offer.reward)
		if offer.reward_plan != &"":
			detail += " · Plan : " + BlueprintCatalog.get_plan(offer.reward_plan).display_name
		if problem != RefugeRules.Problem.NONE and problem != RefugeRules.Problem.MISSING_MATERIALS:
			detail = RefugeRules.PROBLEM_TEXTS[problem]
			if problem == RefugeRules.Problem.ALREADY_DONE and offer.reward_plan != &"":
				detail = "Plan déjà connu."
		var title: String = offer.label
		if offer.recruits():
			title += " (%s)" % offer.recruit_role_label
		list.add_child(MenuKit.row(title, detail, MenuKit.GOOD if problem == RefugeRules.Problem.NONE else MenuKit.BAD,
			"Fait" if problem == RefugeRules.Problem.ALREADY_DONE else verb,
			problem != RefugeRules.Problem.NONE, func() -> void: take(offer)))


func _fill_depot() -> void:
	MenuKit.clear(_depot_list)
	_depot_list.add_child(MenuKit.label("Voitures : %d/%d · Locomotive niv. %d" % [
		GameState.train.size(), GameState.max_cars(), GameState.locomotive_level], MenuKit.GOLD))
	# Réparation complète du train (abîmé par une horde).
	var needs_repair: bool = GameState.train_condition < 1.0
	var can_repair: bool = needs_repair and TrainRules.missing(GameState.DEPOT_REPAIR_COST, GameState.storage).is_empty()
	_depot_list.add_child(MenuKit.row("Réparer le train à fond (%d %% → 100 %%)" % roundi(GameState.train_condition * 100.0) if needs_repair else "Train en bon état",
		"Coût : " + MenuKit.describe_amounts(GameState.DEPOT_REPAIR_COST) if needs_repair else "Rien à réparer.",
		MenuKit.GOOD if can_repair or not needs_repair else MenuKit.BAD, "Réparer", not can_repair,
		func() -> void: GameState.repair_train_at_depot()))
	var next: LocomotiveLevel = TrainRules.next_level(GameState.locomotive_level)
	if next == null:
		_depot_list.add_child(MenuKit.row("Locomotive au niveau maximum", "Elle tire 8 voitures, on ne peut pas faire mieux.",
			MenuKit.MUTED, "Max", true, Callable()))
		return
	var problem: TrainRules.Problem = TrainRules.upgrade_problem(GameState.locomotive_level, GameState.storage)
	var allowed: bool = GameState.can(&"build")
	_depot_list.add_child(MenuKit.row(
		"Renforcer la locomotive : niv. %d, %d voitures" % [next.level, next.max_cars],
		"Coût : " + MenuKit.describe_amounts(next.cost) + ("" if allowed else " · " + GameState.locked_text(&"build")),
		MenuKit.GOOD if problem == TrainRules.Problem.NONE and allowed else MenuKit.BAD,
		"Renforcer", problem != TrainRules.Problem.NONE or not allowed, func() -> void: GameState.upgrade_locomotive()))
	_depot_list.add_child(MenuKit.label("Les voitures se construisent à bord, sur la table du capitaine.", MenuKit.MUTED))
