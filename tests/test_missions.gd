extends TestCase
## Missions d'équipage (grade Capitaine) : un équipier descend seul à l'arrêt choisi,
## l'arrêt est simulé (butin, blessures, infection, fatigue), puis le train repart.

const ROUTE_MENU = preload("res://ui/route/route_menu.gd")
const HOSPITAL: ZoneProfile = preload("res://data/zones/hospital.tres")
const MILITARY: ZoneProfile = preload("res://data/zones/military_camp.tres")

var _nodes: Array[Node] = []


func before_each() -> void:
	GameState.new_run(91)


func after_each() -> void:
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	GameState.new_run()


func _member(role: StringName = &"mechanic") -> CrewMember:
	return CrewMember.create("Lou", role, "Mécanicien", false, 50)


func _rng(seed_value: int = 5) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _total(loot: Dictionary[StringName, int]) -> int:
	var sum: int = 0
	for id: StringName in loot:
		sum += loot[id]
	return sum


func _make_captain() -> void:
	GameState.merit = Career.GRADES[Career.AUTHORITY[&"missions"]].merit_needed


func _go_to_route_choice() -> void:
	while GameState.route_options.size() < 2:
		GameState.prepare_next_stop()


func test_la_mission_rapporte_un_butin_fatigue_et_donne_confiance() -> void:
	var member := _member()
	var result: MissionSim.Result = MissionSim.run(member, HOSPITAL, 4, _rng())
	assert_false(result.died, "revient")
	assert_true(_total(result.loot) > 0 and _total(result.loot) <= MissionSim.BAG, "un sac, pas plus")
	assert_true(member.fatigue == MissionSim.FATIGUE, "fatigué")
	assert_true(member.trust == 50 + MissionSim.TRUST_GAIN, "on lui a fait confiance")
	assert_true(result.lines[0].begins_with("Lou revient de"), "récit")


func test_l_eclaireur_rapporte_plus_et_se_blesse_moins() -> void:
	var scout := _member(&"scout")
	var other := _member()
	var a: MissionSim.Result = MissionSim.run(scout, MILITARY, 10, _rng(8))
	var b: MissionSim.Result = MissionSim.run(other, MILITARY, 10, _rng(8))
	assert_true(_total(a.loot) >= _total(b.loot), "éclaireur : plus de butin")
	assert_true(scout.health >= other.health, "éclaireur : moins de blessures")


func test_un_equipier_trop_faible_peut_ne_pas_revenir() -> void:
	var member := _member()
	member.health = 1
	var result: MissionSim.Result = MissionSim.run(member, MILITARY, 15, _rng())
	assert_true(result.died, "mort")
	assert_true(result.loot.is_empty(), "rien ne revient")
	assert_true("ne revient pas" in result.lines[0], "dit au trajet")


func test_un_equipier_epuise_ou_en_quarantaine_ne_part_pas() -> void:
	var member := _member()
	assert_true(MissionSim.can_go(member), "en état")
	member.quarantined = true
	assert_false(MissionSim.can_go(member), "en quarantaine")


func test_la_mission_range_le_butin_avance_l_heure_et_garde_le_recit() -> void:
	_make_captain()
	_go_to_route_choice()
	var member := _member()
	GameState.crew.append(member)
	var before: int = GameState.storage_total()
	var clock: int = GameState.clock_minutes
	var result: MissionSim.Result = GameState.run_mission(member)
	assert_true(GameState.storage_total() == before + _total(result.loot), "butin au stock")
	assert_true(GameState.clock_minutes == clock + GameState.MISSION_MINUTES, "l'heure avance")
	GameState.prepare_next_stop()
	assert_false(GameState.last_mission_lines.is_empty(), "le récit attend le trajet")


func test_un_mort_en_mission_quitte_l_equipage_et_inquiete_les_autres() -> void:
	_make_captain()
	_go_to_route_choice()
	var member := _member()
	member.health = 1
	var witness := _member()
	GameState.crew.append(member)
	GameState.crew.append(witness)
	GameState.current_zone = MILITARY
	GameState.stop_number = 15
	GameState.run_mission(member)
	assert_false(member in GameState.crew, "parti")
	assert_true(witness.trust == 50 + CrewLife.TRUST_LOSS, "les autres perdent confiance")


func test_seul_le_capitaine_peut_envoyer_un_equipier() -> void:
	_go_to_route_choice()
	GameState.route_by_captain = false
	GameState.crew.append(_member())
	var menu: CanvasLayer = ROUTE_MENU.new()
	tree.root.add_child(menu)
	_nodes.append(menu)
	menu.call(&"open")
	assert_false(_has_button(menu, "Envoyer un équipier"), "pas avant Capitaine")
	_make_captain()
	menu.call(&"open")
	assert_true(_has_button(menu, "Envoyer un équipier"), "Capitaine : il peut")
	var sent: Array[CrewMember] = []
	menu.connect(&"mission_chosen", func(_index: int, who: CrewMember) -> void: sent.append(who))
	menu.call(&"_show_crew_for", 1)
	var send: Button = _find_button(menu, "Envoyer")
	assert_true(send != null, "liste des équipiers")
	send.pressed.emit()
	assert_true(sent.size() == 1, "équipier envoyé")
	assert_true(GameState.current_zone == GameState.route_options[1].zone, "sur la voie choisie")


func _has_button(root: Node, text: String) -> bool:
	return _find_button(root, text) != null


func _find_button(root: Node, text: String) -> Button:
	for child: Node in root.find_children("*", "Button", true, false):
		if (child as Button).text == text:
			return child as Button
	return null
