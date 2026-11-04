extends TestCase
## Règles d'un arrêt : sifflet, départ, montée à bord, butin et exposition.

const SCRAP: LootData = preload("res://data/loot/scrap.tres")

var _session: StopSession
var _whistles: int = 0
var _ends: Array[ExpeditionResult] = []


func before_each() -> void:
	_session = StopSession.new()
	_session.duration = 60.0
	_session.whistle_time = 15.0
	tree.root.add_child(_session)
	_session.set_process(false) # le temps n'avance que via tick()
	_session.whistle_blown.connect(func() -> void: _whistles += 1)
	_session.ended.connect(func(result: ExpeditionResult) -> void: _ends.append(result))


func after_each() -> void:
	_session.free()


func test_le_sifflet_retentit_une_seule_fois_au_bon_moment() -> void:
	_session.tick(44.0)
	assert_true(_whistles == 0, "pas de sifflet à 16 s du départ")
	_session.tick(1.0)
	assert_true(_whistles == 1, "sifflet à 15 s du départ")
	_session.tick(5.0)
	assert_true(_whistles == 1, "le sifflet ne se répète pas")


func test_le_train_part_sans_le_joueur_a_la_fin_du_temps() -> void:
	_session.tick(61.0)
	assert_true(_ends.size() == 1, "la sortie se termine une fois")
	assert_false(_ends[0].boarded, "le joueur n'est pas à bord")
	assert_false(_session.is_running(), "la session est finie")


func test_monter_a_bord_termine_la_sortie() -> void:
	_session.tick(10.0)
	_session.board()
	_session.tick(100.0)
	assert_true(_ends.size() == 1, "une seule fin, même si le temps continue")
	assert_true(_ends[0].boarded, "le joueur est à bord")


func test_le_butin_est_compte_puis_fige_a_la_fin() -> void:
	_session.add_loot(SCRAP, 3)
	_session.add_loot(SCRAP, 2)
	_session.board()
	_session.add_loot(SCRAP, 10)
	assert_true(_session.result.get_amount(&"scrap") == 5, "5 ferrailles, obtenu %d" % _session.result.get_amount(&"scrap"))


func test_l_exposition_du_joueur_est_recopiee_dans_le_resultat() -> void:
	var exposure := ExposureComponent.new()
	exposure.add(0.35)
	_session.exposure_source = exposure
	_session.board()
	assert_almost(_ends[0].exposure, 0.35, "exposition du résultat")
	exposure.free()


func test_l_infection_prise_pendant_la_sortie() -> void:
	var result := ExpeditionResult.new()
	result.exposure_start = 0.4
	result.exposure = 0.55
	assert_almost(result.exposure_gained(), 0.15, "15 points pris pendant la sortie")
	result.exposure = 0.3
	assert_almost(result.exposure_gained(), 0.0, "jamais négatif")
