extends TestCase
## Jeter des ressources du sac pendant un arrêt : elles restent au sol en tas, qu'on
## peut ramasser.

const STOP_ZONE: PackedScene = preload("res://levels/stop_zone/stop_zone.tscn")
const PILE_SCENE: PackedScene = preload("res://props/dropped_pile/dropped_pile.tscn")
const SCRAP: LootData = preload("res://data/loot/scrap.tres")
const WOOD: LootData = preload("res://data/loot/wood.tres")

var _nodes: Array[Node] = []


func after_each() -> void:
	GameMenu.close()
	tree.paused = false
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	GameState.new_run()


func _add(node: Node) -> Node:
	tree.root.add_child(node)
	_nodes.append(node)
	return node


func _session(capacity: int = 12) -> StopSession:
	var session: StopSession = _add(StopSession.new())
	session.capacity = capacity
	return session


func test_jeter_retire_du_sac_et_previent_la_zone() -> void:
	var session := _session()
	session.add_loot(SCRAP, 5)
	var thrown: Array = []
	session.dropped.connect(func(id: StringName, amount: int) -> void: thrown.append([id, amount]))
	assert_true(session.drop(&"scrap", 2) == 2, "2 jetés")
	assert_true(session.result.get_amount(&"scrap") == 3, "il en reste 3")
	assert_true(thrown == [[&"scrap", 2]], "la zone pose le tas")
	assert_true(session.drop(&"scrap", 10) == 3, "pas plus que ce qu'on porte")
	assert_true(session.drop(&"wood", 1) == 0, "rien à jeter")
	assert_true(session.free_space() == 12, "le sac est vide")


func test_on_ne_jette_plus_une_fois_l_arret_fini() -> void:
	var session := _session()
	session.add_loot(SCRAP, 2)
	session.board()
	assert_true(session.drop(&"scrap", 1) == 0, "arrêt fini")


func test_un_tas_se_complete_se_ramasse_et_disparait_vide() -> void:
	var pile: DroppedPile = _add(PILE_SCENE.instantiate())
	pile.add(&"scrap", 2)
	pile.add(&"wood", 1)
	pile.add(&"scrap", 1)
	assert_true(pile.total() == 4 and pile.contents[&"scrap"] == 3, "contenu cumulé")
	assert_true("3 ferraille" in pile.prompt, "on voit ce qu'il contient : %s" % pile.prompt)
	assert_true(pile.take(&"scrap", 5) == 3, "on reprend ce qu'il y a")
	assert_true(pile.can_interact(), "il reste du bois")
	pile.take(&"wood", 1)
	assert_false(pile.can_interact(), "vide")
	assert_true(DroppedPile.nearest(tree, pile.global_position) == null, "un tas vide ne compte plus")


func test_jeter_pres_d_un_tas_le_complete() -> void:
	var pile: DroppedPile = _add(PILE_SCENE.instantiate())
	pile.global_position = Vector2(100, 100)
	pile.add(&"scrap", 1)
	assert_true(DroppedPile.nearest(tree, Vector2(110, 105)) == pile, "tout près : le même tas")
	assert_true(DroppedPile.nearest(tree, Vector2(200, 100)) == null, "plus loin : un autre tas")


func _zone() -> Node:
	GameState.new_run(5)
	GameState.stop_number = 2
	var zone := STOP_ZONE.instantiate()
	zone.set(&"zone_override", preload("res://data/zones/plains.tres"))
	zone.set(&"seed_override", 11)
	return _add(zone)


func test_dans_la_zone_le_tas_tombe_aux_pieds_et_se_ramasse() -> void:
	var zone := _zone()
	var session: StopSession = zone.get_node("StopSession")
	var player: Node2D = zone.get_node("World/Player")
	session.add_loot(SCRAP, 4)
	session.drop(&"scrap", 3)
	session.drop(&"scrap", 1)
	var piles := tree.get_nodes_in_group(DroppedPile.GROUP)
	assert_true(piles.size() == 1, "un seul tas (le 2e jet le complète)")
	var pile := piles[0] as DroppedPile
	assert_true(pile.global_position.distance_to(player.global_position) < 12.0, "aux pieds du joueur")
	assert_true(pile.contents[&"scrap"] == 4, "tout est dedans")
	# Sac presque plein : on ne reprend que ce qui rentre.
	session.add_loot(WOOD, session.free_space() - 1)
	pile.interact(player)
	assert_true(session.result.get_amount(&"scrap") == 1, "1 ferraille reprise (sac plein)")
	assert_true(pile.contents[&"scrap"] == 3, "le reste reste au sol")
	session.drop(&"wood", 5)
	pile.interact(player)
	assert_true(session.result.get_amount(&"scrap") == 4, "tout repris une fois la place faite")


func test_l_inventaire_propose_jeter_pendant_un_arret() -> void:
	var zone := _zone()
	var session: StopSession = zone.get_node("StopSession")
	tree.current_scene = zone
	session.add_loot(SCRAP, 3)
	GameMenu.open_inventory()
	var one: Button = _find_button(GameMenu, "Jeter 1")
	assert_true(one != null and _find_button(GameMenu, "Tout") != null, "Jeter 1 et Tout")
	one.pressed.emit()
	assert_true(session.result.get_amount(&"scrap") == 2, "une ferraille en moins")
	assert_true(_find_label(GameMenu, "Ferraille ×2") != null, "l'inventaire se met à jour")
	_find_button(GameMenu, "Tout").pressed.emit()
	assert_true(session.result.get_amount(&"scrap") == 0, "tout jeté")
	assert_true(_find_button(GameMenu, "Jeter 1") == null, "plus rien à jeter")
	tree.current_scene = null


func _find_button(root: Node, text: String) -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		if (node as Button).text == text and (node as Button).is_visible_in_tree():
			return node as Button
	return null


func _find_label(root: Node, text: String) -> Label:
	for node: Node in root.find_children("*", "Label", true, false):
		if (node as Label).text == text and (node as Label).is_visible_in_tree():
			return node as Label
	return null
