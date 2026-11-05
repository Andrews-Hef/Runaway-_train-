extends TestCase
## Biomes : régions de la ligne, aiguillage à deux voies, sol piégeux, décors propres,
## règles (eau, froid, glace, flaques toxiques, alarmes de voiture).

const ROUTE_MENU = preload("res://ui/route/route_menu.gd")
const STOP_ZONE: PackedScene = preload("res://levels/stop_zone/stop_zone.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const MARSH: BiomeData = preload("res://data/biomes/marsh.tres")
const TUNDRA: BiomeData = preload("res://data/biomes/tundra.tres")
const CITY: BiomeData = preload("res://data/biomes/city.tres")
const INDUSTRIAL: BiomeData = preload("res://data/biomes/industrial.tres")

var _nodes: Array[Node] = []


func before_each() -> void:
	GameState.new_run(77)


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


## Avance jusqu'à l'arrêt `stop` (sans jouer les arrêts).
func _go_to_stop(stop: int) -> void:
	while GameState.stop_number < stop:
		GameState.prepare_next_stop()


# --- Régions et aiguillage --------------------------------------------------------------

func test_chaque_region_a_assez_de_types_d_arret() -> void:
	for zone: ZoneProfile in GameState.ZONES:
		assert_true(zone.biome != null, "%s sans biome" % zone.id)
		assert_false(zone.specialty.is_empty(), "%s sans spécialité" % zone.id)
	for biome: BiomeData in GameState.REGIONS:
		var count: int = GameState.ZONES.filter(func(zone: ZoneProfile) -> bool: return zone.biome == biome).size()
		assert_true(count >= 3, "%s : %d types d'arrêt (3 attendus)" % [biome.id, count])


func test_la_ligne_change_de_region_a_chaque_gare_refuge() -> void:
	assert_true(GameState.region_for(1).id == &"countryside" and GameState.region_for(5).id == &"countryside", "arrêts 1 à 5 : campagne")
	assert_true(GameState.region_for(6) == MARSH and GameState.region_for(10) == MARSH, "6 à 10 : marais")
	assert_true(GameState.region_for(11) == CITY, "11 : ville")
	assert_true(GameState.region_for(16) == INDUSTRIAL, "16 : zone industrielle")
	assert_true(GameState.region_for(21) == TUNDRA, "21 : toundra")
	assert_true(GameState.region_for(26).id == &"countryside", "la ligne repart après la toundra")


func test_le_premier_arret_n_a_pas_d_aiguillage() -> void:
	assert_true(GameState.stop_number == 1, "arrêt n°1")
	assert_false(GameState.has_route_choice(), "un seul chemin pour commencer")


func test_l_aiguillage_propose_deux_voies_de_la_region() -> void:
	_go_to_stop(7)
	assert_true(GameState.has_route_choice(), "deux voies")
	assert_true(GameState.route_options.size() == GameState.ROUTE_CHOICES, "%d voies" % GameState.ROUTE_CHOICES)
	var first: ZoneProfile = GameState.route_options[0].zone
	var second: ZoneProfile = GameState.route_options[1].zone
	assert_true(first != second, "deux types d'arrêt différents")
	assert_true(first.biome == MARSH and second.biome == MARSH, "tous deux dans le marais")
	assert_true(GameState.current_zone == first, "la 1re voie par défaut")


func test_choisir_une_voie_change_l_arret_et_l_ordre() -> void:
	_go_to_stop(3)
	var option: Object = GameState.route_options[1]
	assert_true(GameState.choose_route(1), "voie n°2 prise")
	assert_true(GameState.current_zone == option.get(&"zone"), "l'arrêt est celui de la voie")
	assert_true(GameState.current_seed == option.get(&"seed"), "sa graine")
	assert_true(GameState.current_order == option.get(&"order"), "son ordre du capitaine")
	assert_false(GameState.choose_route(5), "pas de voie n°6")


func test_pas_d_aiguillage_avant_une_gare_refuge() -> void:
	_go_to_stop(5)
	assert_true(GameState.is_refuge_stop(), "arrêt n°5 : gare refuge")
	assert_true(GameState.route_options.is_empty(), "pas de voies à choisir")


func test_l_aiguillage_se_sauvegarde() -> void:
	_go_to_stop(8)
	GameState.choose_route(1)
	var zones: Array[StringName] = []
	for option: Object in GameState.route_options:
		zones.append((option.get(&"zone") as ZoneProfile).id)
	var chosen: StringName = GameState.current_zone.id
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_save()))
	GameState.new_run(3)
	assert_true(GameState.load_save(data), "sauvegarde relue")
	assert_true(GameState.route_options.size() == 2, "les deux voies sont revenues")
	for i: int in zones.size():
		assert_true((GameState.route_options[i].get(&"zone") as ZoneProfile).id == zones[i], "voie %d" % i)
	assert_true(GameState.current_zone.id == chosen, "et le choix fait")


