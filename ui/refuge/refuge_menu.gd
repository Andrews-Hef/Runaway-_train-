extends CanvasLayer
## Menu d'une gare refuge : marchand (troc libre, équipements, plans), comptoir (offres
## fixes), bureau de recrutement (quarantaine), dépôt (renfort de la locomotive). Tout se
## paie avec le stock du train.
##
## Il garde la mémoire du passage en cours : une recrue ne se prend qu'une fois, l'étal
## du marchand garde ce qu'on lui a vendu et acheté.
##
## Peu de texte : chaque offre est une carte « ce que tu donnes → ce que tu reçois » en
## cases, avec son bouton ; la phrase du marchand et les raisons sont en infobulle.

signal closed

enum Tab { MARKET, TRADE, RECRUIT, DEPOT }

const CRATE: Texture2D = preload("res://assets/ui/icons/crate.png")
const BED: Texture2D = preload("res://assets/ui/icons/bed.png")
const CROSS: Texture2D = preload("res://assets/ui/icons/cross.png")
const WAGON: Texture2D = preload("res://assets/ui/icons/wagon.png")
const HAMMER: Texture2D = preload("res://assets/ui/icons/hammer.png")
const LOCOMOTIVE: Texture2D = preload("res://assets/ui/icons/locomotive.png")
const PERSON: Texture2D = preload("res://assets/ui/icons/recruit.png")
const PLAN: Texture2D = preload("res://assets/ui/icons/plan.png")
const BALANCE: Texture2D = preload("res://assets/ui/icons/balance.png")
const CHECK: Texture2D = preload("res://assets/ui/icons/check.png")

@onready var _root: Control = $Root
@onready var _tabs: TabContainer = %Tabs
@onready var _title: Label = %Title
@onready var _trade_list: VBoxContainer = %TradeList
@onready var _recruit_list: VBoxContainer = %RecruitList
@onready var _depot_list: VBoxContainer = %DepotList
@onready var _close: Button = %Close
@onready var _market_list: VBoxContainer = %MarketList
@onready var _deal_box: HBoxContainer = %Deal
@onready var _detail: HBoxContainer = %Detail

var refuge: RefugeData
## Offres déjà prises pendant ce passage (recrues).
var _done: Array[RefugeOffer] = []
var _rng := RandomNumberGenerator.new()
## L'étal du marchand pour ce passage, et l'échange qu'on prépare.
var stall: Barter.Stall
var deal := Barter.Deal.new()
## Case choisie au marché : « stall:<id> », « stock:<id> », « item:<id> », « plan:<id> ».
var market_key: String = ""
## Ce que dit le marchand après un échange (vide dès qu'on en prépare un autre).
var _note: String = ""
var _market_cells: Array[SlotCell] = []


func _ready() -> void:
	_root.visible = false
	_close.pressed.connect(close)
	for signal_name: StringName in [&"storage_changed", &"crew_changed", &"train_changed", &"condition_changed"]:
		# Différé : un bouton ne doit pas être détruit pendant son propre clic.
		GameState.connect(signal_name, _refresh, CONNECT_DEFERRED)
	_tabs.set_tab_title(Tab.MARKET, "Marchand")
	_tabs.set_tab_title(Tab.TRADE, "Comptoir")
	_tabs.set_tab_title(Tab.RECRUIT, "Recrutement")
	_tabs.set_tab_title(Tab.DEPOT, "Dépôt")


func setup(refuge_data: RefugeData, rng_seed: int) -> void:
	refuge = refuge_data
	_rng.seed = rng_seed
	_done.clear()
	stall = GameState.market_stall(refuge_data, rng_seed)
	deal.clear()
	market_key = ""


func _unhandled_input(event: InputEvent) -> void:
	if _root.visible and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause")):
		close()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _root.visible


func open(tab: Tab) -> void:
	_refresh()
	_tabs.current_tab = tab
	if not _root.visible:
		Audio.play(&"ui_open")
	_root.visible = true
	MenuKit.focus_later(_close)


func close() -> void:
	if not _root.visible:
		return
	Audio.play(&"ui_close")
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
	_fill_market()
	_fill_offers(_trade_list, refuge.trades, "Échanger")
	_fill_offers(_recruit_list, refuge.recruits, "Recruter")
	_fill_depot()


# --- Marchand : le troc -------------------------------------------------------------

