extends TestCase
## Énergie de la chaudière et pannes : un trajet brûle de l'énergie, une chaudière vide
## ou une panne moteur arrêtent le train en pleine voie, et on en repart.

const WOOD: LootData = preload("res://data/loot/wood.tres")
const COAL: LootData = preload("res://data/loot/coal.tres")
const STOP_ZONE: PackedScene = preload("res://levels/stop_zone/stop_zone.tscn")
const PLAINS: ZoneProfile = preload("res://data/zones/plains.tres")
const StopZoneScript = preload("res://levels/stop_zone/stop_zone.gd")

var _nodes: Array[Node] = []


func before_each() -> void:
	GameState.new_run(5)
	GameState.engine_trouble = true


func after_each() -> void:
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	GameState.new_run()


func _zone() -> Node:
	var zone: Node = STOP_ZONE.instantiate()
	tree.root.add_child(zone)
	_nodes.append(zone)
	return zone


func _fuels() -> Array[LootData]:
	return GameState.fuel_types()


# --- Règles pures -------------------------------------------------------------------

func test_un_trajet_coute_plus_cher_avec_un_long_train() -> void:
	assert_true(EngineRules.trip_cost(4) == 6, "4 voitures : 6 d'énergie")
	assert_true(EngineRules.trip_cost(8) == 10, "8 voitures : 10")
	assert_true(EngineRules.START_ENERGY / EngineRules.trip_cost(4) == 4, "4 trajets au départ")


func test_bois_et_charbon_brulent_les_autres_non() -> void:
	assert_true(WOOD.fuel == 2 and COAL.fuel == 6, "bois 2, charbon 6")
	assert_true(_fuels().size() == 2, "deux combustibles")
	assert_true(COAL.describe().contains("6 d'énergie"), "le charbon dit ce qu'il donne")


func test_on_brule_sans_gaspiller() -> void:
	var stock := {&"wood": 5, &"coal": 2}
	assert_true(EngineRules.fuel_for(3, stock, _fuels()) == {&"wood": 2}, "3 d'énergie : 2 bois, pas un charbon entier")
	assert_true(EngineRules.fuel_for(10, stock, _fuels()) == {&"coal": 1, &"wood": 2}, "10 : 1 charbon + 2 bois")
	assert_true(EngineRules.fuel_for(3, {&"coal": 1}, _fuels()) == {&"coal": 1}, "que du charbon : on en brûle un")
	assert_true(EngineRules.fuel_for(20, {&"wood": 1}, _fuels()) == {&"wood": 1}, "pas assez : tout ce qu'il y a")


func test_un_train_abime_tombe_plus_souvent_en_panne() -> void:
	var neuf: float = EngineRules.breakdown_chance(1.0, 0)
	var abime: float = EngineRules.breakdown_chance(0.3, 0)
	assert_true(abime > neuf * 3.0, "train abîmé : bien plus de pannes (%.2f contre %.2f)" % [abime, neuf])
	assert_true(EngineRules.breakdown_chance(0.3, 2) < abime, "les mécaniciens en évitent")
	assert_true(EngineRules.breakdown_chance(1.0, 2) >= EngineRules.BREAKDOWN_MIN, "jamais zéro")


func test_les_mecaniciens_reparent_plus_vite() -> void:
	var seul: float = EngineRules.repair_seconds(EngineRules.BREAKDOWN, 0)
	assert_true(EngineRules.repair_seconds(EngineRules.BREAKDOWN, 2) < seul, "deux mécaniciens : plus vite")
	assert_true(EngineRules.repair_seconds(EngineRules.DRY, 2) == EngineRules.PRESSURE_SECONDS, "panne sèche : le temps que la pression remonte")


# --- La chaudière --------------------------------------------------------------------

func test_un_trajet_brule_de_l_energie() -> void:
	var before: int = GameState.energy
	GameState.prepare_next_stop()
	assert_true(GameState.energy == before - GameState.trip_energy(), "un trajet de moins dans la chaudière")
	assert_false(GameState.is_incident_stop(), "assez d'énergie : pas d'arrêt forcé")


func test_on_charge_la_chaudiere_avec_le_stock_sans_deborder() -> void:
	GameState.storage[&"wood"] = 5
	GameState.energy = GameState.energy_capacity() - 4
	assert_true(GameState.loadable_fuel(WOOD) == 2, "place pour 2 bois")
	assert_true(GameState.loadable_fuel(COAL) == 0, "pas pour un charbon (6)")
	assert_true(GameState.load_fuel(WOOD, 5) == 2, "2 bois chargés")
	assert_true(GameState.energy == GameState.energy_capacity(), "chaudière pleine")
	assert_true(GameState.storage_amount(&"wood") == 3, "pris dans le stock")


