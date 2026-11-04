extends TestCase
## L'intérieur du train : tous les postes sont là, l'équipage est à bord.

const SCENE: PackedScene = preload("res://levels/train_interior/train_interior.tscn")

var _interior: Node


func before_each() -> void:
	GameState.new_run(8)
	GameState.crew.append(CrewMember.create("Léa", &"mechanic", "mécanique", false))
	GameState.crew.append(CrewMember.create("Malik", &"scout", "repérage", false))
	_interior = SCENE.instantiate()
	tree.root.add_child(_interior)


func after_each() -> void:
	_interior.free()
	GameState.new_run()


func _find(prefix: String) -> Array[Node]:
	var found: Array[Node] = []
	for child: Node in _interior.get_node("Train/World").get_children():
		if child.name.begins_with(prefix):
			found.append(child)
	return found


func test_tous_les_postes_du_train_existent() -> void:
	var names: Array[String] = []
	for station: Node in _find("Station_"):
		names.append(station.name)
	for expected: String in ["Station_stock", "Station_workshop", "Station_equipment", "Station_crew", "Station_train", "Station_lever"]:
		assert_true(expected in names, "%s manquant" % expected)


func test_les_postes_sont_interactifs() -> void:
	for station: Node in _find("Station_"):
		assert_true(station is Interactable, "%s n'est pas un Interactable" % station.name)


func test_l_equipage_est_dans_le_dortoir() -> void:
	var crew: Array[String] = []
	for child: Node in _interior.get_node("Train/World").get_children():
		if child.name.begins_with("Crew_"):
			crew.append(child.name)
	assert_true(crew.size() == 2, "2 équipiers visibles, obtenu %d" % crew.size())
	assert_true("Crew_Léa" in crew, "Léa est à bord")


func test_le_joueur_est_celui_de_dehors() -> void:
	var player: Node = _interior.get_node("Train/World/Player")
	assert_true(player is Player, "même personnage que dans les zones")


func test_le_joueur_apparait_dans_le_train() -> void:
	var player: Node2D = _interior.get_node("Train/World/Player")
	var start: float = _interior.call(&"train_start")
	var end: float = _interior.call(&"train_end")
	assert_true(player.position.x > start and player.position.x < end, "dans la longueur du train")
	assert_true(absf(player.position.y) < 18.0, "sur le plancher")


func test_une_voiture_construite_apparait_en_queue() -> void:
	var lever: Node2D = _find("Station_lever")[0]
	var lever_x: float = lever.position.x
	for loot: LootData in GameState.LOOT_TYPES:
		GameState.storage[loot.id] = 50
	assert_true(GameState.build_wagon(preload("res://data/wagons/stock.tres")), "wagon de stock construit")
	assert_true(_find("Station_stock").size() == 2, "deux coffres de stock")
	assert_almost((_find("Station_lever")[0] as Node2D).position.x, lever_x, "la cabine n'a pas bougé")
	var shells: int = 0
	for child: Node in _interior.get_node("Train/Floors").get_children():
		if child is Sprite2D:
			shells += 1
	assert_true(shells == 5, "5 voitures dessinées, obtenu %d" % shells)


func test_l_equipage_se_repartit_dans_les_dortoirs() -> void:
	for loot: LootData in GameState.LOOT_TYPES:
		GameState.storage[loot.id] = 50
	GameState.build_wagon(preload("res://data/wagons/dormitory.tres"))
	for i: int in 4:
		GameState.crew.append(CrewMember.create("Extra%d" % i, &"scout", "repérage", false))
	GameState.crew_changed.emit()
	GameState.train_changed.emit()
	assert_true(_find("Crew_").size() == 6, "les 6 équipiers sont visibles")