## Change la quantité d'une case dans l'échange : `amount` > 0 pour prendre (étal) ou
## donner (stock), < 0 pour reposer. Bornée par ce qu'il y a vraiment.
func change(key: String, amount: int) -> void:
	var kind: String = key.get_slice(":", 0)
	var id := StringName(key.get_slice(":", 1))
	match kind:
		"stall":
			var total: int = clampi(deal.take.get(id, 0) + amount, 0, stall.goods.get(id, 0))
			Barter.Deal.change(deal.take, id, total - deal.take.get(id, 0))
		"stock":
			var total: int = clampi(deal.give.get(id, 0) + amount, 0, GameState.storage_amount(id))
			Barter.Deal.change(deal.give, id, total - deal.give.get(id, 0))
		"item":
			var item: ItemData = ItemCatalog.get_item(id)
			if amount > 0 and item in stall.items and not item in deal.items:
				deal.items.append(item)
			elif amount < 0:
				deal.items.erase(item)
		"plan":
			if amount > 0 and id in stall.plans and not id in deal.plans:
				deal.plans.append(id)
			elif amount < 0:
				deal.plans.erase(id)
	_note = ""
	_refresh_market.call_deferred()


## Fait l'échange préparé. Renvoie false s'il ne passe pas.
func trade() -> bool:
	var gear: bool = not deal.items.is_empty()
	var plans: bool = not deal.plans.is_empty()
	if not GameState.barter(refuge, deal, stall):
		return false
	_note = "Marché conclu."
	if gear:
		_note += " Équipe-le depuis l'inventaire (Pause), ici même."
	elif plans:
		_note += " Le plan est à étudier à la table des plans."
	_refresh_market.call_deferred()
	return true


## Complète ce que tu donnes avec ton surplus pour couvrir ce que tu prends.
func balance_deal() -> bool:
	var done: bool = Barter.balance(refuge, deal, GameState.storage)
	_refresh_market.call_deferred()
	return done


func clear_deal() -> void:
	deal.clear()
	_refresh_market.call_deferred()


func select(key: String) -> void:
	market_key = key
	for cell: SlotCell in _market_cells:
		cell.set_selected(cell.key == key)
	_fill_market_detail()


func _refresh_market() -> void:
	# Le focus (manette, clavier) reste sur la même case, ou sur le même bouton du bas.
	var owner: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var focus_text: String = ""
	if owner is Button and (_detail.is_ancestor_of(owner) or _deal_box.is_ancestor_of(owner)):
		focus_text = (owner as Button).text
	_fill_market()
	if not focus_text.is_empty():
		for node: Node in _detail.find_children("*", "Button", true, false) + _deal_box.find_children("*", "Button", true, false):
			if (node as Button).text == focus_text and not (node as Button).disabled:
				MenuKit.focus_later(node as Button)
				return
		_focus_market_cell()
	elif owner and owner.get_parent() is SlotCell:
		_focus_market_cell()


func _focus_market_cell() -> void:
	for cell: SlotCell in _market_cells:
		if cell.key == market_key:
			MenuKit.focus_later(cell.button)
			return


