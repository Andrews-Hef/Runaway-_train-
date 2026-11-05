extends TestCase
## Équipage vivant : travail et fatigue, infection cachée, contagion, quarantaine,
## ruche, mort, confiance (fidèle, méfiance, départ), demandes personnelles, soins.

const GameStateScript = preload("res://core/game_state.gd")


func before_each() -> void:
	GameState.new_run(33)


func after_each() -> void:
	GameState.new_run()


func _member(role: StringName = &"mechanic", infected: bool = false, trust: int = 50) -> CrewMember:
	return CrewMember.create("Léa", role, "rôle", infected, trust)


func _context(seed_value: int = 1) -> CrewLife.Context:
	var context := CrewLife.Context.new()
	context.rng = RandomNumberGenerator.new()
	context.rng.seed = seed_value
	return context


func _crew(members: Array) -> Array[CrewMember]:
	var crew: Array[CrewMember] = []
	for member: CrewMember in members:
		crew.append(member)
	return crew


# --- Travail et fatigue ----------------------------------------------------------------

func test_le_mecanicien_repare_et_se_fatigue() -> void:
	var mechanic := _member()
	var report := CrewLife.run_trajet(_crew([mechanic]), _context())
	assert_almost(report.repair, CrewLife.MECHANIC_REPAIR, "+10 % au train")
	assert_true(mechanic.fatigue == CrewLife.WORK_FATIGUE[&"mechanic"], "travailler fatigue")


func test_epuise_il_ne_travaille_plus_et_perd_confiance() -> void:
	var mechanic := _member()
	mechanic.fatigue = CrewLife.EXHAUSTED
	var report := CrewLife.run_trajet(_crew([mechanic]), _context())
	assert_true(report.repair == 0.0, "épuisé : pas de réparation")
	assert_true(mechanic.fatigue < CrewLife.EXHAUSTED, "il récupère en ne travaillant pas")


func test_le_repos_fait_mieux_recuperer() -> void:
	var tired := _member()
	tired.fatigue = 70
	tired.resting = true
	CrewLife.run_trajet(_crew([tired]), _context())
	assert_true(tired.fatigue == 70 - CrewLife.REST_RECOVERY - CrewLife.RESTING_BONUS, "au repos : %d" % tired.fatigue)
	assert_false(tired.resting, "le repos ne dure qu'un trajet")


func test_un_equipier_fidele_travaille_mieux() -> void:
	var loyal := _member(&"mechanic", false, 80)
	var report := CrewLife.run_trajet(_crew([loyal]), _context())
	assert_almost(report.repair, CrewLife.MECHANIC_REPAIR * CrewLife.LOYAL_BONUS, "+15 %")
	assert_true("fidèle" in CrewLife.status(loyal), "affiché « fidèle »")


# --- Infection --------------------------------------------------------------------------

func test_l_infection_est_cachee_puis_se_voit() -> void:
	var sick := _member(&"scout", true)
	assert_false(sick.infection_known, "cachée au recrutement")
	assert_true(sick.infection_text() == "?", "le joueur voit « ? »")
	var crew := _crew([sick])
	var seen: bool = false
	for i: int in 4:
		var report := CrewLife.run_trajet(crew, _context(i))
		for line: String in report.events:
			if "tousse" in line:
				seen = true
	assert_true(sick.infection_known and seen, "symptômes : on le sait (%d %%)" % sick.infection)


func test_un_soigneur_repere_les_infectes() -> void:
	var sick := _member(&"scout", true)
	var medic := CrewMember.create("Iris", &"medic", "soins", false)
	CrewLife.run_trajet(_crew([sick, medic]), _context())
	assert_true(sick.infection_known, "le soigneur l'a examiné")


