extends TestCase
## Équipier de sortie : on le choisit à bord (Caporal), il descend avec toi à chaque
## arrêt, fouille de son côté sans qu'on le voie, et rapporte sa part en remontant.

const SCRAPYARD: ZoneProfile = preload("res://data/zones/scrapyard.tres")
const STOP_ZONE: PackedScene = preload("res://levels/stop_zone/stop_zone.tscn")
const RESULT: PackedScene = preload("res://ui/result/result_screen.tscn")

var _nodes: Array[Node] = []


func before_each() -> void:
	GameState.new_run(6)


func after_each() -> void:
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	GameState.new_run()


func _caporal() -> void:
	GameState.merit = Career.GRADES[Career.AUTHORITY[&"companion"]].merit_needed


func _member(member_name: String = "Sacha") -> CrewMember:
	var member := CrewMember.create(member_name, &"scout", "repérage", false, 60)
	GameState.crew.append(member)
	return member


func _rng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng


func _total(loot: Dictionary) -> int:
	var total: int = 0
	for amount: int in loot.values():
		total += amount
	return total


func test_il_faut_etre_caporal_pour_emmener_un_equipier() -> void:
	var sacha := _member()
	GameState.set_companion(sacha)
	assert_true(GameState.companion == null, "recrue : on sort seul")
	_caporal()
	GameState.set_companion(sacha)
	assert_true(GameState.companion == sacha, "caporal : Sacha t'accompagne")
	assert_true(GameState.companion_for_stop() == sacha, "il sort au prochain arrêt")


func test_un_equipier_epuise_reste_a_bord() -> void:
	_caporal()
	var sacha := _member()
	GameState.set_companion(sacha)
	sacha.fatigue = 95
	assert_true(GameState.companion_for_stop() == null, "trop fatigué pour sortir")
	assert_true(GameState.companion_problem().contains("reste à bord"), "on dit pourquoi")


func test_plus_on_reste_dehors_plus_il_rapporte() -> void:
	var short: int = 0
	var long: int = 0
	for i: int in 30:
		short += _total(MissionSim.run_companion(CrewMember.create("A", &"scout", "repérage", false), SCRAPYARD, 4, _rng(i), 0.25).loot)
		long += _total(MissionSim.run_companion(CrewMember.create("A", &"scout", "repérage", false), SCRAPYARD, 4, _rng(i), 1.0).loot)
	assert_true(long > short * 2, "tout l'arrêt : bien plus qu'un quart (%d contre %d)" % [long, short])


func test_un_sac_lui_fait_rapporter_plus() -> void:
	var bare: int = 0
	var bagged: int = 0
	for i: int in 20:
		bare += _total(MissionSim.run_companion(CrewMember.create("A", &"scout", "repérage", false), SCRAPYARD, 4, _rng(i), 1.0).loot)
		var member := CrewMember.create("A", &"scout", "repérage", false)
		member.loadout.equip(preload("res://data/items/bag_hiking.tres"))
		bagged += _total(MissionSim.run_companion(member, SCRAPYARD, 4, _rng(i), 1.0).loot)
	assert_true(bagged > bare, "sans sac il plafonne à 10 objets ; avec, il en rapporte plus (%d contre %d)" % [bagged, bare])


func test_il_rapporte_moins_qu_en_mission_et_risque_moins() -> void:
	var partner: int = 0
	var mission: int = 0
	var partner_wounds: int = 0
	var mission_wounds: int = 0
	# Un grand sac pour les deux : sinon les deux le remplissent (10 objets) dans une zone riche.
	var big_bag: ItemData = preload("res://data/items/bag_military.tres")
	for i: int in 30:
		var partner_member := CrewMember.create("A", &"scout", "repérage", false)
		partner_member.loadout.equip(big_bag)
		var mission_member := CrewMember.create("B", &"scout", "repérage", false)
		mission_member.loadout.equip(big_bag)
		var a := MissionSim.run_companion(partner_member, SCRAPYARD, 8, _rng(i), 1.0)
		var b := MissionSim.run(mission_member, SCRAPYARD, 8, _rng(i))
		partner += _total(a.loot)
		mission += _total(b.loot)
		partner_wounds += a.wounds
		mission_wounds += b.wounds
	assert_true(partner < mission, "sa part est plus petite qu'une mission")
	assert_true(partner_wounds < mission_wounds, "et il se blesse moins (tu attires les ennemis)")


