extends TestCase
## Carrière : grades, mérite, talents ; ordres du capitaine ; armure.


func before_each() -> void:
	GameState.new_run(2024)


func after_each() -> void:
	GameState.new_run()


func _result(boarded: bool = true) -> ExpeditionResult:
	var result := ExpeditionResult.new()
	result.boarded = boarded
	return result


func test_les_grades_suivent_le_merite() -> void:
	assert_true(Career.grade_index_for(0) == 0, "Recrue au départ")
	assert_true(Career.grade_index_for(Career.GRADES[1].merit_needed) == 1, "Soldat")
	assert_true(Career.grade_index_for(Career.GRADES[2].merit_needed - 1) == 1, "pas encore Caporal")
	assert_true(Career.grade_index_for(99999) == Career.GRADES.size() - 1, "Capitaine au bout")
	assert_true(Career.GRADES.back().id == &"captain", "le dernier grade est Capitaine")
	for i: int in range(1, Career.GRADES.size()):
		assert_true(Career.GRADES[i].perks.size() == 2, "%s : deux talents au choix" % Career.GRADES[i].id)


func test_une_promotion_propose_un_talent() -> void:
	var gained: Array[GradeData] = GameState.add_merit(Career.GRADES[1].merit_needed)
	assert_true(gained.size() == 1 and GameState.grade().id == &"soldier", "promu Soldat")
	assert_true(GameState.pending_promotions.size() == 1, "un talent à choisir")
	var other_grade_perk: PerkData = Career.GRADES[2].perks[0]
	assert_false(GameState.choose_perk(other_grade_perk), "pas un talent d'un autre grade")
	var tough: PerkData = Career.find_perk(&"tough")
	assert_true(GameState.choose_perk(tough), "Endurci choisi")
	assert_true(GameState.max_health() == GameState.BASE_HEALTH + 2, "+2 PV")
	assert_true(GameState.pending_promotions.is_empty(), "plus rien à choisir")


func test_deux_grades_d_un_coup() -> void:
	GameState.add_merit(Career.GRADES[2].merit_needed)
	assert_true(GameState.pending_promotions.size() == 2, "deux talents à choisir, dans l'ordre")
	assert_true(GameState.pending_promotions[0].id == &"soldier", "d'abord Soldat")


func test_le_talent_glaneur_agrandit_le_sac() -> void:
	var before: int = GameState.bag_capacity()
	GameState.add_merit(Career.GRADES[1].merit_needed)
	GameState.choose_perk(Career.find_perk(&"forager"))
	assert_true(GameState.bag_capacity() == before + 4, "sac +4")


func test_le_premier_ordre_est_simple() -> void:
	var order: CaptainOrders.Order = GameState.current_order
	assert_true(order != null and order.data.id == &"collect_scrap" and order.amount == 4, "Ramène 4 ferrailles")
	assert_true(order.text() == "Ramène 4 ferrailles", "texte : %s" % order.text())


func test_les_ordres_sont_faisables_dans_chaque_zone() -> void:
	for zone: ZoneProfile in GameState.ZONES:
		for stop_number: int in [2, 3, 4, 6, 9]:
			for zone_seed: int in 6:
				var rng := RandomNumberGenerator.new()
				rng.seed = zone_seed
				var order: CaptainOrders.Order = CaptainOrders.pick(zone, stop_number, rng, 12)
				assert_true(order.amount >= 1, "%s : ordre vide" % zone.id)
				assert_true(order.amount <= CaptainOrders.max_possible(order.data, zone, stop_number, 12), "%s : %s impossible" % [zone.id, order.text()])
				assert_true(stop_number >= order.data.min_stop, "%s trop tôt" % order.data.id)


func test_pas_d_ordre_en_gare() -> void:
	while GameState.stop_number < 5:
		GameState.prepare_next_stop()
	assert_true(GameState.current_order == null, "gare refuge : pas d'ordre")