func test_une_locomotive_renforcee_a_une_plus_grande_reserve() -> void:
	var before: int = GameState.energy_capacity()
	GameState.locomotive_level = 2
	assert_true(GameState.energy_capacity() > before, "plus de réserve au niveau 2")


func test_sans_les_pannes_rien_ne_brule() -> void:
	GameState.engine_trouble = false
	var before: int = GameState.energy
	GameState.prepare_next_stop()
	assert_true(GameState.energy == before, "énergie intacte (débogage, tests des autres systèmes)")


# --- Panne sèche ------------------------------------------------------------------------

func test_une_chaudiere_vide_arrete_le_train_en_pleine_voie() -> void:
	GameState.energy = 3
	var stop: int = GameState.stop_number
	GameState.prepare_next_stop()
	assert_true(GameState.incident == EngineRules.DRY, "panne sèche")
	assert_true(GameState.stop_number == stop, "en pleine voie : pas encore l'arrêt suivant")
	assert_true(GameState.route_options.size() == 1 and not GameState.has_route_choice(), "pas d'aiguillage")
	assert_true(GameState.current_order == null and GameState.current_refuge == null, "ni ordre ni gare")
	assert_true(GameState.energy == 0, "chaudière éteinte")
	assert_true(GameState.incident_left() == EngineRules.rest_of_trip(GameState.trip_energy()), "de quoi finir le trajet")
	assert_true(GameState.captain_notes.any(func(note: String) -> bool: return note.contains("Panne sèche")), "le trajet l'annonce")


func test_on_ravitaille_avec_le_sac_puis_le_stock() -> void:
	GameState.energy = 0
	GameState.prepare_next_stop()
	var bag := ExpeditionResult.new()
	bag.add_loot(&"wood", 1)
	GameState.storage.clear()
	GameState.storage[&"coal"] = 2
	var used: Dictionary = GameState.feed_incident(bag)
	assert_true((used["bag"] as Dictionary).get(&"wood", 0) == 1, "le bois du sac d'abord")
	assert_true((used["stock"] as Dictionary).get(&"coal", 0) == 1, "puis un charbon du stock")
	assert_true(bag.get_amount(&"wood") == 0, "le sac s'est vidé")
	assert_true(GameState.storage_amount(&"coal") == 1, "un charbon reste au stock")
	assert_true(GameState.incident_left() == 0, "assez pour repartir")


func test_on_repart_de_la_panne_et_on_finit_le_trajet() -> void:
	GameState.energy = 0
	var stop: int = GameState.stop_number
	GameState.prepare_next_stop()
	GameState.storage[&"coal"] = 3
	GameState.feed_incident(null)
	var energy: int = GameState.energy
	var rest: int = GameState.incident_rest
	GameState.prepare_next_stop()
	assert_false(GameState.is_incident_stop(), "la panne est derrière nous")
	assert_true(GameState.stop_number == stop + 1, "on arrive à l'arrêt suivant")
	assert_true(GameState.energy == energy - rest, "la fin du trajet a brûlé son énergie")


# --- Panne moteur -----------------------------------------------------------------------

func test_une_panne_moteur_demande_des_pieces_rapportees() -> void:
	GameState.stop_number = 4
	GameState.train_condition = 0.0
	# Hasard tiré de la partie et du trajet : on cherche une partie où ça casse.
	var broke: bool = false
	for run_seed: int in range(1, 60):
		GameState.new_run(run_seed)
		GameState.engine_trouble = true
		GameState.stop_number = 4
		GameState.train_condition = 0.2
		GameState.prepare_next_stop()
		if GameState.incident == EngineRules.BREAKDOWN:
			broke = true
			break
	assert_true(broke, "un train à 20 %% finit par tomber en panne")
	assert_true(GameState.incident_left() == EngineRules.parts_needed(true), "train critique : une pièce de plus")
	var bag := ExpeditionResult.new()
	bag.add_loot(&"parts", 1)
	GameState.storage[&"parts"] = 5
	GameState.feed_incident(bag)
	assert_true(GameState.incident_left() == 0, "les pièces sont rapportées")
	assert_true(bag.get_amount(&"parts") == 0 and GameState.storage_amount(&"parts") == 5 - (EngineRules.parts_needed(true) - 1),
		"une du sac, le reste du stock")


func test_pas_de_panne_moteur_aux_premiers_arrets() -> void:
	for run_seed: int in range(1, 40):
		GameState.new_run(run_seed)
		GameState.engine_trouble = true
		GameState.train_condition = 0.0
		GameState.prepare_next_stop()
		assert_false(GameState.incident == EngineRules.BREAKDOWN, "pas avant l'arrêt %d (partie %d)" % [EngineRules.BREAKDOWN_FROM_STOP, run_seed])


