extends TestCase
## Sauvegarde : la partie se relit à l'identique ; train raté = reprise à la dernière gare.


func before_each() -> void:
	SaveStore.erase(SaveStore.CHECKPOINT)
	SaveStore.erase(SaveStore.RESUME)
	GameState.new_run(4242)


func after_each() -> void:
	SaveStore.erase(SaveStore.CHECKPOINT)
	SaveStore.erase(SaveStore.RESUME)
	GameState.new_run()


func _play_a_bit() -> void:
	for i: int in 3:
		GameState.prepare_next_stop()
	GameState.storage[&"scrap"] = 7
	GameState.storage[&"parts"] = 2
	GameState.crew.append(CrewMember.create("Léa", &"mechanic", "mécanique", true))
	GameState.owned_items.append(ItemCatalog.get_item(&"bag_hiking"))
	GameState.equip(ItemCatalog.get_item(&"bag_hiking"))
	GameState.train.insert(0, preload("res://data/wagons/stock.tres"))
	GameState.locomotive_level = 2


func test_une_partie_se_relit_a_l_identique() -> void:
	_play_a_bit()
	var saved: Dictionary = GameState.to_save()
	# Passage par le texte JSON, comme sur le disque.
	var data: Dictionary = JSON.parse_string(JSON.stringify(saved))
	GameState.new_run(1)
	assert_true(GameState.load_save(data), "sauvegarde relue")
	assert_true(GameState.stop_number == 4, "arrêt n°4")
	assert_true(GameState.storage_amount(&"scrap") == 7 and GameState.storage_amount(&"parts") == 2, "stock")
	assert_true(GameState.crew.size() == 1 and GameState.crew[0].display_name == "Léa" and GameState.crew[0].infected, "équipage, infection cachée comprise")
	assert_true(GameState.loadout.capacity() == 20, "sac de randonnée porté")
	assert_true(GameState.train.size() == 5 and GameState.locomotive_level == 2, "train et locomotive")
	assert_true(JSON.stringify(GameState.to_save()) == JSON.stringify(saved), "rien n'a changé")


func test_le_hasard_reprend_au_meme_endroit() -> void:
	_play_a_bit()
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_save()))
	var next: Array[String] = []
	for i: int in 3:
		GameState.prepare_next_stop()
		next.append("%s:%d" % [GameState.stop_name(), GameState.current_seed])
	GameState.load_save(data)
	for i: int in 3:
		GameState.prepare_next_stop()
		assert_true(next[i] == "%s:%d" % [GameState.stop_name(), GameState.current_seed], "arrêt %d identique" % GameState.stop_number)


func test_une_sauvegarde_illisible_ne_change_rien() -> void:
	_play_a_bit()
	assert_false(GameState.load_save({"version": 999}), "mauvaise version")
	assert_false(GameState.load_save({}), "vide")
	assert_true(GameState.stop_number == 4, "partie intacte")


func test_le_disque() -> void:
	assert_false(SaveStore.exists(SaveStore.RESUME), "pas de sauvegarde au départ")
	assert_true(SaveStore.write(SaveStore.RESUME, GameState.to_save()), "écrite")
	assert_true(SaveStore.read(SaveStore.RESUME).get("stop_number", 0) == 1.0, "relue")
	assert_true(SaveStore.directory != "user://saves", "les tests n'écrivent pas dans les vraies sauvegardes")


func test_train_rate_on_reprend_a_la_derniere_gare() -> void:
	while GameState.stop_number < 5:
		GameState.prepare_next_stop()
	GameState.storage[&"wood"] = 3
	Campaign.reach_refuge()
	# Plus loin, on gagne des choses... puis on rate le train à l'arrêt 7.
	GameState.prepare_next_stop()
	GameState.prepare_next_stop()
	GameState.storage[&"wood"] = 40
	Campaign.autosave_journey()
	Campaign.train_missed()
	var resume: Dictionary = SaveStore.read(SaveStore.RESUME)
	assert_true(int(resume["stop_number"]) == 5 and resume["location"] == "refuge", "la session reprend aussi à la gare")
	assert_true(GameState.load_save(SaveStore.read(SaveStore.CHECKPOINT)), "point de reprise relu")
	assert_true(GameState.stop_number == 5 and GameState.is_refuge_stop(), "retour à la gare n°5")
	assert_true(GameState.storage_amount(&"wood") == 3, "ce qui a été gagné depuis est perdu")
	assert_true(Campaign.retry_place().contains("Fort-Cendre"), "le bilan dit où on reprend")


func test_l_ecran_titre_propose_de_continuer() -> void:
	var title: Node = (load("res://levels/title/title.tscn") as PackedScene).instantiate()
	tree.root.add_child(title)
	assert_false((title.get_node("%Continue") as Button).visible, "rien à continuer")
	title.free()
	Campaign.autosave_journey()
	title = (load("res://levels/title/title.tscn") as PackedScene).instantiate()
	tree.root.add_child(title)
	var button: Button = title.get_node("%Continue")
	assert_true(button.visible and button.text.contains("Arrêt n°1"), "Continuer — Arrêt n°1")
	title.free()
