extends TestCase
## Responsabilités par grade : avant le grade requis, le capitaine décide (voie, équipage,
## construction, dépôt) ; ensuite c'est le joueur.

const ROUTE_GRADE: int = 2


func before_each() -> void:
	GameState.new_run(57)


func after_each() -> void:
	GameState.new_run()


func _set_grade(permission: StringName) -> void:
	GameState.merit = Career.GRADES[Career.AUTHORITY[permission]].merit_needed


func test_chaque_responsabilite_a_son_grade() -> void:
	assert_true(Career.required_grade(&"recruit") == "Soldat", "recruter : Soldat")
	assert_true(Career.required_grade(&"route") == "Caporal", "la voie : Caporal")
	assert_true(Career.required_grade(&"crew") == "Sergent", "l'équipage : Sergent")
	assert_true(Career.required_grade(&"build") == "Lieutenant", "construire : Lieutenant")
	assert_true(Career.required_grade(&"missions") == "Capitaine", "missions : Capitaine")
	assert_false(GameState.can(&"route"), "une recrue ne choisit pas la voie")
	_set_grade(&"route")
	assert_true(GameState.can(&"route") and GameState.can(&"recruit") and not GameState.can(&"crew"), "caporal")


func test_avant_caporal_le_capitaine_choisit_la_voie_la_plus_sure() -> void:
	while GameState.stop_number < 7:
		GameState.prepare_next_stop()
	assert_true(GameState.route_by_captain, "le capitaine a choisi")
	assert_false(GameState.has_route_choice(), "pas de choix pour le joueur")
	var chosen: ZoneProfile = GameState.current_zone
	for option: Object in GameState.route_options:
		var zone: ZoneProfile = option.get(&"zone")
		assert_true(chosen.danger(GameState.stop_number) <= zone.danger(GameState.stop_number), "la voie la moins dangereuse")
	assert_true(GameState.captain_notes.any(func(note: String) -> bool: return "voie" in note), "dit au trajet")


func test_une_horde_reperee_detourne_le_capitaine() -> void:
	var options: Array = []
	for zone_id: String in ["bog", "reed_beds"]:
		var option := GameState.StopOption.new(load("res://data/zones/%s.tres" % zone_id), 1, null)
		options.append(option)
	var calm: int = CaptainDecisions.pick_route(options, 8)
	options[calm].horde_spotted = true
	assert_true(CaptainDecisions.pick_route(options, 8) != calm, "il évite la voie où attend une horde")


func test_caporal_le_joueur_choisit() -> void:
	_set_grade(&"route")
	while GameState.stop_number < 7:
		GameState.prepare_next_stop()
	assert_false(GameState.route_by_captain, "plus le capitaine")
	assert_true(GameState.has_route_choice(), "à toi de choisir")


func test_avant_sergent_le_capitaine_dirige_l_equipage() -> void:
	var tired := CrewMember.create("Léa", &"mechanic", "mécanique", false)
	tired.fatigue = 70
	var sick := CrewMember.create("Malik", &"scout", "repérage", true)
	sick.infection = 50
	sick.infection_known = true
	var crew: Array[CrewMember] = [tired, sick]
	var notes := CaptainDecisions.manage_crew(crew, true, 2)
	assert_true(tired.resting, "l'épuisée au repos")
	assert_true(sick.quarantined, "l'infecté à l'infirmerie")
	assert_true(notes.size() == 2, "deux décisions racontées")
	var no_infirmary := CrewMember.create("Iris", &"medic", "soins", true)
	no_infirmary.infection = 50
	no_infirmary.infection_known = true
	var alone: Array[CrewMember] = [no_infirmary]
	CaptainDecisions.manage_crew(alone, false, 2)
	assert_false(no_infirmary.quarantined, "sans infirmerie, pas de quarantaine")


func test_avant_lieutenant_le_capitaine_fait_construire() -> void:
	for i: int in GameState.beds():
		GameState.crew.append(CrewMember.create("Équipier %d" % i, &"scout", "repérage", false))
	for loot: LootData in GameState.LOOT_TYPES:
		if not loot.is_medicine():
			GameState.storage[loot.id] = 10
	var cars: int = GameState.train.size()
	var note: String = CaptainDecisions.build(GameState)
	assert_true(GameState.train.size() == cars + 1 and "dortoir" in note, "plus de couchette : un dortoir (« %s »)" % note)


func test_au_depot_le_capitaine_renforce_la_locomotive() -> void:
	for loot: LootData in GameState.LOOT_TYPES:
		GameState.storage[loot.id] = 10
	var note: String = CaptainDecisions.depot(GameState)
	assert_true(GameState.locomotive_level == 2 and not note.is_empty(), "locomotive renforcée")


func test_le_trajet_applique_les_decisions_du_capitaine() -> void:
	var tired := CrewMember.create("Léa", &"mechanic", "mécanique", false)
	tired.fatigue = 75
	GameState.crew.append(tired)
	GameState.prepare_next_stop()
	assert_true(GameState.captain_notes.any(func(note: String) -> bool: return "repos" in note), "mise au repos racontée")
	_set_grade(&"crew")
	tired.fatigue = 75
	GameState.prepare_next_stop()
	assert_false(GameState.captain_notes.any(func(note: String) -> bool: return "repos" in note), "sergent : c'est toi qui décides")


func test_une_recrue_ne_recrute_pas_en_sortie() -> void:
	var choice := EncounterChoice.new()
	choice.recruit_role = &"scout"
	var lacking := EncounterResolver.missing(choice, ExpeditionResult.new(), -1, 3, false)
	assert_true(lacking.has(EncounterResolver.NO_RANK), "il faut être Soldat")
	assert_true(EncounterResolver.missing(choice, ExpeditionResult.new(), -1, 3, true).is_empty(), "soldat : possible")


func test_la_progression_vers_le_grade_suivant() -> void:
	assert_true(is_equal_approx(Career.progress(0), 0.0), "Recrue sans mérite : 0")
	assert_true(is_equal_approx(Career.progress(12), 12.0 / 25.0), "12 / 25 avant Soldat")
	assert_true(is_equal_approx(Career.progress(25), 0.0), "Soldat tout juste : on repart de 0")
	assert_true(is_equal_approx(Career.progress(500), 1.0), "Capitaine : barre pleine")
	assert_true(Career.UNLOCKS.size() == Career.GRADES.size(), "un texte par grade")


func test_l_onglet_grade_montre_la_barre() -> void:
	GameState.new_run(2)
	GameState.merit = 12
	var list := VBoxContainer.new()
	tree.root.add_child(list)
	GradeView.fill(list)
	var bar := list.get_node("GradeProgress") as StageBar
	assert_true(bar != null and is_equal_approx(bar.value, 12.0 / 25.0), "barre à 12/25")
	list.free()