func _fill_market() -> void:
	if stall == null:
		return
	# Le stock a pu baisser (comptoir, dépôt) : on ne donne pas ce qu'on n'a plus.
	for id: StringName in deal.give.keys():
		Barter.Deal.change(deal.give, id, mini(GameState.storage_amount(id), deal.give[id]) - deal.give[id])
	MenuKit.clear(_market_list)
	_market_cells.clear()
	var head := MenuKit.header()
	var full: bool = GameState.storage_free() == 0
	head.add_child(MenuKit.chip(CRATE, "%d/%d" % [GameState.storage_total(), GameState.storage_capacity()],
		MenuKit.BAD if full else Color.WHITE, "Stock du train : on paie avec, on y range ce qu'on reçoit"))
	head.add_child(_price_hint("Pas cher ici", refuge.abundant, MenuKit.GOOD,
		"Ces ressources abondent dans cette gare : le marchand les vend moins cher et les reprend moins cher."))
	head.add_child(_price_hint("Recherché", refuge.scarce, MenuKit.GOLD,
		"Ces ressources manquent dans cette gare : le marchand les paie plus cher."))
	_market_list.add_child(head)
	# Les deux côtés du comptoir, côte à côte : l'étal à gauche, ton stock à droite.
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override(&"separation", 4)
	_market_list.add_child(sides)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.3
	left.add_theme_constant_override(&"separation", 1)
	sides.add_child(left)
	sides.add_child(VSeparator.new())
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override(&"separation", 1)
	sides.add_child(right)
	left.add_child(MenuKit.section("Étal du marchand"))
	var goods := MenuKit.grid()
	for loot: LootData in GameState.LOOT_TYPES:
		if not stall.goods.has(loot.id):
			continue
		var taken: int = deal.take.get(loot.id, 0)
		var cell := _market_cell("stall:" + String(loot.id), loot.icon, "%s · %d" % [loot.display_name,
			Barter.sell_price(refuge, loot)], str(stall.goods[loot.id] - taken))
		if taken > 0:
			cell.set_corner(CHECK)
		elif stall.goods[loot.id] == 0:
			cell.set_dim(true)
		goods.add_child(cell)
	for item: ItemData in stall.items:
		var cell := _market_cell("item:" + String(item.id), item.icon, "%s · %d" % [item.display_name, Barter.item_price(item)])
		if item in deal.items:
			cell.set_corner(CHECK)
		goods.add_child(cell)
	for plan_id: StringName in stall.plans:
		var plan: BlueprintData = BlueprintCatalog.get_plan(plan_id)
		var cell := _market_cell("plan:" + String(plan_id), PLAN, "Plan : %s · %d" % [plan.display_name, Barter.plan_price(plan)])
		if plan_id in deal.plans:
			cell.set_corner(CHECK)
		goods.add_child(cell)
	left.add_child(goods)
	right.add_child(MenuKit.section("Ton stock"))
	var mine := MenuKit.grid()
	for loot: LootData in GameState.LOOT_TYPES:
		var have: int = GameState.storage_amount(loot.id)
		if have <= 0:
			continue
		var given: int = deal.give.get(loot.id, 0)
		var cell := _market_cell("stock:" + String(loot.id), loot.icon, "%s · %d" % [loot.display_name,
			Barter.buy_price(refuge, loot)], str(have - given))
		if given > 0:
			cell.set_corner(CHECK)
		mine.add_child(cell)
	if mine.get_child_count() == 0:
		right.add_child(MenuKit.label("Stock vide.", MenuKit.MUTED))
	else:
		right.add_child(mine)
	var keys: Array = _market_cells.map(func(cell: SlotCell) -> Variant: return cell.key)
	if not market_key in keys:
		market_key = keys[0] if not keys.is_empty() else ""
	for cell: SlotCell in _market_cells:
		cell.set_selected(cell.key == market_key)
	_fill_deal()
	_fill_market_detail()


## « Pas cher ici [charbon][ferraille] » : les ressources que cette gare a en trop (ou pas).
func _price_hint(text: String, ids: Array[StringName], color: Color, tip: String) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 1)
	box.tooltip_text = tip
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	if ids.is_empty():
		return box
	var title := MenuKit.label(text, color)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)
	for id: StringName in ids:
		var loot := MenuKit.loot(id)
		if loot:
			var picture := MenuKit.icon(loot.icon, 12.0)
			picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(picture)
	return box


func _market_cell(key: String, texture: Texture2D, tip: String, count: String = "") -> SlotCell:
	var cell := SlotCell.create(texture, count, tip)
	cell.key = key
	cell.chosen.connect(select.bind(key))
	cell.focused.connect(select.bind(key))
	_market_cells.append(cell)
	return cell


## La ligne de l'échange : [ce que tu donnes] → [ce que tu prends], la balance, les boutons.
func _fill_deal() -> void:
	MenuKit.clear(_deal_box)
	if deal.is_empty():
		_deal_box.add_child(MenuKit.label(_note, MenuKit.GOOD) if not _note.is_empty()
			else MenuKit.label("Choisis sur l'étal ce que tu veux, et dans ton stock ce que tu donnes.", MenuKit.MUTED))
		return
	if deal.give.is_empty():
		_deal_box.add_child(MenuKit.label("rien", MenuKit.MUTED))
	else:
		_deal_box.add_child(MenuKit.cost_row(deal.give))
	_deal_box.add_child(MenuKit.icon(MenuKit.ARROW, 12.0))
	var taken := HBoxContainer.new()
	taken.add_theme_constant_override(&"separation", 1)
	taken.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not deal.take.is_empty():
		taken.add_child(MenuKit.cost_row(deal.take))
	for item: ItemData in deal.items:
		taken.add_child(SlotCell.create(item.icon, "", item.display_name, false, SlotCell.SMALL))
	for plan_id: StringName in deal.plans:
		taken.add_child(SlotCell.create(PLAN, "", "Plan : " + BlueprintCatalog.get_plan(plan_id).display_name, false, SlotCell.SMALL))
	if taken.get_child_count() == 0:
		taken.add_child(MenuKit.label("rien", MenuKit.MUTED))
	_deal_box.add_child(taken)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deal_box.add_child(spacer)
	var given: int = Barter.given_value(refuge, deal)
	var asked: int = Barter.taken_value(refuge, deal)
	var tip: String = "Ce que tu donnes vaut %d, ce que tu prends %d." % [given, asked]
	if given > asked and not deal.takes_nothing():
		tip += "
