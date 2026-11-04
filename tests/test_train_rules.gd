extends TestCase
## Règles du train : la locomotive limite le nombre de voitures, les voitures se
## construisent avec le stock, dortoirs = couchettes, wagons de stock = places.

const DORMITORY: WagonData = preload("res://data/wagons/dormitory.tres")
const STOCK: WagonData = preload("res://data/wagons/stock.tres")
const CABIN: WagonData = preload("res://data/wagons/cabin.tres")


func before_each() -> void:
	GameState.new_run(77)


func after_each() -> void:
	GameState.new_run()


## Remplit le stock de tout ce qu'il faut pour construire et renforcer.
func _fill_storage(amount: int = 200) -> void:
	for loot: LootData in GameState.LOOT_TYPES:
		GameState.storage[loot.id] = amount


func _recruit_choice() -> EncounterChoice:
	var choice := EncounterChoice.new()
	choice.recruit_role = &"mechanic"
	choice.recruit_role_label = "mécanique"
	return choice


func test_le_train_de_depart() -> void:
	assert_true(GameState.train.size() == 4, "4 voitures au départ")
	assert_true(GameState.train.back() == CABIN, "la cabine est en tête")
	assert_true(GameState.max_cars() == 5, "la locomotive niv. 1 tire 5 voitures")
	assert_true(GameState.beds() == 4, "4 couchettes")
	assert_true(GameState.storage_capacity() == 60, "60 places de stock")


func test_la_locomotive_plafonne_a_8_voitures() -> void:
	assert_true(TrainRules.max_cars(TrainRules.max_level()) == 8, "8 voitures au dernier niveau")
	for level: int in range(1, TrainRules.max_level()):
		assert_true(TrainRules.max_cars(level + 1) == TrainRules.max_cars(level) + 1, "une voiture de plus par niveau")


func test_construire_paie_et_attelle_en_queue() -> void:
	_fill_storage(20)
	assert_true(GameState.build_wagon(DORMITORY), "dortoir construit")
	assert_true(GameState.train.size() == 5, "5 voitures")
	assert_true(GameState.train[0] == DORMITORY, "attelé en queue")
	assert_true(GameState.train.back() == CABIN, "la cabine reste en tête")
	assert_true(GameState.beds() == 8, "8 couchettes")
	assert_true(GameState.storage_amount(&"wood") == 20 - DORMITORY.cost[&"wood"], "bois payé")


func test_sans_traction_on_ne_construit_pas() -> void:
	_fill_storage()
	assert_true(GameState.build_wagon(STOCK), "5e voiture")
	var wood: int = GameState.storage_amount(&"wood")
	assert_false(GameState.build_wagon(STOCK), "pas de 6e voiture au niveau 1")
	assert_true(TrainRules.build_problem(STOCK, GameState.train, GameState.locomotive_level, GameState.storage) == TrainRules.Problem.NO_TRACTION, "problème : traction")
	assert_true(GameState.storage_amount(&"wood") == wood, "rien n'est payé")


func test_renforcer_la_locomotive_jusqu_au_maximum() -> void:
	_fill_storage()
	for level: int in range(2, TrainRules.max_level() + 1):
		assert_true(GameState.upgrade_locomotive(), "niveau %d" % level)
	assert_true(GameState.max_cars() == 8, "8 voitures")
	assert_false(GameState.upgrade_locomotive(), "pas au-delà du maximum")
	assert_true(TrainRules.upgrade_problem(GameState.locomotive_level, GameState.storage) == TrainRules.Problem.MAX_LEVEL, "problème : niveau max")
	while GameState.build_wagon(STOCK):
		pass
	assert_true(GameState.train.size() == 8, "on remplit jusqu'à 8 voitures")


func test_sans_materiaux_rien_ne_se_passe() -> void:
	assert_false(GameState.build_wagon(DORMITORY), "stock vide")
	assert_false(GameState.upgrade_locomotive(), "stock vide")
	assert_true(GameState.train.size() == 4 and GameState.locomotive_level == 1, "train inchangé")


func test_la_cabine_ne_se_construit_pas_et_les_uniques_non_plus() -> void:
	_fill_storage()
	assert_true(TrainRules.build_problem(CABIN, GameState.train, 4, GameState.storage) == TrainRules.Problem.NOT_BUILDABLE, "cabine")
	var unique := WagonData.new()
	unique.unique = true
	unique.cost = {&"wood": 1}
	var train: Array[WagonData] = [unique, CABIN]
	assert_true(TrainRules.build_problem(unique, train, 4, GameState.storage) == TrainRules.Problem.ALREADY_THERE, "unique déjà là")


func test_le_stock_plein_laisse_le_reste_sur_le_quai() -> void:
	var result := ExpeditionResult.new()
	result.boarded = true
	result.add_loot(&"scrap", 50)
	result.add_loot(&"wood", 20)
	GameState.record_expedition(result)
	assert_true(GameState.storage_total() == 60, "stock rempli à 60")
	assert_true(result.left_behind.get(&"wood", 0) == 10, "10 bois laissés sur le quai")
	assert_true(GameState.storage_free() == 0, "plus de place")


func test_un_wagon_de_stock_ajoute_des_places() -> void:
	_fill_storage(10)
	GameState.build_wagon(STOCK)
	assert_true(GameState.storage_capacity() == 120, "120 places")


func test_plus_de_couchette_plus_de_recrue() -> void:
	var choice := _recruit_choice()
	var result := ExpeditionResult.new()
	assert_true(EncounterResolver.can_afford(choice, result, -1, 1), "une couchette libre")
	assert_true(EncounterResolver.missing(choice, result, -1, 0).has(EncounterResolver.NO_BED), "aucune couchette")
	EncounterResolver.apply(choice, result, RandomNumberGenerator.new())
	assert_false(EncounterResolver.can_afford(choice, result, -1, 1), "la recrue de la sortie a pris la couchette")
	var trade := EncounterChoice.new()
	assert_true(EncounterResolver.can_afford(trade, result, -1, 0), "les autres choix restent possibles")


func test_l_arret_refuse_une_recrue_sans_couchette() -> void:
	for i: int in 4:
		GameState.crew.append(CrewMember.create("R%d" % i, &"scout", "repérage", false))
	assert_true(GameState.free_beds() == 0, "dortoir plein")
	var session := StopSession.new()
	session.free_beds = GameState.free_beds()
	session.start(60.0)
	assert_true(session.resolve_choice(_recruit_choice(), RandomNumberGenerator.new()) == null, "recrutement refusé")
	assert_true(session.result.recruits.is_empty(), "personne ne monte")
	session.free()


func test_le_train_vu_de_dehors_suit_la_composition() -> void:
	var train: Train = (load("res://entities/train/train.tscn") as PackedScene).instantiate()
	tree.root.add_child(train)
	var base_length: float = train.length()
	var door_x: float = train.door.position.x
	train.set_wagon_count(6)
	var wagons: int = 0
	for car: Node in train.get_node("Cars").get_children():
		if car.name.begins_with("Wagon"):
			wagons += 1
	assert_true(wagons == 6, "6 wagons dessinés, obtenu %d" % wagons)
	assert_almost(train.length(), base_length + 4 * Train.WAGON_PITCH, "le train s'allonge")
	assert_almost(train.door.position.x, door_x, "la porte ne bouge pas")
	train.free()
