extends CanvasLayer
## Menu d'une gare refuge : comptoir d'échange, bureau de recrutement (quarantaine),
## dépôt (renfort de la locomotive). Tout se paie avec le stock du train.
##
## Il garde la mémoire du passage en cours : une recrue ne se prend qu'une fois.
##
## Peu de texte : chaque offre est une carte « ce que tu donnes → ce que tu reçois » en
## cases, avec son bouton ; la phrase du marchand et les raisons sont en infobulle.

signal closed

enum Tab { TRADE, RECRUIT, DEPOT }

const CRATE: Texture2D = preload("res://assets/ui/icons/crate.png")
const BED: Texture2D = preload("res://assets/ui/icons/bed.png")
const CROSS: Texture2D = preload("res://assets/ui/icons/cross.png")
const WAGON: Texture2D = preload("res://assets/ui/icons/wagon.png")
const HAMMER: Texture2D = preload("res://assets/ui/icons/hammer.png")
const LOCOMOTIVE: Texture2D = preload("res://assets/ui/icons/locomotive.png")
const PERSON: Texture2D = preload("res://assets/ui/icons/recruit.png")
const PLAN: Texture2D = preload("res://assets/ui/icons/plan.png")

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
	MenuKit.focus_later(_close)


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
	_fill_depot()


func _fill_offers(list: VBoxContainer, offers: Array[RefugeOffer], verb: String) -> void:
	MenuKit.clear(list)
	var head := MenuKit.header()
	var full: bool = GameState.storage_free() == 0
	head.add_child(MenuKit.chip(CRATE, "%d/%d" % [GameState.storage_total(), GameState.storage_capacity()],
		MenuKit.BAD if full else Color.WHITE, "Stock du train : on paie avec, on y range ce qu'on reçoit"))
	if offers.any(func(offer: RefugeOffer) -> bool: return offer.recruits()):
		head.add_child(MenuKit.chip(BED, "%d/%d" % [GameState.crew.size(), GameState.beds()],
			MenuKit.BAD if GameState.free_beds() == 0 else Color.WHITE, "Couchettes"))
		head.add_child(MenuKit.chip(CROSS, "Jamais infectées", MenuKit.GOOD, "Les recrues de la gare sortent de quarantaine."))
	list.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 4)
	grid.add_theme_constant_override(&"v_separation", 3)
	for offer: RefugeOffer in offers:
		grid.add_child(_offer_card(offer, verb))
	list.add_child(grid)


## Une offre : [ce qu'on donne] → [ce qu'on reçoit], et son bouton. La phrase du marchand
## et la raison d'un refus sont dans l'infobulle.
func _offer_card(offer: RefugeOffer, verb: String) -> PanelContainer:
	var problem: RefugeRules.Problem = RefugeRules.problem(offer, GameState.storage, GameState.storage_free(),
		GameState.free_beds(), offer in _done or GameState.knows_plan(offer.reward_plan), GameState.can(&"recruit"))
	var why: String = ""
	if problem != RefugeRules.Problem.NONE:
		why = RefugeRules.PROBLEM_TEXTS[problem]
		if problem == RefugeRules.Problem.ALREADY_DONE and offer.reward_plan != &"":
			why = "Plan déjà connu."
	var card := PanelContainer.new()
	card.theme_type_variation = &"InsetPanel"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = offer.label + ("\n" + why if not why.is_empty() else "")
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 3)
	card.add_child(box)
	if offer.recruits():
		var portrait := MenuKit.icon(PERSON, 24.0)
		portrait.self_modulate = MenuKit.role_color(offer.recruit_role)
		box.add_child(portrait)
		box.add_child(MenuKit.label(offer.recruit_role_label))
	box.add_child(MenuKit.cost_row(offer.cost, GameState.storage))
	if not offer.reward.is_empty() or offer.reward_plan != &"":
		box.add_child(MenuKit.icon(MenuKit.ARROW, 12.0))
	if not offer.reward.is_empty():
		box.add_child(MenuKit.cost_row(offer.reward))
	if offer.reward_plan != &"":
		box.add_child(MenuKit.icon(PLAN, 12.0))
		box.add_child(MenuKit.label(BlueprintCatalog.get_plan(offer.reward_plan).display_name))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	# Une raison qui n'est pas « il manque » (couchette, place, grade) se dit en clair.
	if problem != RefugeRules.Problem.NONE and problem != RefugeRules.Problem.MISSING_MATERIALS \
			and problem != RefugeRules.Problem.ALREADY_DONE:
		var reason := MenuKit.label(_short_reason(problem), MenuKit.BAD)
		box.add_child(reason)
	var button := MenuKit.action("Fait" if problem == RefugeRules.Problem.ALREADY_DONE else verb, func() -> void: take(offer),
		problem != RefugeRules.Problem.NONE, why)
	box.add_child(button)
	return card


