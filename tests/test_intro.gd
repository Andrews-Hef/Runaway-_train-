extends TestCase
## Intro d'une nouvelle partie : pages de contexte par-dessus le premier trajet.

const JOURNEY: PackedScene = preload("res://levels/journey/journey.tscn")

var _nodes: Array[Node] = []


func after_each() -> void:
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	GameState.new_run()


func _add(node: Node) -> Node:
	tree.root.add_child(node)
	_nodes.append(node)
	return node


func test_l_intro_raconte_le_contexte_puis_le_capitaine_parle() -> void:
	assert_true(IntroOverlay.PAGES.size() >= 3, "quelques pages de contexte")
	assert_true(IntroOverlay.page_count() == IntroOverlay.PAGES.size() + 1, "plus la page du capitaine")
	assert_true("ruche" in IntroOverlay.PAGES[0], "la peste et la ruche d'abord")


func test_un_appui_finit_la_page_le_suivant_passe_a_la_suite() -> void:
	var intro: IntroOverlay = _add(IntroOverlay.new())
	assert_true(intro.page == 0 and intro.is_typing(), "la première page s'écrit")
	intro.advance()
	assert_true(intro.page == 0 and not intro.is_typing(), "1er appui : la page s'affiche en entier")
	intro.advance()
	assert_true(intro.page == 1 and intro.is_typing(), "2e appui : page suivante")


func test_la_derniere_page_termine_l_intro() -> void:
	var intro: IntroOverlay = _add(IntroOverlay.new())
	var ended: Array[int] = [0]
	intro.finished.connect(func() -> void: ended[0] += 1)
	for i: int in IntroOverlay.page_count() * 2:
		intro.advance()
	assert_true(ended[0] == 1, "terminée une seule fois")


func test_echap_ou_le_bouton_retour_passent_l_intro() -> void:
	var intro: IntroOverlay = _add(IntroOverlay.new())
	var ended: Array[int] = [0]
	intro.finished.connect(func() -> void: ended[0] += 1)
	var escape := InputEventAction.new()
	escape.action = &"pause"
	escape.pressed = true
	tree.root.push_input(escape)
	assert_true(ended[0] == 1, "Échap (ou retour Android, qui fait Échap) passe tout")


func test_le_premier_trajet_d_une_nouvelle_partie_attend_la_fin_de_l_intro() -> void:
	GameState.new_run(3)
	GameState.pending_intro = true
	var journey: Node = _add(JOURNEY.instantiate())
	var intro: IntroOverlay = journey.get(&"_intro")
	assert_true(intro != null, "l'intro passe d'abord")
	assert_false(GameState.pending_intro, "une seule fois")
	assert_false(journey.get_node("Ui/Root/Panel").visible, "le panneau du trajet attend")
	intro.finish()
	assert_true(journey.get(&"_intro") == null, "intro finie")
	assert_true(journey.get_node("Ui/Root/Panel").visible, "le trajet s'affiche")


func test_une_partie_reprise_ne_rejoue_pas_l_intro() -> void:
	GameState.pending_intro = true
	GameState.new_run(3)
	assert_false(GameState.pending_intro, "new_run l'efface (Campaign la demande après)")
	var journey: Node = _add(JOURNEY.instantiate())
	assert_true(journey.get(&"_intro") == null, "pas d'intro")
	assert_true(journey.get_node("Ui/Root/Panel").visible, "trajet tout de suite")
