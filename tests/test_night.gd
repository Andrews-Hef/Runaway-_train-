extends TestCase
## Jour et nuit : horloge, temps qui passe (arrêt, trajet, gare), lumière, ennemis
## de nuit, hordes plus fréquentes, sauvegarde.

const STOP_ZONE: PackedScene = preload("res://levels/stop_zone/stop_zone.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const CITY: BiomeData = preload("res://data/biomes/city.tres")
const GameStateScript = preload("res://core/game_state.gd")

var _nodes: Array[Node] = []


func before_each() -> void:
	GameState.new_run(13)


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


static func _at(day: int, hour: int, minute: int = 0) -> int:
	return (day - 1) * DayClock.MINUTES_PER_DAY + hour * 60 + minute


# --- Horloge -----------------------------------------------------------------------

func test_la_lumiere_du_jour_suit_l_heure() -> void:
	assert_true(DayClock.daylight(_at(1, 12)) == 1.0, "midi : plein jour")
	assert_true(DayClock.daylight(_at(1, 0)) == 0.0, "minuit : nuit noire")
	assert_almost(DayClock.daylight(_at(1, 20)), 0.5, "20h : à mi-crépuscule")
	assert_almost(DayClock.daylight(_at(2, 6)), 0.5, "6h : à mi-aube")
	assert_true(DayClock.is_night(_at(1, 22)) and DayClock.is_night(_at(1, 4, 59)), "22h et 4h59 : nuit")
	assert_false(DayClock.is_night(_at(1, 5)) or DayClock.is_night(_at(1, 12)), "5h et midi : pas la nuit")
	assert_true(DayClock.describe(_at(2, 1, 5)) == "Jour 2 · 01:05", "texte")
	assert_true(DayClock.period_name(_at(1, 19, 30)) == "crépuscule", "crépuscule")


func test_le_temps_passe_entre_les_arrets() -> void:
	assert_true(GameState.clock_minutes == DayClock.START_MINUTES + DayClock.TRAVEL_MINUTES, "arrêt n°1 à 9h")
	var before: int = GameState.clock_minutes
	GameState.prepare_next_stop()
	assert_true(GameState.clock_minutes == before + DayClock.TRAVEL_MINUTES, "un trajet : 3 h")
	while not GameState.is_refuge_stop():
		GameState.prepare_next_stop()
	before = GameState.clock_minutes
	GameState.prepare_next_stop()
	assert_true(GameState.clock_minutes == before + DayClock.REFUGE_MINUTES + DayClock.TRAVEL_MINUTES, "1 h en gare, puis le trajet")


func test_l_heure_se_sauvegarde() -> void:
	GameState.clock_minutes = _at(3, 22, 15)
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_save()))
	assert_true(String(data["label"]).begins_with("Jour 3"), "le jour dans le nom de la sauvegarde")
	GameState.new_run(2)
	assert_true(GameState.load_save(data), "relu")
	assert_true(GameState.clock_minutes == _at(3, 22, 15), "même heure")


# --- Nuit --------------------------------------------------------------------------

func test_la_nuit_la_ruche_chasse_et_les_pilleurs_somnolent() -> void:
	var infected := ENEMY_SCENE.instantiate() as Enemy
	infected.data = preload("res://data/enemies/infected.tres")
	_add(infected)
	var raider := ENEMY_SCENE.instantiate() as Enemy
	raider.data = preload("res://data/enemies/raider.tres")
	_add(raider)
	infected.set_night(true)
	raider.set_night(true)
	assert_true(infected.sight_scale > 1.0 and infected.chase_speed() > infected.data.chase_speed, "infecté : voit plus loin, court plus vite")
	assert_true(raider.sight_scale < 1.0, "pilleur : voit moins loin")
	infected.set_night(false)
	assert_true(infected.sight_scale == 1.0 and infected.speed_scale == 1.0, "le jour : normal")


func test_les_hordes_sont_plus_frequentes_la_nuit() -> void:
	var day_hordes: int = 0
	var night_hordes: int = 0
	for seed_value: int in 400:
		if GameStateScript.roll_surprise(CITY, 12, seed_value * 7907, false) != null:
			day_hordes += 1
		if GameStateScript.roll_surprise(CITY, 12, seed_value * 7907, true) != null:
			night_hordes += 1
	assert_true(night_hordes > day_hordes * 1.25, "%d la nuit contre %d le jour" % [night_hordes, day_hordes])


func _zone(minutes: int) -> Node:
	GameState.new_run(5)
	GameState.stop_number = 6
	GameState.clock_minutes = minutes
	var zone := STOP_ZONE.instantiate()
	zone.set(&"zone_override", preload("res://data/zones/plains.tres"))
	zone.set(&"seed_override", 8)
	return _add(zone)


func test_de_nuit_la_lanterne_s_allume() -> void:
	var zone := _zone(_at(2, 23))
	var lantern: PointLight2D = zone.get_node("World/Player/Lantern")
	assert_true(lantern.energy > 0.5, "lanterne allumée")
	assert_true((zone.get_node("BiomeLight") as CanvasModulate).color.v < 0.7, "le monde est sombre")
	assert_true(zone.get(&"_night"), "c'est la nuit")
	for node: Node in tree.get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy.data.faction == EnemyData.Faction.INFECTED:
			assert_true(enemy.sight_scale > 1.0, "les infectés de la zone chassent")


func test_de_jour_pas_de_lanterne() -> void:
	var zone := _zone(_at(2, 12))
	assert_true((zone.get_node("World/Player/Lantern") as PointLight2D).energy == 0.0, "midi : lanterne éteinte")
	assert_true((zone.get_node("BiomeLight") as CanvasModulate).color.is_equal_approx(Color.WHITE), "lumière normale")


func test_le_temps_passe_pendant_l_arret() -> void:
	var zone := _zone(_at(2, 20, 30))
	var session: StopSession = zone.get_node("StopSession")
	session.tick(45.0)
	assert_true(zone.call(&"clock_now") == _at(2, 21, 15), "45 s d'arrêt = 45 min")
	zone.call(&"_update_daylight")
	assert_true(zone.get(&"_night"), "la nuit est tombée pendant l'arrêt")
	session.board()
	assert_true(GameState.clock_minutes == _at(2, 21, 15), "l'heure est gardée en remontant à bord")
