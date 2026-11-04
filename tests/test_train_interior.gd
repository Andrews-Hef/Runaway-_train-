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
	for wagon: Node in _interior.get_node("Train/Wagons").get_children():
		for child: Node in wagon.get_children():
			if child.name.begins_with(prefix):
				found.append(child)
	return found


func test_tous_les_postes_du_train_existent() -> void:
	var names: Array[String] = []
	for station: Node in _find("Station_"):
		names.append(station.name)
	for expected: String in ["Station_stock", "Station_workshop", "Station_equipment", "Station_crew", "Station_lever"]:
		assert_true(expected in names, "%s manquant" % expected)


func test_les_postes_sont_interactifs() -> void:
	for station: Node in _find("Station_"):
		assert_true(station is Interactable, "%s n'est pas un Interactable" % station.name)


func test_l_equipage_est_dans_le_dortoir() -> void:
	var crew_sprites: int = 0
	for child: Node in _interior.get_node("Train/Wagons/Wagon0").get_children():
		if child is AnimatedSprite2D:
			crew_sprites += 1
	assert_true(crew_sprites == 2, "2 équipiers visibles, obtenu %d" % crew_sprites)


func test_le_joueur_reste_dans_le_train() -> void:
	var player: InteriorPlayer = _interior.get_node("Train/InteriorPlayer")
	assert_true(player.min_x < player.position.x and player.position.x < player.max_x, "départ dans le train")
	assert_true(player.max_x - player.min_x > 900.0, "on peut traverser les 4 wagons")