static func _short_reason(problem: RefugeRules.Problem) -> String:
	match problem:
		RefugeRules.Problem.NO_SPACE:
			return "stock plein"
		RefugeRules.Problem.NO_BED:
			return "pas de couchette"
		RefugeRules.Problem.NO_RANK:
			return "grade " + Career.required_grade(&"recruit")
	return ""


func _fill_depot() -> void:
	MenuKit.clear(_depot_list)
	var head := MenuKit.header()
	head.add_child(MenuKit.chip(WAGON, "%d/%d" % [GameState.train.size(), GameState.max_cars()], Color.WHITE,
		"Voitures attelées / ce que la locomotive peut tirer"))
	head.add_child(MenuKit.chip(LOCOMOTIVE, "niv. %d" % GameState.locomotive_level, Color.WHITE, "Locomotive"))
	head.add_child(MenuKit.chip(CRATE, "%d/%d" % [GameState.storage_total(), GameState.storage_capacity()], Color.WHITE, "Stock du train"))
	_depot_list.add_child(head)
	# Réparation complète du train (abîmé par une horde).
	var needs_repair: bool = GameState.train_condition < 1.0
	var can_repair: bool = needs_repair and TrainRules.missing(GameState.DEPOT_REPAIR_COST, GameState.storage).is_empty()
	var repair := _depot_card(HAMMER, "%d %% → 100 %%" % roundi(GameState.train_condition * 100.0) if needs_repair else "Train en bon état",
		Color.WHITE if needs_repair else MenuKit.GOOD, "Réparation complète du train, abîmé par les hordes")
	if needs_repair:
		repair.add_child(MenuKit.cost_row(GameState.DEPOT_REPAIR_COST, GameState.storage))
		repair.add_child(MenuKit.action("Réparer", func() -> void: GameState.repair_train_at_depot(), not can_repair,
			"Il manque des matériaux dans le stock."))
	# Renfort de la locomotive : une voiture de plus.
	var next: LocomotiveLevel = TrainRules.next_level(GameState.locomotive_level)
	if next == null:
		_depot_card(LOCOMOTIVE, "Niveau maximum : %d voitures" % GameState.max_cars(), MenuKit.MUTED, "On ne peut pas faire mieux.")
	else:
		var problem: TrainRules.Problem = TrainRules.upgrade_problem(GameState.locomotive_level, GameState.storage)
		var allowed: bool = GameState.can(&"build")
		var loco := _depot_card(LOCOMOTIVE, "Niv. %d · %d voitures" % [next.level, next.max_cars], Color.WHITE,
			"Renforcer la locomotive : elle tire une voiture de plus")
		loco.add_child(MenuKit.cost_row(next.cost, GameState.storage))
		loco.add_child(MenuKit.action("Renforcer", func() -> void: GameState.upgrade_locomotive(),
			problem != TrainRules.Problem.NONE or not allowed,
			GameState.locked_text(&"build") if not allowed else "Il manque des matériaux dans le stock."))
	_depot_list.add_child(MenuKit.label("Les voitures se construisent à bord (table du capitaine).", MenuKit.MUTED))


## Une carte du dépôt : icône, ce qu'on obtient ; renvoie sa ligne pour y ajouter coût et bouton.
func _depot_card(texture: Texture2D, text: String, color: Color, tip: String) -> HBoxContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"InsetPanel"
	card.tooltip_text = tip
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	card.add_child(box)
	box.add_child(MenuKit.icon(texture, 24.0))
	var label := MenuKit.label(text, color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(label)
	_depot_list.add_child(card)
	return box