Le marchand garde la différence (%d)." % (given - asked)
	_deal_box.add_child(MenuKit.chip(BALANCE, "%d/%d" % [given, asked], MenuKit.GOOD if given >= asked else MenuKit.BAD, tip))
	var problem: Barter.Problem = GameState.barter_problem(refuge, deal, stall)
	if given < asked:
		_deal_box.add_child(MenuKit.action("Compléter", func() -> void: balance_deal(), false,
			"Ajoute ce que tu as le plus dans ton stock jusqu'à payer le prix."))
	_deal_box.add_child(MenuKit.action("Vider", clear_deal))
	var why: String = Barter.PROBLEM_TEXTS.get(problem, "")
	_deal_box.add_child(MenuKit.action("Échanger", func() -> void: trade(), problem != Barter.Problem.NONE, why, &"pickup"))


## La barre du bas : la case choisie, son prix, et ce qu'on en fait (prendre, donner).
func _fill_market_detail() -> void:
	MenuKit.clear(_detail)
	var kind: String = market_key.get_slice(":", 0)
	var id := StringName(market_key.get_slice(":", 1))
	match kind:
		"stall", "stock":
			var loot := MenuKit.loot(id)
			if loot == null:
				return
			var from_stall: bool = kind == "stall"
			var left: int = stall.goods.get(id, 0) - deal.take.get(id, 0) if from_stall \
				else GameState.storage_amount(id) - deal.give.get(id, 0)
			var price: int = Barter.sell_price(refuge, loot) if from_stall else Barter.buy_price(refuge, loot)
			var text: String = ("Le marchand le vend %d la pièce." if from_stall else "Le marchand t'en donne %d la pièce.") % price
			if id in refuge.abundant:
				text += " Abonde ici."
			elif id in refuge.scarce:
				text += " Recherché ici."
			MenuKit.detail_info(_detail, loot.icon, "%s ×%d %s" % [loot.display_name, left,
				"sur l'étal" if from_stall else "dans ton stock"], text)
			var chosen: int = deal.take.get(id, 0) if from_stall else deal.give.get(id, 0)
			_detail.add_child(MenuKit.chip(BALANCE, str(price), MenuKit.GOLD, "Prix d'une pièce"))
			_detail.add_child(MenuKit.label(("Pris %d" if from_stall else "Donné %d") % chosen, MenuKit.GOOD if chosen > 0 else MenuKit.MUTED))
			_detail.add_child(MenuKit.action("−1", change.bind(market_key, -1), chosen == 0))
			_detail.add_child(MenuKit.action("+1", change.bind(market_key, 1), left == 0))
			_detail.add_child(MenuKit.action("+5", change.bind(market_key, 5), left == 0))
		"item":
			var item: ItemData = ItemCatalog.get_item(id)
			if item == null:
				return
			MenuKit.detail_info(_detail, item.icon, "%s · %s" % [item.display_name, item.slot_name()], item.describe_effects())
			_detail.add_child(MenuKit.chip(BALANCE, str(Barter.item_price(item)), MenuKit.GOLD, "Prix"))
			var picked: bool = item in deal.items
			_detail.add_child(MenuKit.action("Reposer" if picked else "Prendre", change.bind(market_key, -1 if picked else 1)))
		"plan":
			var plan: BlueprintData = BlueprintCatalog.get_plan(id)
			if plan == null:
				return
			MenuKit.detail_info(_detail, PLAN, "Plan : " + plan.display_name,
				plan.effect_text + " À étudier à la table des plans.")
			_detail.add_child(MenuKit.chip(BALANCE, str(Barter.plan_price(plan)), MenuKit.GOLD, "Prix"))
			var picked: bool = id in deal.plans
			_detail.add_child(MenuKit.action("Reposer" if picked else "Prendre", change.bind(market_key, -1 if picked else 1)))


# --- Comptoir, recrutement -----------------------------------------------------------

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
		problem != RefugeRules.Problem.NONE, why, &"pickup")
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
			"Il manque des matériaux dans le stock.", &"craft"))
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
			GameState.locked_text(&"build") if not allowed else "Il manque des matériaux dans le stock.", &"build"))
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
