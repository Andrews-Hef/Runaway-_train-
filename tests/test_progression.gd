extends TestCase
## Infection persistante et médicaments, plans et recherche, extraction et machines.

const STOP_SCENE: PackedScene = preload("res://levels/stop_zone/stop_zone.tscn")


func before_each() -> void:
	GameState.new_run(606)


func after_each() -> void:
	GameState.new_run()


func _fill(amount: int = 30) -> void:
	for loot: LootData in GameState.LOOT_TYPES:
		if not loot.is_medicine():
			GameState.storage[loot.id] = amount


func _loot(id: StringName) -> LootData:
	for loot: LootData in GameState.LOOT_TYPES:
		if loot.id == id:
			return loot
	return null


func _zone() -> Node:
	var zone: Node = STOP_SCENE.instantiate()
	tree.root.add_child(zone)
	return zone


# --- Infection ----------------------------------------------------------------------

func test_les_stades_d_infection() -> void:
	assert_true(Infection.stage_for(0.1) == Infection.Stage.HEALTHY, "sain")
	assert_true(Infection.stage_for(0.45) == Infection.Stage.FEVER and Infection.health_malus(0.45) == 2, "fièvre : −2 PV")
	assert_true(Infection.stage_for(0.7) == Infection.Stage.CONTAMINATED and Infection.speed_factor(0.7) < 1.0, "contaminé : plus lent")
	assert_true(Infection.stage_for(1.0) == Infection.Stage.TURNED, "100 % : la ruche")


func test_l_infection_reste_apres_le_retour() -> void:
	var result := ExpeditionResult.new()
	result.boarded = true
	result.exposure = 0.42
	GameState.record_expedition(result)
	GameState.prepare_next_stop()
	assert_almost(GameState.infection, 0.42, "rien ne la fait baisser toute seule")
	assert_true(GameState.max_health() == GameState.BASE_HEALTH - 2, "la fièvre coûte 2 PV")


func test_l_arret_repart_de_l_infection_du_joueur() -> void:
	GameState.infection = 0.65
	var zone := _zone()
	var player: Player = zone.get_node("World/Player")
	assert_almost(player.exposure.value, 0.65, "l'exposition continue")
	assert_true(player.health.max_health == GameState.BASE_HEALTH - 4, "contaminé : −4 PV")
	assert_true(player.move_speed < 72.0, "et plus lent")
	zone.free()


func test_a_100_pourcent_on_rejoint_la_ruche() -> void:
	GameState.infection = 0.95
	var zone := _zone()
	var player: Player = zone.get_node("World/Player")
	var session: StopSession = zone.get_node("StopSession")
	player.exposure.add(0.2)
	assert_false(session.is_running(), "la sortie s'arrête")
	assert_true(session.result.turned and not session.result.boarded, "rejoint la ruche")
	zone.free()


func test_les_medicaments_font_baisser_l_infection() -> void:
	GameState.infection = 0.5
	assert_false(GameState.take_medicine(_loot(&"antibiotics")), "pas de médicament à bord")
	GameState.storage[&"antibiotics"] = 1
	assert_true(GameState.take_medicine(_loot(&"antibiotics")), "pris")
	assert_almost(GameState.infection, 0.3, "−20 points")
	assert_true(GameState.storage_amount(&"antibiotics") == 0, "consommé")
	assert_false(GameState.take_medicine(_loot(&"scrap")), "la ferraille ne soigne pas")


func test_les_medicaments_speciaux_demandent_l_infirmerie_et_un_plan() -> void:
	_fill()
	var serum: RecipeData = RecipeCatalog.ALL.filter(func(r: RecipeData) -> bool: return r.id == &"serum")[0]
	assert_true(GameState.recipe_problem(serum) == "Plan à étudier.", "plan Pharmacie d'abord")
	GameState.researched_plans.append(&"pharmacy")
	assert_true(GameState.recipe_problem(serum).begins_with("Il faut une infirmerie"), "puis une infirmerie")
	GameState.train.insert(0, preload("res://data/wagons/infirmary.tres"))
	assert_true(GameState.make_recipe(serum), "préparé")
	assert_true(GameState.storage_amount(&"serum") == 1, "un sérum en stock")


# --- Plans et recherche ---------------------------------------------------------------

func test_un_plan_s_etudie_dans_l_ordre_de_l_arbre() -> void:
	_fill()
	var torch: BlueprintData = BlueprintCatalog.get_plan(&"torch")
	assert_false(GameState.research(torch), "pas encore trouvé")
	GameState.add_plan(&"torch")
	assert_true(BlueprintCatalog.research_problem(torch, GameState.found_plans, GameState.researched_plans, GameState.storage).begins_with("Étudie d'abord"), "il faut la Métallurgie")
	GameState.add_plan(&"metallurgy")
	assert_true(GameState.research(BlueprintCatalog.get_plan(&"metallurgy")), "Métallurgie étudiée")
	assert_true(GameState.research(torch), "puis le Chalumeau")
	assert_true(GameState.is_known(&"torch"), "débloqué")


