extends TestCase
## Rencontres : payer, recevoir, recruter, et l'équipage qui monte à bord.

var _rng: RandomNumberGenerator


func before_each() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = 99
	GameState.new_run(1)


func after_each() -> void:
	GameState.new_run()


func _choice(cost: Dictionary, reward: Dictionary) -> EncounterChoice:
	var choice := EncounterChoice.new()
	for id: StringName in cost:
		choice.cost[id] = cost[id]
	for id: StringName in reward:
		choice.reward[id] = reward[id]
	return choice


func _carrying(loot: Dictionary) -> ExpeditionResult:
	var result := ExpeditionResult.new()
	for id: StringName in loot:
		result.add_loot(id, loot[id])
	return result


func test_un_echange_retire_le_cout_et_donne_le_gain() -> void:
	var result := _carrying({&"scrap": 5})
	var outcome := EncounterResolver.apply(_choice({&"scrap": 3}, {&"herb": 2}), result, _rng)
	assert_true(result.get_amount(&"scrap") == 2, "5 - 3 ferrailles")
	assert_true(result.get_amount(&"herb") == 2, "+2 plantes")
	assert_true(outcome.gained.get(&"herb", 0) == 2, "le gain est annoncé")


func test_on_ne_peut_pas_payer_ce_qu_on_n_a_pas() -> void:
	var result := _carrying({&"scrap": 1})
	var choice := _choice({&"scrap": 3}, {&"herb": 2})
	assert_false(EncounterResolver.can_afford(choice, result), "pas assez de ferraille")
	assert_true(EncounterResolver.missing(choice, result).get(&"scrap", 0) == 2, "il manque 2 ferrailles")


func test_tout_depenser_vide_la_ligne_du_butin() -> void:
	var result := _carrying({&"wood": 2})
	EncounterResolver.apply(_choice({&"wood": 2}, {}), result, _rng)
	assert_false(result.loot.has(&"wood"), "plus de bois du tout")


func test_le_gain_aleatoire_reste_dans_sa_fourchette() -> void:
	var choice := EncounterChoice.new()
	choice.random_reward_pool = [&"scrap", &"herb"]
	choice.random_reward_amount = Vector2i(2, 4)
	for i: int in 20:
		var result := ExpeditionResult.new()
		EncounterResolver.apply(choice, result, _rng)
		var total: int = result.total_items()
		assert_true(total >= 2 and total <= 4, "gain aléatoire de %d" % total)


func test_recruter_ajoute_une_recrue_nommee_a_la_sortie() -> void:
	var choice := EncounterChoice.new()
	choice.recruit_role = &"mechanic"
	choice.recruit_role_label = "mécanique"
	choice.outcome_text = "{nom} te suit."
	var result := ExpeditionResult.new()
	var outcome := EncounterResolver.apply(choice, result, _rng)
	assert_true(result.recruits.size() == 1, "une recrue")
	assert_true(outcome.recruit.display_name in EncounterResolver.NAMES, "prénom de la liste")
	assert_true(outcome.text == "%s te suit." % outcome.recruit.display_name, "le prénom remplace {nom}")


func test_pas_deux_recrues_du_meme_nom() -> void:
	var choice := EncounterChoice.new()
	choice.recruit_role = &"scout"
	var taken: Array[String] = []
	for i: int in EncounterResolver.NAMES.size():
		var outcome := EncounterResolver.apply(choice, ExpeditionResult.new(), _rng, taken)
		assert_false(outcome.recruit.display_name in taken, "%s déjà pris" % outcome.recruit.display_name)
		taken.append(outcome.recruit.display_name)


func test_l_infection_cachee_suit_sa_probabilite() -> void:
	var always := EncounterChoice.new()
	always.recruit_role = &"scout"
	always.recruit_infection_chance = 1.0
	var never := EncounterChoice.new()
	never.recruit_role = &"scout"
	never.recruit_infection_chance = 0.0
	assert_true(EncounterResolver.apply(always, ExpeditionResult.new(), _rng).recruit.infected, "toujours infecté")
	assert_false(EncounterResolver.apply(never, ExpeditionResult.new(), _rng).recruit.infected, "jamais infecté")


func test_les_recrues_montent_a_bord_avec_le_joueur() -> void:
	var result := ExpeditionResult.new()
	result.recruits.append(CrewMember.create("Léa", &"mechanic", "mécanique", false))
	result.boarded = true
	GameState.record_expedition(result)
	assert_true(GameState.crew.size() == 1, "Léa rejoint l'équipage")


func test_rater_le_train_perd_aussi_les_recrues() -> void:
	var result := ExpeditionResult.new()
	result.recruits.append(CrewMember.create("Malik", &"scout", "repérage", false))
	result.boarded = false
	GameState.record_expedition(result)
	assert_true(GameState.crew.is_empty(), "personne ne monte")


func test_la_session_refuse_un_choix_impossible_ou_trop_tard() -> void:
	var session := StopSession.new()
	tree.root.add_child(session)
	session.set_process(false)
	session.start(60.0)
	var choice := _choice({&"scrap": 1}, {&"herb": 1})
	assert_true(session.resolve_choice(choice, _rng) == null, "rien à donner")
	session.add_loot(preload("res://data/loot/scrap.tres"), 1)
	assert_true(session.resolve_choice(choice, _rng) != null, "échange possible")
	session.add_loot(preload("res://data/loot/scrap.tres"), 1)
	session.board()
	assert_true(session.resolve_choice(choice, _rng) == null, "la sortie est finie")
	session.free()


func test_toutes_les_rencontres_du_catalogue_sont_valides() -> void:
	for pool_kind: StringName in EncounterLibrary.POOLS:
		for id: StringName in EncounterLibrary.POOLS[pool_kind]:
			var encounter := EncounterLibrary.get_encounter(id)
			assert_true(encounter != null, "rencontre %s introuvable" % id)
			if encounter == null:
				continue
			assert_false(encounter.choices.is_empty(), "%s sans choix" % id)
			var can_leave: bool = false
			for choice: EncounterChoice in encounter.choices:
				can_leave = can_leave or choice.leave
				for loot_id: StringName in choice.cost.keys() + choice.reward.keys() + choice.random_reward_pool:
					assert_true(_loot_exists(loot_id), "%s : ressource inconnue %s" % [id, loot_id])
			assert_true(can_leave, "%s : il faut toujours pouvoir partir" % id)


func _loot_exists(id: StringName) -> bool:
	for loot: LootData in GameState.LOOT_TYPES:
		if loot.id == id:
			return true
	return false
