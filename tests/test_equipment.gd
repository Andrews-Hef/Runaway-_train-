extends TestCase
## Équipement : effets, fabrication à l'atelier, capacité du sac, objets trouvés.

const SCRAP: LootData = preload("res://data/loot/scrap.tres")


func before_each() -> void:
	GameState.new_run(3)


func after_each() -> void:
	GameState.new_run()


func _item(id: StringName) -> ItemData:
	return ItemCatalog.get_item(id)


func test_une_nouvelle_partie_equipe_le_materiel_de_depart() -> void:
	var loadout: Loadout = GameState.loadout
	assert_true(loadout.get_item(ItemData.Slot.OUTFIT) == _item(&"outfit_worn"), "tenue de départ")
	assert_true(loadout.get_item(ItemData.Slot.WEAPON) == _item(&"weapon_pipe"), "barre de fer")
	assert_true(loadout.capacity() == 12, "petit sac : 12, obtenu %d" % loadout.capacity())
	assert_almost(loadout.protection(), 0.1, "masque usé")


func test_tenue_et_masque_s_additionnent_mais_plafonnent() -> void:
	var loadout := Loadout.new()
	loadout.equip(_item(&"outfit_hazmat"))
	loadout.equip(_item(&"mask_filter"))
	assert_almost(loadout.protection(), 0.6, "0,35 + 0,25")
	var heavy := ItemData.new()
	heavy.slot = ItemData.Slot.OUTFIT
	heavy.protection = 0.9
	loadout.equip(heavy)
	assert_almost(loadout.protection(), Loadout.MAX_PROTECTION, "plafond")


func test_sans_sac_on_porte_peu() -> void:
	var loadout := Loadout.new()
	assert_true(loadout.capacity() == Loadout.BASE_CAPACITY, "capacité sans sac")


func test_un_outil_accelere_seulement_son_type_d_objet() -> void:
	var loadout := Loadout.new()
	loadout.equip(_item(&"tool_hatchet"))
	assert_almost(loadout.harvest_speed_for(&"wood"), 1.8, "bois plus vite")
	assert_almost(loadout.harvest_speed_for(&"scrap"), 1.0, "ferraille normale")


func test_fabriquer_prend_les_materiaux_du_stock() -> void:
	var bag: ItemData = _item(&"bag_hiking")
	GameState.storage[&"cloth"] = 5
	GameState.storage[&"wood"] = 1
	assert_true(GameState.craft(bag), "fabrication réussie")
	assert_true(GameState.storage_amount(&"cloth") == 1, "4 tissus consommés")
	assert_true(GameState.storage_amount(&"wood") == 0, "bois consommé")
	assert_true(bag in GameState.owned_items, "sac possédé")
	GameState.equip(bag)
	assert_true(GameState.loadout.capacity() == 20, "sac de randonnée porté")


func test_on_ne_fabrique_pas_sans_les_materiaux_ni_deux_fois() -> void:
	var mask: ItemData = _item(&"mask_filter")
	assert_false(GameState.craft(mask), "stock vide")
	assert_true(Crafting.missing(mask, GameState.storage).get(&"herb", 0) == 3, "il manque 3 plantes")
	GameState.storage[&"scrap"] = 4
	GameState.storage[&"herb"] = 6
	GameState.storage[&"parts"] = 2
	assert_true(GameState.craft(mask), "première fabrication")
	assert_false(GameState.craft(mask), "déjà possédé")


func test_on_ne_porte_que_ce_qu_on_possede() -> void:
	GameState.equip(_item(&"weapon_axe"))
	assert_true(GameState.loadout.get_item(ItemData.Slot.WEAPON) == _item(&"weapon_pipe"), "toujours la barre de fer")


func test_le_sac_limite_le_butin_d_une_sortie() -> void:
	var session := StopSession.new()
	tree.root.add_child(session)
	session.set_process(false)
	session.start(60.0)
	session.capacity = 5
	assert_true(session.add_loot(SCRAP, 3) == 3, "3 ferrailles prises")
	assert_true(session.add_loot(SCRAP, 4) == 2, "seulement 2 de plus")
	assert_true(session.is_bag_full(), "sac plein")
	assert_true(session.add_loot(SCRAP, 1) == 0, "plus rien ne rentre")
	session.free()


func test_une_rencontre_ne_donne_pas_plus_que_le_sac_ne_contient() -> void:
	var choice := EncounterChoice.new()
	choice.reward[&"herb"] = 3
	var result := ExpeditionResult.new()
	result.add_loot(&"scrap", 4)
	assert_true(EncounterResolver.can_afford(choice, result, 10), "4 + 3 <= 10")
	var lacking := EncounterResolver.missing(choice, result, 6)
	assert_true(lacking.get(EncounterResolver.NO_SPACE, 0) == 1, "il manque 1 place")


func test_un_echange_libere_la_place_qu_il_coute() -> void:
	var choice := EncounterChoice.new()
	choice.cost[&"scrap"] = 3
	choice.reward[&"herb"] = 2
	var result := ExpeditionResult.new()
	result.add_loot(&"scrap", 6)
	assert_true(EncounterResolver.can_afford(choice, result, 6), "6 - 3 + 2 = 5 <= 6")


func test_la_protection_reduit_l_exposition() -> void:
	var exposure := ExposureComponent.new()
	exposure.protection = 0.5
	exposure.add(0.4)
	assert_almost(exposure.value, 0.2, "moitié de 0,4")
	exposure.free()


func test_un_equipement_achete_rejoint_le_train_au_retour() -> void:
	var choice := EncounterChoice.new()
	choice.reward_item = _item(&"tool_crowbar")
	var result := ExpeditionResult.new()
	var outcome := EncounterResolver.apply(choice, result, RandomNumberGenerator.new())
	assert_true(outcome.item == _item(&"tool_crowbar"), "objet annoncé")
	result.boarded = true
	GameState.record_expedition(result)
	assert_true(_item(&"tool_crowbar") in GameState.owned_items, "pied-de-biche rangé dans le train")


func test_toutes_les_recettes_utilisent_des_ressources_connues() -> void:
	for item: ItemData in ItemCatalog.craftables():
		for id: StringName in item.recipe:
			var known: bool = false
			for loot: LootData in GameState.LOOT_TYPES:
				known = known or loot.id == id
			assert_true(known, "%s : ressource inconnue %s" % [item.id, id])
	for slot: int in ItemData.Slot.values():
		var has_starter: bool = false
		for item: ItemData in ItemCatalog.starters():
			has_starter = has_starter or item.slot == slot
		if slot != ItemData.Slot.TOOL:
			assert_true(has_starter, "pas d'équipement de départ pour %s" % ItemData.SLOT_NAMES[slot])
