extends TestCase
## Combat : vie, coup du joueur, infectés et pilleurs, apparition par zone.

const ENEMY_SCENE: PackedScene = preload("res://entities/enemy/enemy.tscn")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const INFECTED: EnemyData = preload("res://data/enemies/infected.tres")
const RAIDER: EnemyData = preload("res://data/enemies/raider.tres")

var _nodes: Array[Node] = []


func after_each() -> void:
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func _add(node: Node) -> Node:
	tree.root.add_child(node)
	_nodes.append(node)
	return node


func _enemy(enemy_data: EnemyData, at: Vector2) -> Enemy:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.data = enemy_data
	enemy.position = at
	return _add(enemy) as Enemy


func _player(at: Vector2) -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = at
	return _add(player) as Player


## Fait réfléchir l'ennemi pendant `seconds` (sans moteur physique).
func _think(enemy: Enemy, seconds: float) -> void:
	var steps: int = ceili(seconds / 0.05)
	for i: int in steps:
		enemy.think(0.05)


func test_la_vie_compte_les_coups() -> void:
	var health := HealthComponent.new()
	_add(health)
	health.reset(5)
	var deaths: Array[int] = [0]
	health.died.connect(func() -> void: deaths[0] += 1)
	assert_true(health.take_damage(2) == 2 and health.health == 3, "5 - 2 = 3")
	assert_true(health.take_damage(9) == 3 and health.is_dead(), "pas en dessous de 0")
	health.take_damage(1)
	assert_true(deaths[0] == 1, "on ne meurt qu'une fois")


func test_l_invincibilite_apres_un_coup() -> void:
	var health := HealthComponent.new()
	health.invulnerable_time = 5.0
	_add(health)
	health.reset(10)
	assert_true(health.take_damage(1) == 1, "premier coup")
	assert_true(health.take_damage(1) == 0, "invincible juste après")


func test_l_infecte_repere_et_poursuit() -> void:
	var player := _player(Vector2(300, 100))
	var enemy := _enemy(INFECTED, Vector2(100, 100))
	enemy.target = player
	_think(enemy, 0.2)
	assert_true(enemy.state == Enemy.State.WANDER, "trop loin : il erre")
	player.position = Vector2(160, 100)
	_think(enemy, 0.1)
	assert_true(enemy.state == Enemy.State.CHASE, "à 60 px : il poursuit")
	assert_true(enemy.velocity.x > 0.0, "vers le joueur")


func test_le_coup_part_apres_l_elan_et_s_esquive() -> void:
	var player := _player(Vector2(110, 100))
	var enemy := _enemy(INFECTED, Vector2(100, 100))
	enemy.target = player
	var landed: Array[int] = [0]
	enemy.attack_landed.connect(func(_e: Enemy) -> void: landed[0] += 1)
	_think(enemy, 0.1)
	assert_true(enemy.state == Enemy.State.WINDUP, "à portée : il prend son élan")
	_think(enemy, INFECTED.windup + 0.05)
	assert_true(landed[0] == 1, "le coup porte")
	# Deuxième fois : le joueur s'éloigne pendant l'élan.
	_think(enemy, INFECTED.cooldown + 0.1)
	assert_true(enemy.state == Enemy.State.WINDUP, "il recommence")
	player.position = Vector2(160, 100)
	_think(enemy, INFECTED.windup + 0.05)
	assert_true(landed[0] == 1, "esquivé")


func test_le_joueur_touche_devant_lui() -> void:
	var player := _player(Vector2(100, 100))
	player.facing = Vector2.RIGHT
	player.attack_damage = 2
	var front := _enemy(RAIDER, Vector2(116, 100))
	var behind := _enemy(RAIDER, Vector2(84, 100))
	assert_true(player.strike() == 1, "un seul touché")
	assert_true(front.health.health == RAIDER.max_health - 2, "celui de devant")
	assert_true(behind.health.health == RAIDER.max_health, "pas celui de derrière")
	assert_true(front.state == Enemy.State.HURT, "il recule")