func test_le_menu_de_l_aiguillage_montre_les_voies_et_fait_choisir() -> void:
	_go_to_stop(12)
	var menu: CanvasLayer = _add(ROUTE_MENU.new())
	menu.call(&"open")
	assert_true(menu.call(&"card_count") == 2, "deux cartes")
	var picked: Array[int] = []
	menu.connect(&"chosen", func(index: int) -> void: picked.append(index))
	menu.call(&"_choose", 1)
	assert_true(picked == [1], "voie n°2 choisie")
	assert_true(GameState.current_zone == GameState.route_options[1].zone, "GameState suit")


# --- Générateur : sol piégeux et objets propres --------------------------------------

func test_les_nappes_de_sol_piegeux_apparaissent_et_restent_praticables() -> void:
	var bog: ZoneProfile = preload("res://data/zones/bog.tres")
	var spawn := Vector2(120.0, 160.0)
	var layout := ZoneGenerator.generate(bog, 123, [spawn], 12)
	var hazard: int = 0
	for tile: int in layout.tiles:
		if tile == ZoneGenerator.Tile.HAZARD:
			hazard += 1
	assert_true(hazard > 20, "de l'eau dans la tourbière (%d tuiles)" % hazard)
	assert_false(layout.is_hazard_at(spawn), "pas d'eau là où le joueur apparaît")
	for spawn_data: ZoneGenerator.Spawn in layout.spawns:
		if spawn_data.kind in [&"herb", &"dead_tree", &"wreck"]:
			assert_false(layout.is_hazard_at(spawn_data.position), "%s pas dans l'eau" % spawn_data.kind)


func test_l_usine_chimique_a_ses_futs() -> void:
	var plant: ZoneProfile = preload("res://data/zones/chemical_plant.tres")
	var layout := ZoneGenerator.generate(plant, 5, [], 16)
	assert_true(layout.count(&"barrel") >= plant.extras[&"barrel"].x, "fûts chimiques : %d" % layout.count(&"barrel"))


func test_les_zones_de_la_campagne_n_ont_pas_de_sol_piegeux() -> void:
	var layout := ZoneGenerator.generate(preload("res://data/zones/plains.tres"), 9, [], 3)
	assert_false(ZoneGenerator.Tile.HAZARD in layout.tiles, "la campagne reste comme avant")


func test_la_toundra_a_ses_sapins_enneiges() -> void:
	GameState.new_run(5)
	var zone := STOP_ZONE.instantiate()
	zone.set(&"zone_override", preload("res://data/zones/pine_forest.tres"))
	zone.set(&"seed_override", 31)
	_add(zone)
	var pines: int = 0
	var bare: int = 0
	for child: Node in zone.get_node("World").get_children():
		if child.scene_file_path.ends_with("snow_pine.tscn"):
			pines += 1
		elif child.scene_file_path.ends_with("dead_tree.tscn"):
			bare += 1
	assert_true(pines >= 10 and bare == 0, "sapins enneigés à la place des arbres morts (%d)" % pines)
	assert_true(zone.get_node_or_null("Weather") != null, "il neige")
	assert_true(zone.get_node_or_null("BiomeLight") != null, "lumière froide")


# --- Règles des biomes -----------------------------------------------------------------

func _rules(biome: BiomeData, outfit: StringName = &"") -> BiomeRules:
	var loadout := Loadout.new()
	if outfit != &"":
		loadout.equip(ItemCatalog.get_item(outfit))
	var rules := BiomeRules.new()
	rules.setup(biome, loadout)
	return rules


