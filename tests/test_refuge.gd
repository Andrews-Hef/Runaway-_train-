extends TestCase
## Gares refuges : une tous les 5 arrêts, zone sûre, échanges et recrues payés avec le stock.

const REFUGE_SCENE: PackedScene = preload("res://levels/refuge/refuge.tscn")


func before_each() -> void:
	GameState.new_run(31)


func after_each() -> void:
	GameState.new_run()


func _go_to_stop(number: int) -> void:
	while GameState.stop_number < number:
		GameState.prepare_next_stop()


func _offer(cost: Dictionary[StringName, int], reward: Dictionary[StringName, int], role: StringName = &"") -> RefugeOffer:
	var offer := RefugeOffer.new()
	offer.cost = cost
	offer.reward = reward
	offer.recruit_role = role
	offer.recruit_role_label = "test"
	return offer


func test_une_gare_refuge_tous_les_5_arrets() -> void:
	for number: int in range(1, 16):
		_go_to_stop(number)
		assert_true(GameState.is_refuge_stop() == (number % 5 == 0), "arrêt n°%d" % number)
	assert_true(GameState.current_refuge == GameState.REFUGES[2 % GameState.REFUGES.size()], "3e gare : on reprend la liste")


func test_apres_la_gare_on_retrouve_une_zone() -> void:
	_go_to_stop(5)
	assert_true(GameState.stop_name() == GameState.REFUGES[0].display_name, "nom de la gare")
	_go_to_stop(6)
	assert_false(GameState.is_refuge_stop(), "arrêt 6 : zone")
	assert_true(GameState.current_zone != null and GameState.stop_name() == GameState.current_zone.display_name, "nom de la zone")


func test_la_prochaine_gare() -> void:
	_go_to_stop(3)
	assert_true(GameState.next_refuge_stop() == 5, "depuis l'arrêt 3")
	_go_to_stop(5)
	assert_true(GameState.next_refuge_stop() == 5, "on y est")
	_go_to_stop(7)
	assert_true(GameState.next_refuge_stop() == 10, "depuis l'arrêt 7")


func test_un_echange_paie_et_rapporte() -> void:
	GameState.storage[&"herb"] = 5
	var offer := _offer({&"herb": 4}, {&"parts": 1})
	assert_true(GameState.use_refuge_offer(offer, RandomNumberGenerator.new()), "échange fait")
	assert_true(GameState.storage_amount(&"herb") == 1 and GameState.storage_amount(&"parts") == 1, "4 plantes -> 1 pièce")
	assert_false(GameState.use_refuge_offer(offer, RandomNumberGenerator.new()), "plus assez de plantes")


func test_un_echange_doit_rentrer_dans_le_stock() -> void:
	GameState.storage[&"scrap"] = 59
	var offer := _offer({&"scrap": 1}, {&"wood": 3})
	assert_true(RefugeRules.problem(offer, GameState.storage, GameState.storage_free(), 4) == RefugeRules.Problem.NO_SPACE, "stock trop plein")


func test_une_recrue_de_la_gare_est_saine_et_prend_une_couchette() -> void:
	GameState.storage[&"herb"] = 20
	var offer := _offer({&"herb": 2}, {}, &"medic")
	assert_false(GameState.use_refuge_offer(offer, RandomNumberGenerator.new()), "une recrue ne recrute pas encore")
	GameState.merit = Career.GRADES[Career.AUTHORITY[&"recruit"]].merit_needed
	assert_true(GameState.use_refuge_offer(offer, RandomNumberGenerator.new()), "recrutée")
	assert_true(GameState.crew.size() == 1 and not GameState.crew[0].infected, "une recrue saine")
	assert_true(RefugeRules.problem(offer, GameState.storage, 60, 3, true) == RefugeRules.Problem.ALREADY_DONE, "une fois par passage")
	assert_true(RefugeRules.problem(offer, GameState.storage, 60, 0) == RefugeRules.Problem.NO_BED, "il faut une couchette")


func test_les_gares_ont_des_offres() -> void:
	for refuge: RefugeData in GameState.REFUGES:
		assert_false(refuge.trades.is_empty(), "%s : échanges" % refuge.id)
		assert_false(refuge.recruits.is_empty(), "%s : recrues" % refuge.id)
		for offer: RefugeOffer in refuge.recruits:
			assert_true(offer.recruits(), "%s : %s recrute" % [refuge.id, offer.label])


func test_la_scene_de_la_gare() -> void:
	_go_to_stop(5)
	var scene: Node = REFUGE_SCENE.instantiate()
	tree.root.add_child(scene)
	for expected: String in ["Station_trade", "Station_recruit", "Station_depot"]:
		assert_true(scene.get_node("World").has_node(expected), "%s manquant" % expected)
	var train: Train = scene.get_node("World/Train")
	assert_true(train.door.prompt == "Repartir", "la porte du train sert à repartir")
	scene.free()


func test_le_levier_mene_a_la_gare() -> void:
	_go_to_stop(5)
	var interior: Node = (load("res://levels/train_interior/train_interior.tscn") as PackedScene).instantiate()
	tree.root.add_child(interior)
	assert_true(interior.call(&"next_scene") == "res://levels/refuge/refuge.tscn", "arrêt 5 : la gare")
	interior.free()
	_go_to_stop(6)
	interior = (load("res://levels/train_interior/train_interior.tscn") as PackedScene).instantiate()
	tree.root.add_child(interior)
	assert_true(interior.call(&"next_scene") == "res://levels/stop_zone/stop_zone.tscn", "arrêt 6 : une zone")
	interior.free()