func test_un_ennemi_meurt_et_le_dit() -> void:
	var enemy := _enemy(INFECTED, Vector2(100, 100))
	var dead: Array[Enemy] = []
	enemy.died.connect(func(e: Enemy) -> void: dead.append(e))
	enemy.take_hit(INFECTED.max_health, Vector2(90, 100))
	assert_true(enemy.is_dead() and dead.size() == 1, "mort annoncée")
	assert_false(enemy.is_in_group(Enemy.GROUP), "il ne compte plus parmi les ennemis")


func test_le_pilleur_vole_dans_le_sac() -> void:
	var session := StopSession.new()
	_add(session)
	session.start(60.0)
	session.result.add_loot(&"wood", 2)
	var stolen := session.steal(RAIDER.steal_amount, RandomNumberGenerator.new())
	assert_true(stolen.get(&"wood", 0) == 1 and session.result.get_amount(&"wood") == 1, "1 bois volé")
	session.result.remove_loot(&"wood", 1)
	assert_true(session.steal(1, RandomNumberGenerator.new()).is_empty(), "sac vide : rien à voler")


func test_tomber_termine_la_sortie() -> void:
	var session := StopSession.new()
	_add(session)
	session.start(60.0)
	session.result.add_loot(&"scrap", 3)
	session.fall()
	assert_true(session.result.fell and not session.result.boarded, "tombé, pas à bord")
	GameState.new_run(5)
	GameState.record_expedition(session.result)
	assert_true(GameState.storage_total() == 0, "le butin est perdu")
	GameState.new_run()


func test_les_ennemis_apparaissent_selon_la_zone() -> void:
	var spawn := ZoneGenerator.TRAIN_POSITION + Vector2(156, 56)
	for zone: ZoneProfile in GameState.ZONES:
		for zone_seed: int in [1, 2, 3]:
			var layout := ZoneGenerator.generate(zone, zone_seed, [spawn])
			var counts: Dictionary[StringName, int] = {}
			for entry: ZoneGenerator.Spawn in layout.spawns:
				if EnemyCatalog.get_enemy(entry.kind):
					counts[entry.kind] = counts.get(entry.kind, 0) + 1
					assert_true(entry.position.distance_to(spawn) >= ZoneGenerator.ENEMY_SAFE_RADIUS, "%s trop près du joueur" % entry.kind)
			for kind: StringName in counts:
				assert_true(counts[kind] <= zone.count_range(kind).y, "%s : trop de %s" % [zone.id, kind])


func test_au_premier_arret_seulement_des_infectes() -> void:
	for zone: ZoneProfile in GameState.ZONES:
		for zone_seed: int in [1, 2, 3, 4]:
			for entry: ZoneGenerator.Spawn in ZoneGenerator.generate(zone, zone_seed, [], 1).spawns:
				var enemy: EnemyData = EnemyCatalog.get_enemy(entry.kind)
				if enemy:
					assert_true(enemy.min_stop <= 1, "%s dès l'arrêt 1" % enemy.id)


func test_chaque_faction_a_ses_quatre_profils() -> void:
	for faction: int in EnemyData.Faction.values():
		var archetypes: Array[int] = []
		for enemy: EnemyData in EnemyCatalog.ALL:
			if enemy.faction == faction:
				archetypes.append(enemy.archetype)
				assert_true(enemy.frames != null, "%s : sprites" % enemy.id)
		for archetype: int in EnemyData.Archetype.values():
			assert_true(archetype in archetypes, "faction %d : profil %d manquant" % [faction, archetype])


func test_le_lourd_ne_recule_pas() -> void:
	var heavy := _enemy(EnemyCatalog.get_enemy(&"raider_brute"), Vector2(100, 100))
	heavy.state = Enemy.State.CHASE
	heavy.take_hit(1, Vector2(90, 100))
	assert_true(heavy.state == Enemy.State.CHASE, "il continue d'avancer")
	assert_true(heavy.health.health == heavy.data.max_health - 1, "mais il prend le coup")