func test_l_eau_du_marais_ralentit() -> void:
	var rules := _rules(MARSH)
	var speeds: Array[float] = []
	rules.terrain_changed.connect(func(speed: float, _slippery: bool) -> void: speeds.append(speed))
	rules.tick(0.1, true)
	assert_true(speeds == [BiomeRules.WATER_SPEED], "dans l'eau : plus lent")
	rules.tick(0.1, false)
	assert_true(speeds.back() == 1.0, "sorti de l'eau : vitesse normale")
	rules.free()


func test_le_froid_use_la_vie_sans_tenue_chaude() -> void:
	var cold := _rules(TUNDRA)
	var hurt: Array[int] = []
	cold.hurt.connect(func(amount: int, _message: String) -> void: hurt.append(amount))
	for i: int in ceili(BiomeRules.COLD_TICK / 0.5) + 1:
		cold.tick(0.5, false)
	assert_true(hurt == [1], "1 PV perdu au bout de %d s" % BiomeRules.COLD_TICK)
	var warm := _rules(TUNDRA, &"outfit_padded")
	var warm_hurt: Array[int] = []
	warm.hurt.connect(func(amount: int, _message: String) -> void: warm_hurt.append(amount))
	for i: int in 100:
		warm.tick(0.5, false)
	assert_true(warm_hurt.is_empty(), "la veste rembourrée tient chaud")
	cold.free()
	warm.free()


func test_la_glace_fait_glisser() -> void:
	var rules := _rules(TUNDRA)
	var slips: Array[bool] = []
	rules.terrain_changed.connect(func(_speed: float, slippery: bool) -> void: slips.append(slippery))
	rules.tick(0.1, true)
	assert_true(slips == [true], "sur la glace, on glisse")
	rules.free()


func test_les_flaques_toxiques_brulent_sauf_en_combinaison() -> void:
	var bare := _rules(INDUSTRIAL)
	var messages: Array[String] = []
	bare.hurt.connect(func(_amount: int, message: String) -> void: messages.append(message))
	for i: int in 10:
		bare.tick(0.1, false)
	assert_true(messages.is_empty(), "hors des flaques : rien")
	for i: int in 25:
		bare.tick(0.1, true)
	assert_true(messages.size() == 2, "deux brûlures en 2,5 s (obtenu %d)" % messages.size())
	assert_false(messages[0].is_empty(), "la première prévient")
	assert_true(messages[1].is_empty(), "les suivantes ne répètent pas le message")
	var suited := _rules(INDUSTRIAL, &"outfit_hazmat")
	var suited_hurt: Array[String] = []
	suited.hurt.connect(func(_amount: int, message: String) -> void: suited_hurt.append(message))
	for i: int in 30:
		suited.tick(0.1, true)
	assert_true(suited_hurt.is_empty(), "la combinaison étanche protège")
	bare.free()
	suited.free()


func test_les_voitures_de_la_ville_peuvent_sonner() -> void:
	var rules := _rules(CITY)
	var alarms: Array[Vector2] = []
	rules.alarm_raised.connect(func(at: Vector2) -> void: alarms.append(at))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var expected: int = 0
	var check := RandomNumberGenerator.new()
	check.seed = 4
	for i: int in 50:
		if check.randf() < BiomeRules.ALARM_CHANCE:
			expected += 1
		rules.car_searched(Vector2(i, 0), rng)
	assert_true(alarms.size() == expected and expected > 0, "%d alarmes sur 50 voitures" % alarms.size())
	var calm := _rules(MARSH)
	assert_false(calm.car_searched(Vector2.ZERO, rng), "pas d'alarme hors de la ville")
	rules.free()
	calm.free()


func test_une_alarme_fait_accourir_les_ennemis() -> void:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.data = preload("res://data/enemies/raider.tres")
	enemy.position = Vector2(500.0, 500.0)
	_add(enemy)
	enemy.alert(Vector2(300.0, 300.0))
	assert_true(enemy.state == Enemy.State.CHASE, "il accourt")
	assert_true(enemy.home == Vector2(300.0, 300.0), "vers l'alarme")


func test_les_tenues_protegent_des_biomes() -> void:
	var padded: ItemData = ItemCatalog.get_item(&"outfit_padded")
	var hazmat: ItemData = ItemCatalog.get_item(&"outfit_hazmat")
	assert_true(&"cold" in padded.resists and "Tient chaud" in padded.describe_effects(), "veste rembourrée : chaude")
	assert_true(&"toxic" in hazmat.resists and "toxiques" in hazmat.describe_effects(), "combinaison : étanche")