func test_un_equipement_a_plan_ne_se_fabrique_qu_apres_l_etude() -> void:
	_fill()
	var plate: ItemData = ItemCatalog.get_item(&"outfit_plate")
	assert_false(GameState.craft(plate), "plastron : plan Métallurgie à étudier")
	GameState.researched_plans.append(&"metallurgy")
	assert_true(GameState.craft(plate), "fabriqué")


func test_chaque_plan_debloque_quelque_chose() -> void:
	for plan: BlueprintData in BlueprintCatalog.ALL:
		assert_false(BlueprintCatalog.unlocks(plan.id).is_empty(), "%s ne débloque rien" % plan.id)
		for required: StringName in plan.requires:
			assert_true(BlueprintCatalog.get_plan(required) != null, "%s : prérequis inconnu %s" % [plan.id, required])


func test_un_plan_trouve_en_fouillant_rejoint_le_train() -> void:
	var choice := EncounterChoice.new()
	choice.plan_chance = 1.0
	var result := ExpeditionResult.new()
	var outcome := EncounterResolver.apply(choice, result, RandomNumberGenerator.new(), [], [&"chemistry"])
	assert_true(outcome.plan == &"chemistry" and result.plans == [&"chemistry"], "plan trouvé")
	result.boarded = true
	GameState.record_expedition(result)
	assert_true(&"chemistry" in GameState.found_plans, "rangé dans le train")


func test_un_plan_s_achete_une_seule_fois_en_gare() -> void:
	_fill()
	var refuge: RefugeData = GameState.REFUGES[0]
	var plan_offer: RefugeOffer = refuge.trades.filter(func(o: RefugeOffer) -> bool: return o.reward_plan != &"")[0]
	assert_true(GameState.use_refuge_offer(plan_offer, RandomNumberGenerator.new()), "acheté")
	assert_true(GameState.knows_plan(plan_offer.reward_plan), "connu")
	assert_false(GameState.use_refuge_offer(plan_offer, RandomNumberGenerator.new()), "pas deux fois")


# --- Extraction et machines -------------------------------------------------------------

func test_la_serre_produit_pendant_le_trajet() -> void:
	GameState.train.insert(0, preload("res://data/wagons/greenhouse.tres"))
	GameState.prepare_next_stop()
	assert_true(GameState.storage_amount(&"herb") == 2 and GameState.last_production.get(&"herb", 0) == 2, "2 plantes")


func test_le_laboratoire_a_besoin_de_plantes_infectees() -> void:
	GameState.train.insert(0, preload("res://data/wagons/laboratory.tres"))
	GameState.prepare_next_stop()
	assert_true(GameState.storage_amount(&"chemicals") == 0, "rien à distiller")
	GameState.storage[&"infected_herb"] = 3
	GameState.prepare_next_stop()
	assert_true(GameState.storage_amount(&"chemicals") == 1 and GameState.storage_amount(&"infected_herb") == 1, "2 plantes infectées → 1 produit chimique")


func test_une_voiture_a_plan_ne_se_construit_pas_sans_lui() -> void:
	_fill()
	assert_false(GameState.build_wagon(preload("res://data/wagons/greenhouse.tres")), "plan Horticulture à étudier")
	assert_true(GameState.build_wagon(preload("res://data/wagons/infirmary.tres")), "l'infirmerie n'a pas besoin de plan")


func test_l_epave_de_camion_demande_un_chalumeau() -> void:
	var zone := _zone()
	var player: Player = zone.get_node("World/Player")
	var truck := (load("res://props/truck_wreck/truck_wreck.tscn") as PackedScene).instantiate() as Harvestable
	zone.get_node("World").add_child(truck)
	var reason: String = player.interactor.block_reason_for.call(truck)
	assert_true(reason == "Il faut : chalumeau", "raison : %s" % reason)
	GameState.owned_items.append(ItemCatalog.get_item(&"tool_torch"))
	GameState.equip(ItemCatalog.get_item(&"tool_torch"))
	assert_true(player.interactor.block_reason_for.call(truck) == "", "avec le chalumeau, c'est bon")
	zone.free()


func test_le_kit_de_chimie_extrait_des_produits_chimiques() -> void:
	GameState.owned_items.append(ItemCatalog.get_item(&"tool_chem_kit"))
	GameState.equip(ItemCatalog.get_item(&"tool_chem_kit"))
	var zone := _zone()
	var session: StopSession = zone.get_node("StopSession")
	zone.call(&"_extract_with_tool", _loot(&"infected_herb"))
	assert_true(session.result.get_amount(&"chemicals") == 1, "1 produit chimique en plus")
	zone.call(&"_extract_with_tool", _loot(&"herb"))
	assert_true(session.result.get_amount(&"chemicals") == 1, "rien sur une plante saine")
	zone.free()


func test_infection_et_plans_se_sauvegardent() -> void:
	GameState.infection = 0.37
	GameState.add_plan(&"chemistry")
	GameState.researched_plans.append(&"metallurgy")
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_save()))
	GameState.new_run(1)
	assert_true(GameState.load_save(data), "relue")
	assert_almost(GameState.infection, 0.37, "infection")
	assert_true(GameState.found_plans == [&"chemistry"] and GameState.researched_plans == [&"metallurgy"], "plans")
