extends TestCase
## Le marchand des gares refuge : troc libre (ce que tu donnes doit valoir au moins ce que
## tu prends), équipements et plans à acheter avec des ressources.

const REFUGE_MENU: PackedScene = preload("res://ui/refuge/refuge_menu.tscn")
const FORT_CENDRE: RefugeData = preload("res://data/refuges/fort_cendre.tres")
const VIREUX: RefugeData = preload("res://data/refuges/vireux.tres")
const SCRAP: LootData = preload("res://data/loot/scrap.tres")
const COAL: LootData = preload("res://data/loot/coal.tres")
const HERB: LootData = preload("res://data/loot/herb.tres")
const ANTIBIOTICS: LootData = preload("res://data/loot/antibiotics.tres")

var _nodes: Array[Node] = []


func before_each() -> void:
	GameState.new_run(57)


func after_each() -> void:
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	GameState.new_run()


func _stall(goods: Dictionary[StringName, int]) -> Barter.Stall:
	var stall := Barter.Stall.new()
	stall.goods = goods
	return stall


func _menu() -> Node:
	var menu: Node = REFUGE_MENU.instantiate()
	tree.root.add_child(menu)
	_nodes.append(menu)
	return menu


# --- Prix ------------------------------------------------------------------------------

func test_chaque_ressource_a_une_valeur() -> void:
	for loot: LootData in GameState.LOOT_TYPES:
		assert_true(loot.value > 0, "%s a une valeur" % loot.id)
	assert_true(ANTIBIOTICS.value > HERB.value * 5, "un remède vaut bien plus qu'une plante")


func test_le_marchand_vend_plus_cher_qu_il_ne_reprend() -> void:
	for loot: LootData in GameState.LOOT_TYPES:
		assert_true(Barter.sell_price(null, loot) > Barter.buy_price(null, loot),
			"%s : vendu %d, repris %d" % [loot.id, Barter.sell_price(null, loot), Barter.buy_price(null, loot)])


func test_une_gare_paie_plus_ce_qui_lui_manque() -> void:
	assert_true(&"coal" in FORT_CENDRE.abundant and &"coal" in VIREUX.scarce, "le charbon abonde à Fort-Cendre, manque à Vireux")
	assert_true(Barter.sell_price(FORT_CENDRE, COAL) < Barter.sell_price(VIREUX, COAL), "moins cher là où il abonde")
	assert_true(Barter.buy_price(VIREUX, COAL) > Barter.buy_price(FORT_CENDRE, COAL), "mieux payé là où il manque")


func test_pas_d_argent_facile_en_achetant_et_revendant() -> void:
	# Acheter à Fort-Cendre puis revendre à Vireux ne doit pas rapporter : sinon on
	# boucle entre deux gares pour remplir le train.
	for loot: LootData in GameState.LOOT_TYPES:
		var bought: int = Barter.sell_price(FORT_CENDRE, loot)
		var sold: int = Barter.buy_price(VIREUX, loot)
		assert_true(sold <= bought * 1.15, "%s : acheté %d, revendu %d" % [loot.id, bought, sold])
		assert_true(Barter.buy_price(FORT_CENDRE, loot) < bought, "%s : perte sur place" % loot.id)


func test_un_equipement_coute_sa_recette_et_le_travail() -> void:
	for item: ItemData in ItemCatalog.ALL:
		if item.starter:
			continue
		assert_true(Barter.item_price(item) > 0 and Barter.item_price(item) % 5 == 0, "%s : prix rond" % item.id)
	var cheap: ItemData = ItemCatalog.get_item(&"tool_crowbar")
	var dear: ItemData = ItemCatalog.get_item(&"bag_military")
	assert_true(Barter.item_price(dear) > Barter.item_price(cheap), "un sac militaire coûte plus qu'un pied-de-biche")


# --- L'étal -----------------------------------------------------------------------------

func test_l_etal_est_le_meme_pour_un_meme_passage() -> void:
	var a := GameState.market_stall(FORT_CENDRE, 99)
	var b := GameState.market_stall(FORT_CENDRE, 99)
	assert_true(a.goods == b.goods and a.items == b.items and a.plans == b.plans, "même gare, même graine : même étal")
	var c := GameState.market_stall(VIREUX, 99)
	assert_true(a.goods != c.goods or a.items != c.items, "une autre gare a un autre étal")


