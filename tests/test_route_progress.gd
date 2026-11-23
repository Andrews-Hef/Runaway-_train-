extends TestCase
## La barre de progression jusqu'à la prochaine gare refuge : les cases (faites, en cours,
## à venir), la phrase, et où on la voit (écran du trajet, intérieur du train).

const JOURNEY: PackedScene = preload("res://levels/journey/journey.tscn")
const TRAIN: PackedScene = preload("res://levels/train_interior/train_interior.tscn")

var _nodes: Array[Node] = []


func before_each() -> void:
	GameState.new_run(21)
	GameState.pending_intro = false


func after_each() -> void:
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	GameState.new_run()


func _go_to_stop(number: int) -> void:
	while GameState.stop_number < number:
		GameState.prepare_next_stop()


func _add(node: Node) -> Node:
	tree.root.add_child(node)
	_nodes.append(node)
	return node


func test_arrets_restants_avant_la_gare() -> void:
	# [arrêt, en route vers lui : restants, sur place : restants]
	for case: Array in [[1, 4, 3], [3, 2, 1], [4, 1, 0], [5, 0, 0], [6, 4, 3], [9, 1, 0], [10, 0, 0]]:
		_go_to_stop(case[0])
		assert_true(GameState.stops_before_refuge(true) == case[1], "en route vers l'arrêt %d : %d" % [case[0], case[1]])
		assert_true(GameState.stops_before_refuge(false) == case[2], "à l'arrêt %d : %d" % [case[0], case[2]])


func test_la_gare_a_venir_alterne() -> void:
	_go_to_stop(2)
	assert_true(GameState.next_refuge() == GameState.REFUGES[0], "1re gare")
	_go_to_stop(5)
	assert_true(GameState.next_refuge() == GameState.current_refuge, "en gare : c'est elle")
	_go_to_stop(7)
	assert_true(GameState.next_refuge() == GameState.REFUGES[1], "2e gare")


func test_la_phrase() -> void:
	var refuge_name: String = GameState.REFUGES[0].display_name
	_go_to_stop(3)
	assert_true(RouteProgress.text_for(true) == "%s : encore 2 arrêts" % refuge_name, RouteProgress.text_for(true))
	_go_to_stop(4)
	assert_true(RouteProgress.text_for(true) == "%s : encore 1 arrêt" % refuge_name, "singulier")
	assert_true(RouteProgress.text_for(false) == "%s : prochain arrêt !" % refuge_name, "sur place au dernier arrêt")
	_go_to_stop(5)
	assert_true(RouteProgress.text_for(true) == "%s : prochain arrêt !" % refuge_name, "en route vers la gare")
	assert_true(RouteProgress.text_for(false).begins_with("Tu es en gare"), "en gare")


func test_les_cases() -> void:
	_go_to_stop(3)
	assert_true(GameState.region_stops() == Vector2i(1, 5), "4 arrêts puis la gare n°5")
	var states: Array = range(1, 6).map(func(stop: int) -> int: return RouteProgress.pip_state(stop))
	assert_true(states == [-1, -1, 0, 1, 1], "faits, en cours, à venir : %s" % [states])


func test_on_la_voit_pendant_le_trajet_et_a_bord() -> void:
	_go_to_stop(3)
	var journey: Node = _add(JOURNEY.instantiate())
	var progress: RouteProgress = journey.find_child("RouteProgress", true, false)
	assert_true(progress != null and progress.get_node("Text").visible, "trajet : la barre et sa phrase")
	assert_true((progress.get_node("Text") as Label).text.ends_with("encore 2 arrêts"), "la bonne phrase")
	var train: Node = _add(TRAIN.instantiate())
	var compact: RouteProgress = train.get_node("%Summary").get_child(0) as RouteProgress
	assert_true(compact != null and not compact.get_node("Text").visible, "à bord : les cases seules, en tête des indicateurs")
	assert_true(compact.tooltip_text.ends_with("encore 2 arrêts"), "la phrase en infobulle")