func test_evaluer_un_ordre() -> void:
	var collect := CaptainOrders.Order.new(CaptainOrders.find(&"collect_scrap"), 4)
	var result := _result()
	result.add_loot(&"scrap", 3)
	assert_false(collect.is_completed(result), "3/4")
	result.add_loot(&"scrap", 1)
	assert_true(collect.is_completed(result) and collect.progress_text(result) == "4/4", "4/4")
	var eliminate := CaptainOrders.Order.new(CaptainOrders.find(&"eliminate_raiders"), 2)
	result.record_kill(EnemyCatalog.get_enemy(&"raider"))
	result.record_kill(EnemyCatalog.get_enemy(&"infected"))
	assert_false(eliminate.is_completed(result), "un infecté ne compte pas comme pilleur")
	result.record_kill(EnemyCatalog.get_enemy(&"raider_marksman"))
	assert_true(eliminate.is_completed(result), "le Tireur est un pilleur")
	var clean := CaptainOrders.Order.new(CaptainOrders.find(&"low_exposure"), 25)
	result.exposure = 0.3
	assert_false(clean.is_completed(result), "30 % : trop exposé")
	result.exposure = 0.1
	assert_true(clean.is_completed(result), "10 % : réussi")


func test_le_retour_rapporte_du_merite() -> void:
	var result := _result()
	result.add_loot(&"scrap", 4)
	result.record_kill(EnemyCatalog.get_enemy(&"infected"))
	GameState.record_expedition(result)
	assert_true(result.order_completed, "ordre rempli")
	var expected: int = CaptainOrders.FIRST_ORDER.merit + EnemyCatalog.get_enemy(&"infected").merit
	assert_true(result.merit_gained == expected and GameState.merit == expected, "mérite %d" % GameState.merit)


func test_pas_de_merite_si_on_rate_le_train() -> void:
	var result := _result(false)
	result.add_loot(&"scrap", 9)
	result.record_kill(EnemyCatalog.get_enemy(&"raider_brute"))
	GameState.record_expedition(result)
	assert_true(GameState.merit == 0, "rien")


func test_la_carriere_se_sauvegarde() -> void:
	GameState.add_merit(Career.GRADES[2].merit_needed)
	GameState.choose_perk(Career.find_perk(&"tough"))
	GameState.prepare_next_stop()
	var order_text: String = GameState.current_order.text()
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_save()))
	GameState.new_run(1)
	assert_true(GameState.load_save(data), "relue")
	assert_true(GameState.grade().id == &"corporal", "Caporal")
	assert_true(GameState.perks.size() == 1 and GameState.pending_promotions.size() == 1, "un talent choisi, un à choisir")
	assert_true(GameState.current_order.text() == order_text, "même ordre")


func test_l_armure_reduit_les_degats() -> void:
	assert_true(Loadout.damage_after_armor(4, 2) == 2, "4 - 2")
	assert_true(Loadout.damage_after_armor(1, 2) == 1, "il reste toujours 1 dégât")
	var kevlar: ItemData = ItemCatalog.get_item(&"outfit_kevlar")
	assert_true(kevlar.armor == 2 and not kevlar.is_craftable(), "le kevlar s'achète ou se trouve")
	assert_true(ItemCatalog.get_item(&"outfit_plate").is_craftable(), "le plastron se fabrique")
	var sold: bool = false
	for choice: EncounterChoice in EncounterLibrary.get_encounter(&"merchant_scrapper").choices:
		sold = sold or choice.reward_item == kevlar
	assert_true(sold, "le ferrailleur vend un gilet en kevlar")


func test_la_zone_applique_les_talents() -> void:
	GameState.add_merit(Career.GRADES[1].merit_needed)
	GameState.choose_perk(Career.find_perk(&"tough"))
	var zone: Node = (load("res://levels/stop_zone/stop_zone.tscn") as PackedScene).instantiate()
	tree.root.add_child(zone)
	var player: Player = zone.get_node("World/Player")
	assert_true(player.health.max_health == 12 and player.health.health == 12, "12 PV")
	zone.free()
