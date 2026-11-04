extends TestCase
## Agrandissement des voitures : niveaux, coûts, plan du niveau 3, effets, sauvegarde.

const DORMITORY: WagonData = preload("res://data/wagons/dormitory.tres")
const STOCK: WagonData = preload("res://data/wagons/stock.tres")
const GREENHOUSE: WagonData = preload("res://data/wagons/greenhouse.tres")
const INFIRMARY: WagonData = preload("res://data/wagons/infirmary.tres")


func before_each() -> void:
	GameState.new_run(321)


func after_each() -> void:
	GameState.new_run()


func _fill(amount: int = 40) -> void:
	for loot: LootData in GameState.LOOT_TYPES:
		if not loot.is_medicine():
			GameState.storage[loot.id] = amount


func test_agrandir_le_dortoir_donne_des_couchettes() -> void:
	_fill()
	assert_true(GameState.beds() == 4, "4 couchettes au départ")
	assert_true(GameState.upgrade_wagon(DORMITORY), "niv. 2")
	assert_true(GameState.wagon_level(&"dormitory") == 2 and GameState.beds() == 6, "6 couchettes")


func test_le_niveau_3_demande_le_plan_amenagement() -> void:
	_fill()
	GameState.upgrade_wagon(DORMITORY)
	assert_true(GameState.upgrade_wagon_problem(DORMITORY) == TrainRules.Problem.NEEDS_PLAN, "plan Aménagement d'abord")
	GameState.researched_plans.append(&"outfitting")
	assert_true(GameState.upgrade_wagon(DORMITORY), "niv. 3")
	assert_true(GameState.beds() == 8, "8 couchettes")
	assert_true(GameState.upgrade_wagon_problem(DORMITORY) == TrainRules.Problem.MAX_LEVEL, "niveau maximum")


func test_le_cout_compte_chaque_voiture_du_type() -> void:
	var one: Dictionary[StringName, int] = TrainRules.upgrade_cost(STOCK, 2, 1)
	var two: Dictionary[StringName, int] = TrainRules.upgrade_cost(STOCK, 2, 2)
	for id: StringName in one:
		assert_true(two[id] == one[id] * 2, "%s ×2" % id)
	_fill()
	GameState.build_wagon(STOCK)
	var wood: int = GameState.storage_amount(&"wood")
	assert_true(GameState.upgrade_wagon(STOCK), "deux stocks agrandis d'un coup")
	assert_true(GameState.storage_amount(&"wood") == wood - two[&"wood"], "payé pour deux")
	assert_true(GameState.storage_capacity() == 2 * (60 + 30), "180 places")


func test_on_n_agrandit_que_ce_qu_on_a() -> void:
	_fill()
	assert_false(GameState.upgrade_wagon(GREENHOUSE), "pas de serre dans le train")


func test_la_serre_agrandie_produit_plus() -> void:
	GameState.storage = {&"wood": 6, &"cloth": 2, &"herb": 4}
	GameState.train.insert(0, GREENHOUSE)
	assert_true(GameState.upgrade_wagon(GREENHOUSE), "serre niv. 2")
	GameState.prepare_next_stop()
	assert_true(GameState.last_production.get(&"herb", 0) == 3, "3 plantes par trajet")


func test_l_infirmerie_agrandie_rend_les_medicaments_plus_efficaces() -> void:
	_fill()
	GameState.train.insert(0, INFIRMARY)
	GameState.upgrade_wagon(INFIRMARY)
	GameState.infection = 0.5
	GameState.storage[&"antiseptic"] = 1
	var antiseptic: LootData = preload("res://data/loot/antiseptic.tres")
	assert_true(GameState.take_medicine(antiseptic), "pris")
	assert_almost(GameState.infection, 0.35, "10 + 5 points")


func test_l_interieur_montre_le_niveau() -> void:
	_fill()
	GameState.upgrade_wagon(DORMITORY)
	var interior: Node = (load("res://levels/train_interior/train_interior.tscn") as PackedScene).instantiate()
	tree.root.add_child(interior)
	var signs: Array[String] = []
	for child: Node in interior.get_node("Train/Floors").get_children():
		if child is Label:
			signs.append((child as Label).text)
	assert_true("Dortoir niv. 2" in signs, "panneau : %s" % [signs])
	interior.free()


func test_les_niveaux_se_sauvegardent() -> void:
	_fill()
	GameState.upgrade_wagon(STOCK)
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_save()))
	GameState.new_run(1)
	assert_true(GameState.load_save(data), "relue")
	assert_true(GameState.wagon_level(&"stock") == 2 and GameState.storage_capacity() == 90, "stock niv. 2")