func test_le_tireur_garde_ses_distances_et_tire() -> void:
	var sniper_data: EnemyData = EnemyCatalog.get_enemy(&"raider_marksman")
	var player := _player(Vector2(130, 100))
	var sniper := _enemy(sniper_data, Vector2(100, 100))
	sniper.target = player
	sniper.state = Enemy.State.CHASE
	_think(sniper, 0.05)
	assert_true(sniper.velocity.x < 0.0, "trop près : il recule")
	player.position = Vector2(200, 100)
	_think(sniper, 0.05)
	assert_true(sniper.state == Enemy.State.WINDUP, "à bonne distance : il vise")
	var shots: Array[Projectile] = []
	sniper.shot_fired.connect(func(_e: Enemy, p: Projectile) -> void: shots.append(p))
	_think(sniper, sniper_data.windup + 0.05)
	assert_true(shots.size() == 1, "il tire")
	assert_true(shots[0].direction.x > 0.9, "vers le joueur")
	for shot: Projectile in shots:
		shot.free()


func test_un_projectile_touche_ce_qui_est_sur_sa_route() -> void:
	assert_true(Projectile.segment_hits(Vector2(0, 0), Vector2(20, 0), Vector2(10, 5), 7.0), "sur la route")
	assert_false(Projectile.segment_hits(Vector2(0, 0), Vector2(20, 0), Vector2(10, 12), 7.0), "à côté")


func test_le_rampant_plaque_et_il_faut_marteler() -> void:
	var crawler_data: EnemyData = EnemyCatalog.get_enemy(&"infected_crawler")
	var player := _player(Vector2(110, 100))
	var crawler := _enemy(crawler_data, Vector2(100, 100))
	crawler.target = player
	crawler.state = Enemy.State.CHASE
	var grabs: Array[int] = [0]
	var bites: Array[int] = [0]
	crawler.grabbed.connect(func(e: Enemy) -> void:
		grabs[0] += 1
		player.pin(e, e.data.mash_needed))
	crawler.attack_landed.connect(func(_e: Enemy) -> void: bites[0] += 1)
	_think(crawler, crawler_data.windup + 0.1)
	assert_true(grabs[0] == 1 and crawler.is_grabbing() and player.is_pinned(), "plaqué au sol")
	_think(crawler, crawler_data.grab_tick * 2.0 + 0.05)
	assert_true(bites[0] >= 3, "il mord tant qu'il tient (%d)" % bites[0])
	player.freed.connect(func(by: Node2D) -> void: (by as Enemy).release_grab())
	for i: int in crawler_data.mash_needed:
		player.mash()
	assert_false(player.is_pinned(), "dégagé à force de marteler")
	assert_true(crawler.state == Enemy.State.STUNNED, "le rampant est sonné")


func test_la_zone_place_les_ennemis_et_les_branche() -> void:
	GameState.new_run(5)
	var zone := (load("res://levels/stop_zone/stop_zone.tscn") as PackedScene).instantiate()
	zone.set(&"zone_override", preload("res://data/zones/blight.tres"))
	zone.set(&"seed_override", 99)
	_add(zone)
	var enemies: Array[Node] = tree.get_nodes_in_group(Enemy.GROUP)
	assert_true(enemies.size() >= 1, "des infectés dans les terres contaminées")
	var player: Player = zone.get_node("World/Player")
	assert_true((enemies[0] as Enemy).target == player, "ils chassent le joueur")
	# Un coup d'infecté : dégâts et exposition.
	zone.call(&"_on_enemy_attack", enemies[0])
	assert_true(player.health.health == player.health.max_health - 1, "1 dégât")
	assert_true(player.exposure.value > 0.0, "un peu d'exposition")
	GameState.new_run()