func test_l_etal_ne_vend_pas_ce_qu_on_a_deja() -> void:
	for seed_value: int in range(20):
		var stall := Barter.stall(FORT_CENDRE, seed_value, GameState.owned_items, GameState.LOOT_TYPES, [], 3)
		assert_true(stall.items.size() == Barter.ITEMS_FOR_SALE, "%d équipements à vendre" % Barter.ITEMS_FOR_SALE)
		for item: ItemData in stall.items:
			assert_false(item in GameState.owned_items or item.starter, "%s : pas déjà possédé" % item.id)
		assert_true(stall.goods.get(&"scrap", 0) > 0 and stall.goods.get(&"coal", 0) > 0,
			"Fort-Cendre a toujours de la ferraille et du charbon")


func test_la_premiere_gare_ne_vend_pas_le_meilleur_equipement() -> void:
	assert_true(Barter.max_tier(5) == 2 and Barter.max_tier(10) == 3, "rang 2 à la 1re gare, 3 ensuite")
	for seed_value: int in range(20):
		for item: ItemData in Barter.stall(FORT_CENDRE, seed_value, [], GameState.LOOT_TYPES, [], 2).items:
			assert_true(item.tier <= 2, "%s : rang %d" % [item.id, item.tier])


func test_l_etal_propose_parfois_un_plan_inconnu() -> void:
	var seen: int = 0
	for seed_value: int in range(30):
		var stall := Barter.stall(VIREUX, seed_value, [], GameState.LOOT_TYPES, [&"armory"] as Array[StringName], 3)
		seen += stall.plans.size()
		assert_true(stall.plans.is_empty() or (stall.plans.size() == 1 and stall.plans[0] == &"armory"), "seulement un plan encore inconnu")
	assert_true(seen > 5 and seen < 30, "souvent, pas toujours (vu %d fois sur 30)" % seen)


# --- L'échange --------------------------------------------------------------------------

func test_un_echange_passe_si_on_donne_assez() -> void:
	var stall := _stall({&"coal": 5})
	var storage: Dictionary[StringName, int] = {&"scrap": 20}
	var deal := Barter.Deal.new()
	deal.take[&"coal"] = 2
	deal.give[&"scrap"] = 2
	assert_true(Barter.problem(null, deal, stall, storage, 100, []) == Barter.Problem.NOT_ENOUGH, "2 ferrailles ne valent pas 2 charbons")
	assert_true(Barter.balance(null, deal, storage), "on complète avec la ferraille")
	assert_true(Barter.given_value(null, deal) >= Barter.taken_value(null, deal), "la balance est juste")
	assert_true(Barter.problem(null, deal, stall, storage, 100, []) == Barter.Problem.NONE, "ça passe")
	var given: int = deal.give[&"scrap"]
	Barter.apply(null, deal, stall, storage, [])
	assert_true(storage[&"coal"] == 2 and storage[&"scrap"] == 20 - given, "le stock change")
	assert_true(stall.goods[&"coal"] == 3 and stall.goods[&"scrap"] == given, "l'étal reprend la ferraille")
	assert_true(deal.is_empty(), "l'échange est vidé")


func test_on_ne_donne_pas_ce_qu_on_n_a_pas() -> void:
	var deal := Barter.Deal.new()
	deal.take[&"coal"] = 1
	deal.give[&"parts"] = 3
	var storage: Dictionary[StringName, int] = {&"parts": 1}
	assert_true(Barter.problem(null, deal, _stall({&"coal": 5}), storage, 100, []) == Barter.Problem.MISSING, "pas 3 pièces")
	deal.give[&"parts"] = 1
	deal.take[&"coal"] = 9
	assert_true(Barter.problem(null, deal, _stall({&"coal": 5}), storage, 100, []) == Barter.Problem.MERCHANT_SHORT, "il n'en a que 5")


func test_le_stock_plein_bloque() -> void:
	var deal := Barter.Deal.new()
	deal.take[&"scrap"] = 6
	deal.give[&"antibiotics"] = 1
	var storage: Dictionary[StringName, int] = {&"antibiotics": 1}
	assert_true(Barter.problem(null, deal, _stall({&"scrap": 10}), storage, 2, []) == Barter.Problem.NO_SPACE, "6 entrent, 1 sort, 2 places")
	assert_true(Barter.problem(null, deal, _stall({&"scrap": 10}), storage, 5, []) == Barter.Problem.NONE, "5 places : ça entre")