func test_en_remontant_sa_part_rejoint_le_stock() -> void:
	_caporal()
	var sacha := _member()
	GameState.set_companion(sacha)
	GameState.current_zone = SCRAPYARD
	GameState.storage.clear()
	var result := ExpeditionResult.new()
	result.boarded = true
	result.companion = sacha
	var fatigue: int = sacha.fatigue
	GameState.record_expedition(result)
	assert_false(result.companion_lines.is_empty(), "le bilan raconte son retour")
	assert_true(_total(result.companion_loot) > 0, "il rapporte quelque chose de la casse")
	for id: StringName in result.companion_loot:
		assert_true(GameState.storage_amount(id) == result.companion_loot[id], "%s rangé au stock" % id)
	assert_true(sacha.fatigue > fatigue, "la sortie le fatigue")


func test_il_peut_ne_pas_revenir() -> void:
	_caporal()
	var sacha := _member()
	sacha.health = 1
	sacha.nerve = 1
	GameState.set_companion(sacha)
	GameState.current_zone = preload("res://data/zones/military_camp.tres")
	GameState.stop_number = 18
	var result := ExpeditionResult.new()
	result.boarded = true
	result.companion = sacha
	GameState.record_expedition(result)
	assert_true(result.companion_died, "à 1 PV dans un camp militaire, il ne revient pas")
	assert_false(sacha in GameState.crew, "il n'est plus à bord")
	assert_true(GameState.companion == null, "plus d'équipier de sortie")


func test_l_equipier_de_sortie_est_sauvegarde() -> void:
	_caporal()
	_member("Léa")
	var sacha := _member()
	GameState.set_companion(sacha)
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_save()))
	GameState.new_run(2)
	assert_true(GameState.load_save(data), "relue")
	assert_true(GameState.companion != null and GameState.companion.display_name == "Sacha", "Sacha est toujours ton équipier de sortie")


func test_la_session_compte_le_temps_passe_dehors() -> void:
	var session := StopSession.new()
	session.start(100.0)
	session.tick(25.0)
	session.board()
	assert_true(is_equal_approx(session.result.time_share, 0.25), "un quart de l'arrêt")
	session.free()


func test_a_l_arret_il_part_de_son_cote() -> void:
	_caporal()
	var sacha := _member()
	GameState.set_companion(sacha)
	var zone: Node = STOP_ZONE.instantiate()
	tree.root.add_child(zone)
	_nodes.append(zone)
	var session: StopSession = zone.get_node("StopSession")
	assert_true(session.result.companion == sacha, "Sacha est parti fouiller (hors de vue)")


func test_le_bilan_montre_ce_qu_il_rapporte() -> void:
	var sacha := _member()
	var result := ExpeditionResult.new()
	result.boarded = true
	result.companion = sacha
	result.companion_loot = {&"scrap": 3} as Dictionary[StringName, int]
	result.companion_lines = ["Sacha te rejoint au train."] as Array[String]
	var screen: Node = RESULT.instantiate()
	tree.root.add_child(screen)
	_nodes.append(screen)
	screen.call(&"show_result", result, GameState.LOOT_TYPES)
	var list: Node = screen.get_node("%LootList")
	var texts: Array = list.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	assert_true(texts.has("Sacha rapporte"), "sa ligne dans le bilan")
	assert_true(list.find_children("*", "SlotCell", true, false).size() >= 2, "son portrait et sa ferraille en cases")
