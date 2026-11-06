extends TestCase
## Rencontres, gares refuges et bilan en cases : un échange se lit « donne → reçois »,
## ce qui manque est en rouge, le butin du retour est une rangée de cases.

const DIALOG: PackedScene = preload("res://ui/encounter/encounter_dialog.tscn")
const DialogScript = preload("res://ui/encounter/encounter_dialog.gd")
const REFUGE_MENU: PackedScene = preload("res://ui/refuge/refuge_menu.tscn")
const RESULT: PackedScene = preload("res://ui/result/result_screen.tscn")
const SCRAPPER: EncounterData = preload("res://data/encounters/merchant_scrapper.tres")
const FORT_CENDRE: RefugeData = preload("res://data/refuges/fort_cendre.tres")

var _nodes: Array[Node] = []


func before_each() -> void:
	GameState.new_run(13)


func after_each() -> void:
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	GameState.new_run()


func _add(scene: PackedScene) -> Node:
	var node: Node = scene.instantiate()
	tree.root.add_child(node)
	_nodes.append(node)
	return node


static func _slot_cells(node: Node) -> Array[Node]:
	return node.find_children("*", "SlotCell", true, false)


func test_un_echange_de_rencontre_se_lit_en_cases() -> void:
	var dialog: Node = _add(DIALOG)
	var carrying := ExpeditionResult.new()
	carrying.add_loot(&"herb", 2)
	dialog.call(&"open", SCRAPPER, carrying, 8, 2, true)
	var buttons: Array[Node] = dialog.get_node("%Choices").get_children()
	assert_true(buttons.size() == SCRAPPER.choices.size(), "un bouton par choix")
	var trade: EncounterChoice = SCRAPPER.choices[0]
	assert_true(DialogScript._is_trade(trade), "« %s » est un échange" % trade.label)
	var first: Button = buttons[0]
	assert_true(first.text.is_empty(), "pas de phrase : des cases")
	assert_true(_slot_cells(first).size() == trade.cost.size() + trade.reward.size(), "donne et reçois, en cases")
	assert_false(first.disabled, "2 plantes en poche : possible")
	assert_true(first.custom_minimum_size.x > 0.0, "le bouton prend la largeur de ses cases")
	var leave: int = SCRAPPER.choices.find(SCRAPPER.choices.filter(func(c: EncounterChoice) -> bool: return c.leave)[0])
	assert_false(DialogScript._is_trade(SCRAPPER.choices[leave]), "Partir garde son texte")


func test_ce_qui_bloque_un_choix_se_dit_en_deux_mots() -> void:
	assert_true(DialogScript._reason({EncounterResolver.NO_SPACE: 1} as Dictionary[StringName, int]) == "sac plein", "sac plein")
	assert_true(DialogScript._reason({EncounterResolver.NO_BED: 1} as Dictionary[StringName, int]) == "pas de couchette", "couchette")
	assert_true(DialogScript._reason({&"wood": 2} as Dictionary[StringName, int]).is_empty(), "il manque : le nombre en rouge suffit")


func test_le_resultat_d_une_rencontre_montre_les_gains_en_cases() -> void:
	var dialog: Node = _add(DIALOG)
	dialog.call(&"open", SCRAPPER, ExpeditionResult.new(), 8, 2, true)
	dialog.call(&"show_outcome", "Marché conclu.", {&"scrap": 3} as Dictionary[StringName, int], true)
	var gains: Control = dialog.find_child("Gains", true, false)
	assert_true(gains != null and gains.visible, "les gains s'affichent")
	assert_true(_slot_cells(gains).size() == 1, "une case : la ferraille")


func test_le_comptoir_de_la_gare_echange_depuis_sa_carte() -> void:
	var menu: Node = _add(REFUGE_MENU)
	menu.call(&"setup", FORT_CENDRE, 3)
	var offer: RefugeOffer = FORT_CENDRE.trades.filter(func(o: RefugeOffer) -> bool: return o.reward_plan == &"")[0]
	for id: StringName in offer.cost:
		GameState.storage[id] = offer.cost[id]
	menu.call(&"open", 0)
	var cards: Array[Node] = menu.get_node("%TradeList").find_children("*", "PanelContainer", true, false).filter(
		func(node: Node) -> bool: return not node is SlotCell)
	assert_true(cards.size() == FORT_CENDRE.trades.size(), "une carte par offre (obtenu %d)" % cards.size())
	var index: int = FORT_CENDRE.trades.find(offer)
	var button: Button = null
	for node: Node in cards[index].find_children("*", "Button", true, false):
		if (node as Button).text == "Échanger":
			button = node
	assert_true(button != null and not button.disabled, "Échanger est prêt")
	var reward: StringName = offer.reward.keys()[0]
	var before: int = GameState.storage_amount(reward)
	button.pressed.emit()
	assert_true(GameState.storage_amount(reward) > before, "reçu dans le stock")


func test_le_bilan_montre_le_butin_en_cases() -> void:
	var screen: Node = _add(RESULT)
	var result := ExpeditionResult.new()
	result.boarded = true
	result.add_loot(&"scrap", 6)
	result.add_loot(&"herb", 2)
	result.plans.append(&"armory")
	screen.call(&"show_result", result, GameState.LOOT_TYPES)
	var cells: Array[Node] = _slot_cells(screen.get_node("%LootList"))
	assert_true(cells.size() == 3, "ferraille, plantes, plan (obtenu %d)" % cells.size())
