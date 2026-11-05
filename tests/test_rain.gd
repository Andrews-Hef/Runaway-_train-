extends TestCase
## Pluie infectée : prévision à l'aiguillage, déroulé (alerte, pluie, fin), abris,
## exposition à découvert, plantes qui poussent et infectés qui sortent.

const RAIN: EventData = preload("res://data/events/infected_rain.tres")
const STOP_ZONE: PackedScene = preload("res://levels/stop_zone/stop_zone.tscn")
const MARSH: BiomeData = preload("res://data/biomes/marsh.tres")
const TUNDRA: BiomeData = preload("res://data/biomes/tundra.tres")
const GameStateScript = preload("res://core/game_state.gd")

var _nodes: Array[Node] = []


func before_each() -> void:
	GameState.new_run(64)


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


func _rain(duration: float = 90.0) -> InfectedRain:
	var rain: InfectedRain = _add(InfectedRain.new())
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	rain.setup(RAIN, duration, rng)
	return rain


# --- Prévision ------------------------------------------------------------------------

func test_la_pluie_depend_du_biome_et_de_l_arret() -> void:
	assert_true(RAIN.chance_for(MARSH, 7) > RAIN.chance_for(preload("res://data/biomes/countryside.tres"), 7), "plus de pluie au marais")
	assert_true(RAIN.chance_for(TUNDRA, 22) == 0.0, "jamais en toundra")
	assert_true(RAIN.chance_for(MARSH, 2) == 0.0, "jamais avant l'arrêt n°3")


func test_environ_quatre_arrets_du_marais_sur_dix_sont_pluvieux() -> void:
	var rainy: int = 0
	for seed_value: int in 400:
		if GameStateScript.roll_event(MARSH, 7, seed_value * 7919) == RAIN:
			rainy += 1
	assert_true(rainy > 120 and rainy < 200, "%d arrêts pluvieux sur 400 (40 %% attendus)" % rainy)


func test_la_meteo_suit_la_voie_choisie_et_se_sauvegarde() -> void:
	while GameState.stop_number < 6:
		GameState.prepare_next_stop()
	# On force une pluie sur la 2e voie pour le test.
	GameState.route_options[1].event = RAIN
	GameState.choose_route(1)
	assert_true(GameState.current_event == RAIN, "la voie choisie apporte la pluie")
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_save()))
	GameState.new_run(2)
	assert_true(GameState.load_save(data), "relu")
	assert_true(GameState.current_event == RAIN, "pluie sauvegardée")
	assert_true(GameState.route_options[1].event == RAIN, "et sur la carte de sa voie")


# --- Déroulé --------------------------------------------------------------------------

func test_alerte_puis_pluie_puis_fin() -> void:
	var rain := _rain()
	var steps: Array[String] = []
	rain.warned.connect(func(_s: float) -> void: steps.append("alerte"))
	rain.started.connect(func(_d: float) -> void: steps.append("pluie"))
	rain.ended.connect(func() -> void: steps.append("fin"))
	for i: int in 2000:
		rain.tick(0.1, true)
	assert_true(steps == ["alerte", "pluie", "fin"], "dans l'ordre : %s" % [steps])
	assert_true(rain.rain_duration >= RAIN.duration.x and rain.rain_duration <= RAIN.duration.y, "durée dans la fourchette")


func test_l_alerte_laisse_le_temps_de_s_abriter() -> void:
	var rain := _rain()
	# Les lambdas copient les variables locales : on passe par un tableau.
	var times: Dictionary[String, float] = {}
	var t: Array[float] = [0.0]
	rain.warned.connect(func(_s: float) -> void: times["alerte"] = t[0])
	rain.started.connect(func(_d: float) -> void: times["pluie"] = t[0])
	while not times.has("pluie") and t[0] < 200.0:
		t[0] += 0.1
		rain.tick(0.1, true)
	assert_almost(times["pluie"] - times["alerte"], RAIN.warning_time, "%d s d'alerte" % RAIN.warning_time, 0.15)
	assert_true(times["pluie"] >= 90.0 * RAIN.start_window.x - 0.2, "pas tout de suite en arrivant")


func test_a_decouvert_l_infection_monte_a_l_abri_non() -> void:
	var rain := _rain()
	var exposure: Array[float] = [0.0]
	rain.exposed.connect(func(amount: float) -> void: exposure[0] += amount)
	while not rain.is_raining():
		rain.tick(0.1, false)
	assert_true(exposure[0] == 0.0, "rien avant la pluie")
	for i: int in 100:
		rain.tick(0.1, true)
	assert_true(exposure[0] == 0.0, "à l'abri : rien")
	for i: int in 100:
		rain.tick(0.1, false)
	assert_almost(exposure[0], RAIN.exposure_rate * 10.0, "10 s à découvert", 0.002)


# --- Dans la zone ---------------------------------------------------------------------

func _zone() -> Node:
	GameState.new_run(5)
	GameState.stop_number = 8
	var zone := STOP_ZONE.instantiate()
	zone.set(&"zone_override", preload("res://data/zones/stilt_village.tres"))
	zone.set(&"seed_override", 17)
	zone.set(&"event_override", RAIN)
	return _add(zone)


func test_la_zone_prepare_la_pluie_et_ses_abris() -> void:
	var zone := _zone()
	var rain: InfectedRain = zone.get(&"rain")
	assert_true(rain != null and rain.event == RAIN, "pluie prévue")
	assert_true(zone.get_node_or_null("Weather") != null, "pluie à l'écran (arrêtée)")
	var train: Train = zone.get_node("World/Train")
	assert_true(zone.call(&"is_sheltered", train.global_position + train.door.position + Vector2(0, 20)), "abri du train")
	var house: Node2D = null
	for child: Node in zone.get_node("World").get_children():
		if child.scene_file_path.ends_with("house_ruin.tscn"):
			house = child
			break
	assert_true(house != null, "le village a des maisons")
	assert_true(zone.call(&"is_sheltered", house.global_position + Vector2(0, 30)), "contre une maison : à l'abri")
	assert_false(zone.call(&"is_sheltered", Vector2(-500, -500)), "loin de tout : à découvert")


func test_la_pluie_fait_sortir_des_infectes_et_pousser_des_plantes() -> void:
	var zone := _zone()
	var rain: InfectedRain = zone.get(&"rain")
	var enemies_before: int = tree.get_nodes_in_group(Enemy.GROUP).size()
	while not rain.is_raining():
		rain.tick(0.5, true)
	var enemies_after: int = tree.get_nodes_in_group(Enemy.GROUP).size()
	assert_true(enemies_after >= enemies_before + RAIN.extra_infected.x, "des infectés sortent (%d → %d)" % [enemies_before, enemies_after])
	var herbs_before: int = _count(zone, "infected_herb.tscn")
	while rain.phase != InfectedRain.Phase.OVER:
		rain.tick(0.5, true)
	assert_true(_count(zone, "infected_herb.tscn") >= herbs_before + RAIN.sprouts.x, "des plantes infectées ont poussé")


func _count(zone: Node, scene_name: String) -> int:
	var total: int = 0
	for child: Node in zone.get_node("World").get_children():
		if child.scene_file_path.ends_with(scene_name):
			total += 1
	return total
