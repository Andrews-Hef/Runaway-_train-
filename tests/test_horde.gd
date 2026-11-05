extends TestCase
## Horde : surprise à l'arrivée (jamais annoncée), composition, assaut du train,
## état du train (effets, réparations), horde repoussée.

const HORDE: EventData = preload("res://data/events/horde.tres")
const STOP_ZONE: PackedScene = preload("res://levels/stop_zone/stop_zone.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const CITY: BiomeData = preload("res://data/biomes/city.tres")
const GameStateScript = preload("res://core/game_state.gd")

var _nodes: Array[Node] = []


func before_each() -> void:
	GameState.new_run(91)


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


func _fill() -> void:
	for loot: LootData in GameState.LOOT_TYPES:
		GameState.storage[loot.id] = 20


# --- Surprise ------------------------------------------------------------------------

func test_la_horde_n_est_jamais_annoncee() -> void:
	assert_false(HORDE.announced, "pas sur la carte de l'aiguillage")
	for seed_value: int in 300:
		assert_true(GameStateScript.roll_event(CITY, 12, seed_value) != HORDE, "jamais tirée comme météo")


func test_la_horde_surgit_parfois_a_l_arrivee() -> void:
	var hordes: int = 0
	for seed_value: int in 400:
		if GameStateScript.roll_surprise(CITY, 12, seed_value * 104729) == HORDE:
			hordes += 1
	assert_true(hordes > 70 and hordes < 130, "%d hordes sur 400 arrêts en ville (25 %% attendus)" % hordes)
	assert_true(GameStateScript.roll_surprise(CITY, 3, 5) == null or HORDE.min_stop <= 3, "pas avant l'arrêt n°4")


func test_la_horde_grossit_au_fil_des_arrets() -> void:
	var early := Horde.new()
	var late := Horde.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	early.setup(HORDE, 4, rng)
	rng.seed = 1
	late.setup(HORDE, 30, rng)
	assert_true(late.members.size() > early.members.size(), "plus grosse plus loin (%d → %d)" % [early.members.size(), late.members.size()])
	assert_true(late.members.size() <= HORDE.horde_max, "plafonnée")
	for enemy: EnemyData in early.members:
		assert_true(4 >= enemy.min_stop, "%s : pas encore apparu à l'arrêt 4" % enemy.id)
	early.free()
	late.free()


func test_la_horde_arrive_apres_un_delai_et_peut_etre_repoussee() -> void:
	var horde: Horde = _add(Horde.new())
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	horde.setup(HORDE, 6, rng)
	var arrivals: Array[int] = []
	var repelled: Array[bool] = []
	horde.arrived.connect(func(members: Array[EnemyData]) -> void: arrivals.append(members.size()))
	horde.repelled.connect(func() -> void: repelled.append(true))
	horde.tick(HORDE.horde_delay.x - 0.5)
	assert_true(arrivals.is_empty(), "pas tout de suite")
	horde.tick(HORDE.horde_delay.y)
	assert_true(arrivals.size() == 1, "elle surgit une fois")
	for i: int in arrivals[0]:
		horde.member_died()
	assert_true(repelled == [true], "tous tombés : horde repoussée")


# --- Assaut du train -----------------------------------------------------------------

func test_un_membre_de_horde_marche_sur_le_train_et_le_frappe() -> void:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.data = preload("res://data/enemies/infected.tres")
	enemy.position = Vector2(100.0, 300.0)
	_add(enemy)
	enemy.join_siege(Vector2(100.0, 100.0))
	enemy.think(0.05)
	assert_true(enemy.velocity.y < 0.0, "il monte vers le train")
	var hits: Array[int] = []
	enemy.train_hit.connect(func(_e: Enemy) -> void: hits.append(1))
	enemy.global_position = Vector2(100.0, 104.0)
	for i: int in 60:
		enemy.think(0.05)
	assert_true(hits.size() >= 1, "il frappe le train (%d coups en 3 s)" % hits.size())


func test_s_il_voit_le_joueur_il_le_poursuit() -> void:
	var player := preload("res://entities/player/player.tscn").instantiate() as Player
	player.position = Vector2(110.0, 300.0)
	_add(player)
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.data = preload("res://data/enemies/infected.tres")
	enemy.position = Vector2(100.0, 300.0)
	_add(enemy)
	enemy.target = player
	enemy.join_siege(Vector2(100.0, 100.0))
	enemy.think(0.05)
	assert_true(enemy.state != Enemy.State.WANDER, "le joueur à côté : il s'en occupe d'abord")


func test_la_zone_fait_surgir_la_horde_qui_abime_le_train() -> void:
	GameState.new_run(5)
	GameState.stop_number = 8
	var zone := STOP_ZONE.instantiate()
	zone.set(&"zone_override", preload("res://data/zones/boulevard.tres"))
	zone.set(&"seed_override", 23)
	zone.set(&"surprise_override", HORDE)
	_add(zone)
	var horde: Horde = zone.get(&"horde")
	assert_true(horde != null, "une horde prévue")
	var before: int = tree.get_nodes_in_group(Enemy.GROUP).size()
	horde.tick(60.0)
	var members: Array[Enemy] = []
	for node: Node in tree.get_nodes_in_group(Enemy.GROUP):
		if (node as Enemy).besieging:
			members.append(node as Enemy)
	assert_true(members.size() == horde.members.size(), "%d membres apparus" % members.size())
	assert_true(tree.get_nodes_in_group(Enemy.GROUP).size() == before + members.size(), "en plus des ennemis de la zone")
	zone.call(&"_on_train_hit", members[0])
	assert_true(GameState.train_condition < 1.0, "le train est abîmé")
	GameState.train_condition = 0.01
	zone.call(&"_on_train_hit", members[0])
	var session: StopSession = zone.get_node("StopSession")
	assert_true(session.remaining <= session.whistle_time, "à 0 %, le train démarre en catastrophe")


# --- État du train --------------------------------------------------------------------

func test_un_train_abime_n_a_plus_de_machines_et_un_train_critique_repart_plus_tot() -> void:
	# Une serre à bord, et de la place dans le stock pour ses plantes.
	GameState.train.append(preload("res://data/wagons/greenhouse.tres"))
	GameState.train_condition = 0.5
	assert_true(GameState.condition() == GameState.Condition.DAMAGED, "abîmé")
	assert_true(GameState.run_machines().is_empty(), "la serre ne tourne plus")
	assert_true(GameState.stop_time_factor() == 1.0, "arrêts normaux")
	GameState.train_condition = 0.1
	assert_true(GameState.condition() == GameState.Condition.CRITICAL, "critique")
	assert_true(GameState.stop_time_factor() < 1.0, "arrêts écourtés")
	GameState.train_condition = 1.0
	assert_false(GameState.run_machines().is_empty(), "réparé : la serre repart")


func test_reparer_a_la_cabine_et_au_depot() -> void:
	GameState.train_condition = 0.3
	assert_false(GameState.repair_train(), "sans matériaux : impossible")
	_fill()
	assert_true(GameState.repair_train(), "réparé")
	assert_almost(GameState.train_condition, 0.3 + GameState.REPAIR_STEP, "+25 %")
	assert_true(GameState.storage_amount(&"scrap") == 20 - GameState.REPAIR_COST[&"scrap"], "ferraille payée")
	assert_true(GameState.repair_train_at_depot(), "dépôt de la gare")
	assert_true(GameState.train_condition == 1.0, "comme neuf")
	assert_false(GameState.repair_train(), "rien à réparer")


func test_les_mecaniciens_reparent_pendant_le_trajet() -> void:
	GameState.train_condition = 0.5
	GameState.crew.append(CrewMember.create("Léa", &"mechanic", "mécanique", false))
	GameState.crew.append(CrewMember.create("Malik", &"scout", "repérage", false))
	GameState.prepare_next_stop()
	assert_almost(GameState.train_condition, 0.5 + GameState.MECHANIC_REPAIR, "un mécanicien : +10 %")
	assert_almost(GameState.last_repair, GameState.MECHANIC_REPAIR, "affiché au trajet")


func test_l_etat_du_train_se_sauvegarde() -> void:
	GameState.train_condition = 0.42
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_save()))
	GameState.new_run(3)
	assert_true(GameState.load_save(data), "relu")
	assert_almost(GameState.train_condition, 0.42, "état gardé")


func test_repousser_la_horde_rapporte_du_merite() -> void:
	var result := ExpeditionResult.new()
	result.boarded = true
	result.horde_repelled = true
	GameState.current_order = null
	GameState.record_expedition(result)
	assert_true(result.merit_gained == GameState.HORDE_MERIT, "+%d mérite" % GameState.HORDE_MERIT)