func test_completer_garde_les_remedes() -> void:
	var deal := Barter.Deal.new()
	deal.take[&"coal"] = 1
	var storage: Dictionary[StringName, int] = {&"antibiotics": 3, &"wood": 1}
	assert_false(Barter.balance(null, deal, storage), "1 bois ne suffit pas, et les remèdes ne partent pas d'office")
	assert_true(deal.give.is_empty(), "rien n'est ajouté quand ça ne suffit pas")


func test_acheter_un_equipement_et_un_plan() -> void:
	GameState.storage[&"scrap"] = 60
	GameState.storage[&"metal_plate"] = 20
	var stall := Barter.Stall.new()
	var item: ItemData = ItemCatalog.get_item(&"tool_crowbar")
	GameState.owned_items.erase(item)
	stall.items.append(item)
	stall.plans.append(&"armory")
	var deal := Barter.Deal.new()
	deal.items.append(item)
	deal.plans.append(&"armory")
	assert_true(Barter.balance(null, deal, GameState.storage), "le stock paie")
	assert_true(GameState.barter(null, deal, stall), "acheté")
	assert_true(item in GameState.owned_items, "l'équipement est à nous")
	assert_true(&"armory" in GameState.found_plans, "le plan est à étudier")
	assert_true(stall.items.is_empty() and stall.plans.is_empty(), "plus sur l'étal")
	stall.items.append(item)
	deal.items.append(item)
	assert_true(GameState.barter_problem(null, deal, stall) == Barter.Problem.OWNED, "on ne le rachète pas")


# --- Le menu ----------------------------------------------------------------------------

func test_le_marchand_s_ouvre_sur_l_etal_et_le_stock() -> void:
	GameState.storage = {&"scrap": 30, &"herb": 4} as Dictionary[StringName, int]
	var menu := _menu()
	menu.call(&"setup", FORT_CENDRE, 12)
	menu.call(&"open", 0)
	var stall: Barter.Stall = menu.get(&"stall")
	var cells: Array[Node] = menu.get_node("%MarketList").find_children("*", "SlotCell", true, false)
	var expected: int = stall.goods.size() + stall.items.size() + stall.plans.size() + 2
	assert_true(cells.size() == expected, "une case par marchandise et par ressource du stock (%d/%d)" % [cells.size(), expected])
	assert_true((menu.get_node("%Tabs") as TabContainer).get_tab_title(0) == "Marchand", "premier onglet : le marchand")


func test_troquer_depuis_le_menu() -> void:
	GameState.storage = {&"scrap": 40} as Dictionary[StringName, int]
	var menu := _menu()
	menu.call(&"setup", FORT_CENDRE, 12)
	menu.call(&"open", 0)
	var stall: Barter.Stall = menu.get(&"stall")
	stall.goods[&"coal"] = 6
	menu.call(&"change", "stall:coal", 5)
	menu.call(&"change", "stall:coal", 5)
	var deal: Barter.Deal = menu.get(&"deal")
	assert_true(deal.take[&"coal"] == 6, "borné à ce que le marchand a")
	menu.call(&"change", "stall:coal", -4)
	assert_false(menu.call(&"trade"), "rien donné : pas d'échange")
	assert_true(menu.call(&"balance_deal"), "Compléter avec la ferraille")
	assert_true(menu.call(&"trade"), "échangé")
	assert_true(GameState.storage_amount(&"coal") == 2, "2 charbons dans le stock")
	assert_true(GameState.storage_amount(&"scrap") < 40, "payé en ferraille")
	assert_true(stall.goods[&"coal"] == 4, "il en reste 4 sur l'étal")


func test_la_barre_du_bas_prend_et_repose() -> void:
	GameState.storage = {&"scrap": 10} as Dictionary[StringName, int]
	var menu := _menu()
	menu.call(&"setup", FORT_CENDRE, 12)
	menu.call(&"open", 0)
	menu.call(&"select", "stock:scrap")
	var plus: Button = null
	for node: Node in menu.get_node("%Detail").find_children("*", "Button", true, false):
		if (node as Button).text == "+5":
			plus = node
	assert_true(plus != null and not plus.disabled, "+5 est là")
	plus.pressed.emit()
	plus.pressed.emit()
	plus.pressed.emit()
	assert_true((menu.get(&"deal") as Barter.Deal).give[&"scrap"] == 10, "on ne donne pas plus que le stock")
	menu.call(&"clear_deal")
	assert_true((menu.get(&"deal") as Barter.Deal).is_empty(), "Vider")
