extends TestCase
## Inventaire façon Minecraft : équipement porté, sac en cases, casier (à bord).

const MACHETE: ItemData = preload("res://data/items/weapon_machete.tres")
const PIPE: ItemData = preload("res://data/items/weapon_pipe.tres")
const WOOD: LootData = preload("res://data/loot/wood.tres")

var _nodes: Array[Node] = []


func after_each() -> void:
	GameMenu.close()
	tree.paused = false
	tree.current_scene = null
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	GameState.new_run()


func _scene(path: String) -> Node:
	var scene := Node.new()
	scene.scene_file_path = path
	tree.root.add_child(scene)
	tree.current_scene = scene
	_nodes.append(scene)
	return scene


func _cells(grid_name: String) -> Array[Node]:
	var grid: Node = GameMenu.find_child(grid_name, true, false)
	return grid.get_children() if grid else ([] as Array[Node])


func test_dans_le_train_on_s_equipe_depuis_le_casier() -> void:
	GameState.new_run(4)
	GameState.owned_items.append(MACHETE)
	_scene("res://levels/train_interior/train_interior.tscn")
	GameMenu.open_inventory()
	assert_true(_find_button("Équiper") != null, "le casier est actif à bord")
	assert_true(_find_label("Machette · Arme") != null, "l'objet du casier est choisi d'office")
	_find_button("Équiper").pressed.emit()
	assert_true(GameState.loadout.get_item(ItemData.Slot.WEAPON) == MACHETE, "machette en main")
	assert_true(PIPE in GameState.owned_items and GameState.loadout.get_item(ItemData.Slot.WEAPON) != PIPE, "la barre de fer revient au casier")
	assert_true(_find_label("Machette · Arme (porté)") != null, "la sélection suit l'objet porté")


func test_pendant_un_arret_le_casier_est_au_train() -> void:
	GameState.new_run(4)
	GameState.owned_items.append(MACHETE)
	var zone: Node = _scene("res://levels/stop_zone/stop_zone.tscn")
	var session := StopSession.new()
	session.capacity = 4
	zone.add_child(session)
	session.add_loot(WOOD, 7)
	GameMenu.open_inventory()
	assert_true(_find_button("Équiper") == null, "pas d'Équiper en zone")
	assert_true(_find_label("Casier · dans le train") != null, "le casier dit où il est")
	var bag := _cells("BagGrid")
	assert_true(bag.size() == 8, "2 rangées de 4 cases")
	var greyed: int = 0
	for cell: Node in bag:
		if (cell as Control).modulate.a < 1.0:
			greyed += 1
	assert_true(greyed == 4, "4 cases grisées au-delà du petit sac")
	assert_true(_find_label("Bois ×7") != null, "piles du bois : 5 + 2, la ressource choisie")


func _find_button(text: String) -> Button:
	for node: Node in GameMenu.find_children("*", "Button", true, false):
		if (node as Button).text == text and (node as Button).is_visible_in_tree():
			return node as Button
	return null


func _find_label(text: String) -> Label:
	for node: Node in GameMenu.find_children("*", "Label", true, false):
		if (node as Label).text == text and (node as Label).is_visible_in_tree():
			return node as Label
	return null
