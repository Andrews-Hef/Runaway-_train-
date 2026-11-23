extends TestCase
## Se soigner soi-même : un médicament se prend du sac pendant une sortie, ou du coffre à
## bord, même sans infirmerie (bug vu en test : un antibiotique trouvé ne servait à rien
## tant qu'on n'avait pas construit l'infirmerie).

const STOP_SCENE: PackedScene = preload("res://levels/stop_zone/stop_zone.tscn")
const TRAIN_MENU: PackedScene = preload("res://ui/train/train_menu.tscn")
const TrainMenu = preload("res://ui/train/train_menu.gd")
const ANTIBIOTICS: LootData = preload("res://data/loot/antibiotics.tres")
const WOOD: LootData = preload("res://data/loot/wood.tres")
const CLOTH: LootData = preload("res://data/loot/cloth.tres")

var _nodes: Array[Node] = []


func before_each() -> void:
	GameState.new_run(31)


func after_each() -> void:
	GameMenu.close()
	tree.paused = false
	tree.current_scene = null
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	GameState.new_run()


func _zone() -> Node:
	var zone: Node = STOP_SCENE.instantiate()
	tree.root.add_child(zone)
	tree.current_scene = zone
	_nodes.append(zone)
	return zone


func _exposure(zone: Node) -> ExposureComponent:
	return (zone.get(&"_player") as Node).get(&"exposure") as ExposureComponent


func _session(zone: Node) -> StopSession:
	return zone.get(&"_session") as StopSession


func test_le_depart_n_a_pas_d_infirmerie() -> void:
	assert_false(GameState.has_wagon(&"infirmary"), "l'infirmerie se construit : il faut pouvoir se soigner sans elle")


func test_en_sortie_on_prend_un_medicament_du_sac() -> void:
	var zone := _zone()
	_session(zone).add_loot(ANTIBIOTICS, 1)
	_exposure(zone).value = 0.5
	var dropped: Array[int] = [0]
	_session(zone).dropped.connect(func(_id: StringName, _amount: int) -> void: dropped[0] += 1)
	assert_true(zone.call(&"take_medicine", ANTIBIOTICS), "pris en pleine sortie")
	assert_almost(_exposure(zone).value, 0.3, "infection −20 %")
	assert_true(_session(zone).result.get_amount(&"antibiotics") == 0, "consommé")
	assert_true(dropped[0] == 0, "rien ne tombe au sol (ce n'est pas « Jeter »)")


func test_en_sortie_rien_a_soigner_rien_de_perdu() -> void:
	var zone := _zone()
	_session(zone).add_loot(ANTIBIOTICS, 1)
	_session(zone).add_loot(WOOD, 1)
	_exposure(zone).value = 0.0
	assert_false(zone.call(&"take_medicine", ANTIBIOTICS), "pas infecté : on ne gâche pas le médicament")
	assert_true(_session(zone).result.get_amount(&"antibiotics") == 1, "toujours dans le sac")
	_exposure(zone).value = 0.4
	assert_false(zone.call(&"take_medicine", WOOD), "le bois ne soigne pas")


func test_le_sac_propose_prendre() -> void:
	var zone := _zone()
	_session(zone).add_loot(ANTIBIOTICS, 1)
	_exposure(zone).value = 0.5
	GameMenu.open_inventory()
	GameMenu.set(&"_selected", {"kind": &"bag", "id": &"antibiotics"})
	GameMenu.call(&"_fill_detail")
	var take := _button(GameMenu, "Prendre (infection −20 %)")
	assert_true(take != null and not take.disabled, "« Prendre » dans le sac")
	take.pressed.emit()
	assert_almost(_exposure(zone).value, 0.3, "l'infection baisse")
	assert_true(_session(zone).result.get_amount(&"antibiotics") == 0, "le médicament est pris")
	var shown: bool = false
	for node: Node in GameMenu.find_children("*", "Label", true, false):
		shown = shown or (node as Label).text == "Infection : " + Infection.describe(0.3)
	assert_true(shown, "l'inventaire affiche l'infection du moment (pas celle du début de l'arrêt)")


func test_a_bord_sans_infirmerie_le_coffre_soigne() -> void:
	GameState.storage[&"antibiotics"] = 1
	GameState.infection = 0.5
	var menu: CanvasLayer = TRAIN_MENU.instantiate()
	tree.root.add_child(menu)
	_nodes.append(menu)
	menu.call(&"open", TrainMenu.Tab.STOCK)
	menu.call(&"_select", TrainMenu.Tab.STOCK, ANTIBIOTICS)
	var take := _button(menu.get_node("%Detail"), "Prendre")
	assert_true(take != null and not take.disabled, "« Prendre » au coffre, sans infirmerie")
	take.pressed.emit()
	assert_almost(GameState.infection, 0.3, "infection −20 %")
	assert_true(GameState.storage_amount(&"antibiotics") == 0, "consommé")


func test_en_sortie_le_tissu_sert_de_pansement() -> void:
	var zone := _zone()
	var health: HealthComponent = (zone.get(&"_player") as Node).get(&"health")
	_session(zone).add_loot(CLOTH, 2)
	assert_false(zone.call(&"apply_bandage", CLOTH), "PV pleins : on ne gâche pas le tissu")
	health.take_damage(5)
	var before: int = health.health
	GameMenu.open_inventory()
	GameMenu.set(&"_selected", {"kind": &"bag", "id": &"cloth"})
	GameMenu.call(&"_fill_detail")
	var bandage := _button(GameMenu, "Se panser (+%d PV)" % CLOTH.heal)
	assert_true(bandage != null and not bandage.disabled, "« Se panser » dans le sac")
	bandage.pressed.emit()
	assert_true(health.health == mini(before + CLOTH.heal, health.max_health), "PV rendus")
	assert_true(_session(zone).result.get_amount(&"cloth") == 1, "un tissu utilisé")
	assert_false(zone.call(&"apply_bandage", WOOD), "le bois ne panse pas")


func test_chaque_objet_utilisable_a_son_bouton() -> void:
	# Ce qui soigne (infection ou PV) doit pouvoir se prendre depuis le sac : sinon on
	# le ramasse sans pouvoir s'en servir (bug vu en test avec les antibiotiques).
	for loot: LootData in GameState.LOOT_TYPES:
		if loot.is_medicine() or loot.heal > 0:
			assert_false(loot.describe().is_empty(), "%s dit à quoi il sert" % loot.id)
			assert_true(loot.is_medicine() != (loot.heal > 0), "%s : un seul usage (médicament ou pansement)" % loot.id)


func _button(root: Node, text: String) -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node as Button
	return null
