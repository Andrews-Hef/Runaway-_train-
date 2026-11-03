extends TestCase
## La partie en cours : arrêts successifs, stock du train, nouvelle partie.

func before_each() -> void:
	GameState.new_run(12345)


func after_each() -> void:
	GameState.new_run()


func _result(boarded: bool, scrap: int) -> ExpeditionResult:
	var result := ExpeditionResult.new()
	result.boarded = boarded
	result.add_loot(&"scrap", scrap)
	return result


func test_le_premier_arret_est_la_plaine() -> void:
	assert_true(GameState.stop_number == 1, "arrêt n°1")
	assert_true(GameState.current_zone == GameState.FIRST_ZONE, "première zone = plaine")


func test_le_butin_d_une_sortie_reussie_va_dans_le_train() -> void:
	GameState.record_expedition(_result(true, 3))
	GameState.record_expedition(_result(true, 2))
	assert_true(GameState.storage_amount(&"scrap") == 5, "5 ferrailles en stock")


func test_le_butin_d_un_train_rate_est_perdu() -> void:
	GameState.record_expedition(_result(false, 4))
	assert_true(GameState.storage_total() == 0, "rien en stock")


func test_chaque_arret_a_sa_propre_graine() -> void:
	var seeds: Array[int] = [GameState.current_seed]
	for i: int in 5:
		GameState.prepare_next_stop()
		assert_false(GameState.current_seed in seeds, "graine déjà vue à l'arrêt %d" % GameState.stop_number)
		seeds.append(GameState.current_seed)
	assert_true(GameState.stop_number == 6, "arrêt n°6")


func test_jamais_deux_fois_la_meme_zone_de_suite() -> void:
	var previous: ZoneProfile = GameState.current_zone
	for i: int in 30:
		GameState.prepare_next_stop()
		assert_true(GameState.current_zone != previous, "même zone deux fois de suite à l'arrêt %d" % GameState.stop_number)
		previous = GameState.current_zone


func test_une_meme_graine_de_partie_donne_le_meme_voyage() -> void:
	GameState.new_run(777)
	var first: Array[String] = []
	for i: int in 4:
		first.append("%s:%d" % [GameState.current_zone.id, GameState.current_seed])
		GameState.prepare_next_stop()
	GameState.new_run(777)
	for i: int in 4:
		assert_true(first[i] == "%s:%d" % [GameState.current_zone.id, GameState.current_seed], "arrêt %d identique" % (i + 1))
		GameState.prepare_next_stop()


func test_une_nouvelle_partie_vide_le_train() -> void:
	GameState.record_expedition(_result(true, 3))
	GameState.prepare_next_stop()
	GameState.new_run()
	assert_true(GameState.storage_total() == 0, "train vide")
	assert_true(GameState.stop_number == 1, "retour à l'arrêt n°1")