func test_la_contagion_et_la_quarantaine() -> void:
	var infected_spreads: bool = false
	for seed_value: int in 40:
		var sick := _member(&"scout", true)
		var healthy := CrewMember.create("Paul", &"mechanic", "mécanique", false)
		CrewLife.run_trajet(_crew([sick, healthy]), _context(seed_value))
		if healthy.infection > 0:
			infected_spreads = true
			break
	assert_true(infected_spreads, "un malade non isolé finit par contaminer")
	for seed_value: int in 40:
		var isolated := _member(&"scout", true)
		isolated.quarantined = true
		var healthy := CrewMember.create("Paul", &"mechanic", "mécanique", false)
		CrewLife.run_trajet(_crew([isolated, healthy]), _context(seed_value))
		assert_true(healthy.infection == 0, "en quarantaine, il ne contamine personne")


func test_a_100_pour_cent_il_rejoint_la_ruche() -> void:
	var sick := _member(&"scout", true)
	sick.infection = 95
	var other := CrewMember.create("Paul", &"mechanic", "mécanique", false, 60)
	var crew := _crew([sick, other])
	var report := CrewLife.run_trajet(crew, _context())
	assert_true(sick in report.turned and not sick in crew, "parti dans la ruche")
	assert_almost(report.train_damage, CrewLife.TURN_TRAIN_DAMAGE, "une voiture saccagée")
	assert_true(other.trust < 60, "l'équipage est choqué")


func test_sans_vie_il_meurt() -> void:
	var sick := _member(&"scout", true)
	sick.infection = 75
	sick.health = 5
	var crew := _crew([sick])
	var report := CrewLife.run_trajet(crew, _context())
	assert_true(sick in report.dead and crew.is_empty(), "emporté par la maladie")


func test_travailler_jusqu_au_bout_epuise_et_blesse() -> void:
	var mechanic := _member()
	mechanic.fatigue = 79
	CrewLife.run_trajet(_crew([mechanic]), _context())
	assert_true(mechanic.health == 100 - CrewLife.COLLAPSE_DAMAGE, "il s'écroule (%d PV)" % mechanic.health)
	assert_true("épuisement" in CrewLife.status(mechanic), "épuisement affiché")


func test_la_horde_blesse_l_equipage_a_bord() -> void:
	var a := _member()
	var b := CrewMember.create("Paul", &"scout", "repérage", false)
	var context := _context()
	context.horde_damage = 0.25
	CrewLife.run_trajet(_crew([a, b]), context)
	assert_true(a.health + b.health < 200, "des blessés après l'attaque")


func test_un_equipier_mefiant_peut_quitter_le_train_en_gare() -> void:
	var left: int = 0
	for seed_value: int in 20:
		var wary := _member(&"scout", false, 10)
		var crew := _crew([wary])
		var context := _context(seed_value)
		context.to_refuge = true
		CrewLife.run_trajet(crew, context)
		if crew.is_empty():
			left += 1
	assert_true(left > 3 and left < 18, "environ la moitié des méfiants partent (%d/20)" % left)


# --- Demandes ---------------------------------------------------------------------------

func test_remplir_une_demande_donne_de_la_confiance() -> void:
	var member := _member()
	member.request_kind = &"deliver"
	member.request_target = &"parts"
	member.request_amount = 2
	member.request_left = CrewRequests.DURATION
	GameState.crew.append(member)
	assert_false(GameState.fulfil_request(member), "sans pièces : impossible")
	GameState.storage[&"parts"] = 3
	assert_true(GameState.fulfil_request(member), "pièces données")
	assert_true(member.trust == 50 + CrewRequests.TRUST_REWARD, "confiance +20")
	assert_true(GameState.storage_amount(&"parts") == 1 and not member.has_request(), "payé, demande remplie")


