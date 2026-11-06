extends TestCase
## Le sac en cases, façon Minecraft : piles de 5 d'une seule ressource.


func _loot(pairs: Dictionary) -> Dictionary[StringName, int]:
	var loot: Dictionary[StringName, int] = {}
	for id: StringName in pairs:
		loot[id] = pairs[id]
	return loot


func test_une_case_contient_une_pile_de_5() -> void:
	assert_true(BagSlots.STACK_SIZE == 5, "piles de 5")
	assert_true(BagSlots.used(_loot({&"wood": 5})) == 1, "5 bois : 1 case")
	assert_true(BagSlots.used(_loot({&"wood": 7})) == 2, "7 bois : 2 cases")
	assert_true(BagSlots.used(_loot({&"wood": 7, &"herb": 1, &"antiseptic": 4})) == 4, "comme sur la capture : 4 cases")
	assert_true(BagSlots.used(_loot({})) == 0, "vide")


func test_la_place_compte_la_pile_entamee_et_les_cases_libres() -> void:
	var loot := _loot({&"wood": 7, &"herb": 1})
	assert_true(BagSlots.room_for(loot, &"wood", 4) == 3 + 5, "3 pour finir la pile, 5 dans la case libre")
	assert_true(BagSlots.room_for(loot, &"herb", 3) == 4, "sac plein : seulement la fin de la pile de plantes")
	assert_true(BagSlots.room_for(loot, &"scrap", 3) == 0, "pas de case pour la ferraille")


func test_les_piles_se_rangent_dans_l_ordre_des_ressources() -> void:
	var order: Array[StringName] = [&"scrap", &"wood", &"herb"]
	var stacks := BagSlots.layout(_loot({&"herb": 1, &"wood": 7}), order)
	assert_true(stacks.size() == 3, "3 piles")
	assert_true(stacks[0].id == &"wood" and stacks[0].amount == 5, "bois 5 d'abord")
	assert_true(stacks[1].id == &"wood" and stacks[1].amount == 2, "puis bois 2")
	assert_true(stacks[2].id == &"herb" and stacks[2].amount == 1, "puis plante 1")


func test_les_sacs_et_les_talents_donnent_des_cases() -> void:
	assert_true(preload("res://data/items/bag_small.tres").capacity == 4, "petit sac 4")
	assert_true(preload("res://data/items/bag_hiking.tres").capacity == 6, "randonnée 6")
	assert_true(preload("res://data/items/bag_military.tres").capacity == 8, "militaire 8")
	assert_true(Career.find_perk(&"forager").capacity == 1, "Glaneur +1")
	assert_true(Career.find_perk(&"quartermaster").capacity == 2, "Intendant +2")
	assert_true(BagSlots.max_items(4) == 20, "un petit sac tient 20 objets d'une même ressource")
