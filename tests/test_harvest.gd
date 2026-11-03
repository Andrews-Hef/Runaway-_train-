extends TestCase
## Récolte : il faut maintenir Agir assez longtemps, sur l'objet le plus proche.

const HERB_SCENE: PackedScene = preload("res://props/plant/herb.tscn")
const INFECTED_HERB_SCENE: PackedScene = preload("res://props/plant/infected_herb.tscn")

var _actor: Node2D
var _interactor: Interactor
var _harvests: Array[Array] = []


func before_each() -> void:
	_actor = Node2D.new()
	_interactor = Interactor.new()
	_actor.add_child(_interactor)
	tree.root.add_child(_actor)
	_interactor.set_physics_process(false) # on avance le temps à la main


func after_each() -> void:
	Input.action_release(&"interact")
	_actor.free()
	for node: Node in tree.root.get_children():
		if node is Harvestable:
			node.free()


func _spawn(scene: PackedScene, position: Vector2) -> Harvestable:
	var harvestable := scene.instantiate() as Harvestable
	harvestable.position = position
	tree.root.add_child(harvestable)
	harvestable.harvested.connect(func(loot: LootData, amount: int, exposure: float) -> void:
		_harvests.append([loot, amount, exposure]))
	_interactor.add_candidate(harvestable)
	return harvestable


func _hold(seconds: float, step: float = 0.1) -> void:
	Input.action_press(&"interact")
	var elapsed: float = 0.0
	while elapsed < seconds - 0.0001:
		_interactor._physics_process(step)
		elapsed += step


func test_l_objet_le_plus_proche_est_cible() -> void:
	var far := _spawn(HERB_SCENE, Vector2(30.0, 0.0))
	var near := _spawn(HERB_SCENE, Vector2(5.0, 0.0))
	_interactor._physics_process(0.0)
	assert_true(_interactor.target == near, "la plante proche est ciblée")
	assert_true(near.focused and not far.focused, "seule la cible est mise en avant")


func test_un_appui_trop_court_ne_recolte_pas() -> void:
	var herb := _spawn(HERB_SCENE, Vector2.ZERO)
	_hold(herb.hold_time / 2.0)
	Input.action_release(&"interact")
	_interactor._physics_process(0.1)
	assert_true(_harvests.is_empty(), "rien de récolté")
	assert_almost(herb.progress, 0.0, "la progression repart de zéro")


func test_maintenir_agir_recolte_la_plante() -> void:
	var herb := _spawn(HERB_SCENE, Vector2.ZERO)
	_hold(herb.hold_time + 0.1)
	assert_true(_harvests.size() == 1, "une récolte")
	var amount: int = _harvests[0][1]
	assert_true(amount >= herb.amount_min and amount <= herb.amount_max, "quantité dans l'intervalle : %d" % amount)
	assert_true(herb.depleted, "la plante est épuisée")
	assert_false(herb.can_interact(), "on ne peut plus la récolter")


func test_une_plante_infectee_expose_le_joueur() -> void:
	var herb := _spawn(INFECTED_HERB_SCENE, Vector2.ZERO)
	_hold(herb.hold_time + 0.1)
	assert_true(_harvests.size() == 1, "une récolte")
	var loot: LootData = _harvests[0][0]
	assert_true(loot.infected, "ressource infectée")
	assert_true(_harvests[0][2] > 0.0, "exposition à la récolte")