func test_une_demande_de_mission_se_remplit_au_retour() -> void:
	var scout := _member(&"scout")
	scout.request_kind = &"eliminate"
	scout.request_target = &"raider"
	scout.request_amount = 2
	scout.request_left = 3
	GameState.crew.append(scout)
	var result := ExpeditionResult.new()
	result.boarded = true
	result.kills[&"raider"] = 2
	GameState.record_expedition(result)
	assert_true(scout.trust == 50 + CrewRequests.TRUST_REWARD, "vengé : confiance +20")
	assert_true(result.crew_thanks.size() == 1, "remercié dans le bilan")


func test_une_demande_ignoree_decoit() -> void:
	var member := _member()
	CrewRequests.assign(member, RandomNumberGenerator.new())
	member.request_left = 1
	var events: Array[String] = []
	CrewRequests.tick(_crew([member]), RandomNumberGenerator.new(), events)
	assert_false(member.has_request(), "expirée")
	assert_true(member.trust == 50 + CrewRequests.TRUST_DISAPPOINTED, "déçu : confiance −5")


func test_les_demandes_suivent_le_role() -> void:
	var rng := RandomNumberGenerator.new()
	for i: int in 20:
		var scout := _member(&"scout")
		CrewRequests.assign(scout, rng)
		assert_true(scout.request_kind in [&"eliminate", &"bring"], "un éclaireur demande d'agir dehors")
		assert_false(CrewRequests.text(scout).is_empty(), "avec une phrase à lui")


# --- Soins et ordres ------------------------------------------------------------------

func test_panser_et_soigner() -> void:
	var member := _member(&"scout", true)
	member.health = 50
	GameState.crew.append(member)
	GameState.storage[&"cloth"] = 1
	assert_true(GameState.bandage(member), "pansé")
	assert_true(member.health == 80 and GameState.storage_amount(&"cloth") == 0, "+30 PV pour 1 tissu")
	GameState.storage[&"antiseptic"] = 1
	assert_true(GameState.medicate(member), "médicament donné")
	assert_true(member.infection_known and member.infection < CrewMember.HIDDEN_START, "infection soignée et connue")


func test_la_quarantaine_demande_une_infirmerie() -> void:
	var member := _member()
	GameState.crew.append(member)
	assert_false(GameState.toggle_quarantine(member), "pas d'infirmerie")
	GameState.train.insert(0, preload("res://data/wagons/infirmary.tres"))
	assert_true(GameState.toggle_quarantine(member) and member.quarantined, "isolé à l'infirmerie")


func test_l_eclaireur_repere_les_hordes_a_l_aiguillage() -> void:
	GameState.crew.append(_member(&"scout"))
	while GameState.stop_number < 7:
		GameState.prepare_next_stop()
	for option: Object in GameState.route_options:
		assert_true(option.get(&"scouted"), "voie guettée")
		var expected: bool = GameStateScript.roll_surprise((option.get(&"zone") as ZoneProfile).biome, GameState.stop_number,
			option.get(&"seed"), DayClock.is_night(GameState.clock_minutes)) != null
		assert_true(option.get(&"horde_spotted") == expected, "horde repérée = horde qui attend vraiment")


func test_l_equipage_se_sauvegarde() -> void:
	var member := _member(&"medic", true, 64)
	member.health = 42
	member.fatigue = 33
	member.resting = true
	CrewRequests.assign(member, RandomNumberGenerator.new())
	GameState.crew.append(member)
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_save()))
	GameState.new_run(2)
	assert_true(GameState.load_save(data), "relu")
	var back: CrewMember = GameState.crew[0]
	assert_true(back.health == 42 and back.fatigue == 33 and back.trust == 64 and back.resting, "jauges gardées")
	assert_true(back.infected and back.infection == CrewMember.HIDDEN_START, "infection gardée")
	assert_true(back.request_kind == member.request_kind and back.request_amount == member.request_amount, "demande gardée")
	var old := CrewMember.from_dict({"name": "Vieux", "role": "scout", "role_label": "repérage", "infected": false})
	assert_true(old.health == 100 and old.trust == 50, "ancienne sauvegarde : valeurs de départ")