func test_une_panne_ne_change_pas_les_arrets_qui_suivent() -> void:
	# Même partie, avec et sans pannes : les voies tirées après sont les mêmes.
	GameState.new_run(77)
	GameState.engine_trouble = false
	for i: int in 3:
		GameState.prepare_next_stop()
	var zones_without: Array = GameState.route_options.map(func(o: Object) -> StringName: return (o.get(&"zone") as ZoneProfile).id)
	GameState.new_run(77)
	GameState.engine_trouble = true
	GameState.energy = 999
	for i: int in 3:
		GameState.prepare_next_stop()
	var zones_with: Array = GameState.route_options.map(func(o: Object) -> StringName: return (o.get(&"zone") as ZoneProfile).id)
	assert_true(zones_with == zones_without, "le moteur a son propre hasard")


func test_l_arret_force_est_sauvegarde() -> void:
	GameState.energy = 0
	GameState.prepare_next_stop()
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_save()))
	GameState.new_run(2)
	assert_true(GameState.load_save(data), "relue")
	assert_true(GameState.incident == EngineRules.DRY, "toujours en panne sèche")
	assert_true(GameState.incident_left() > 0, "il manque toujours du combustible")


# --- L'arrêt forcé, dans la zone ------------------------------------------------------

func test_en_panne_le_train_ne_part_pas_tant_qu_il_n_est_pas_repare() -> void:
	GameState.energy = 0
	GameState.storage.clear()
	GameState.prepare_next_stop()
	var zone: Node = _zone()
	var session: StopSession = zone.get_node("StopSession")
	assert_true(session.is_held(), "pas de compte à rebours : le train est en panne")
	assert_true(zone.get(&"horde") != null, "le train immobile attire une horde")
	zone.call(&"_on_boarding_requested")
	assert_true(session.is_running(), "on ne monte pas dans un train en panne")
	session.tick(600.0)
	assert_true(session.is_held(), "il n'est pas parti sans toi")
	zone.call(&"feed_engine")
	assert_true(float(zone.get(&"_repair_left")) < 0.0, "rien à donner : rien ne se passe")
	GameState.storage[&"coal"] = 1
	zone.call(&"feed_engine")
	assert_true(float(zone.get(&"_repair_left")) > 0.0, "chaudière rechargée : la pression remonte")
	zone.call(&"_tick_repair", 100.0)
	assert_true(session.state == StopSession.State.WHISTLE, "le train siffle")
	assert_true(is_equal_approx(session.remaining, EngineRules.DEPARTURE_SECONDS), "et part bientôt")
	zone.call(&"_on_boarding_requested")
	assert_false(session.is_running(), "on monte à bord")
	assert_true(session.result.boarded, "à bord")


func test_le_sac_aide_a_reparer_la_locomotive() -> void:
	GameState.incident = EngineRules.BREAKDOWN
	GameState.incident_need = 2
	GameState.storage.clear()
	var zone: Node = _zone()
	var session: StopSession = zone.get_node("StopSession")
	session.add_loot(preload("res://data/loot/parts.tres"), 2)
	zone.call(&"feed_engine")
	assert_true(session.result.get_amount(&"parts") == 0, "les pièces du sac sont posées")
	assert_true(float(zone.get(&"_repair_left")) > 0.0, "la réparation commence")


func test_la_zone_d_une_panne_a_de_quoi_s_en_sortir() -> void:
	var dry: ZoneProfile = StopZoneScript.incident_zone(PLAINS, EngineRules.DRY)
	assert_true(dry.dead_trees.x >= 3 and dry.count_range(&"coal_pile").x >= 1, "du bois et du charbon")
	assert_true(PLAINS.count_range(&"coal_pile") == Vector2i.ZERO, "la zone d'origine ne change pas")
	var broken: ZoneProfile = StopZoneScript.incident_zone(PLAINS, EngineRules.BREAKDOWN)
	assert_true(broken.wrecks.x >= 4, "des épaves à fouiller pour les pièces")


func test_en_panne_moteur_les_epaves_cachent_plus_de_pieces() -> void:
	GameState.incident = EngineRules.BREAKDOWN
	GameState.incident_need = 2
	var zone: Node = _zone()
	var wrecks: int = 0
	for node: Node in zone.find_children("*", "Harvestable", true, false):
		var harvest := node as Harvestable
		if harvest.bonus_loot and harvest.bonus_loot.id == &"parts":
			wrecks += 1
			assert_true(harvest.bonus_chance >= StopZoneScript.BREAKDOWN_PARTS_CHANCE, "%s : plus de chances" % harvest.name)
	assert_true(wrecks >= 4, "au moins 4 épaves (%d)" % wrecks)
