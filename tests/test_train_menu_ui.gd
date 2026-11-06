extends TestCase
## Menu du train en cases : une case par chose, la barre du bas explique et agit.
## Journal des machines, médicament choisi, icônes des voitures et des plans.

const TRAIN_MENU: PackedScene = preload("res://ui/train/train_menu.tscn")
const TrainMenu = preload("res://ui/train/train_menu.gd")
const PADDED: ItemData = preload("res://data/items/outfit_padded.tres")
const CHEM_KIT: ItemData = preload("res://data/items/tool_chem_kit.tres")
const GREENHOUSE: WagonData = preload("res://data/wagons/greenhouse.tres")
const LABORATORY: WagonData = preload("res://data/wagons/laboratory.tres")
const ANTISEPTIC: LootData = preload("res://data/loot/antiseptic.tres")
const ANTIBIOTICS: LootData = preload("res://data/loot/antibiotics.tres")

var _menu: CanvasLayer


func before_each() -> void:
	GameState.new_run(21)


func after_each() -> void:
	if is_instance_valid(_menu):
		_menu.free()
	GameState.new_run()


func _open(tab: TrainMenu.Tab) -> void:
	_menu = TRAIN_MENU.instantiate()
	tree.root.add_child(_menu)
	_menu.call(&"open", tab)


func _cells(list_name: String) -> Array[SlotCell]:
	var cells: Array[SlotCell] = []
	for node: Node in _menu.get_node(list_name).find_children("*", "SlotCell", true, false):
		cells.append(node as SlotCell)
	return cells


func _detail_button(text: String) -> Button:
	for node: Node in _menu.get_node("%Detail").find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node as Button
	return null


func _detail_has_text(text: String) -> bool:
	for node: Node in _menu.get_node("%Detail").find_children("*", "Label", true, false):
		if (node as Label).text.contains(text):
			return true
	return false


# --- Cases ------------------------------------------------------------------------

func test_le_stock_montre_une_case_par_ressource() -> void:
	GameState.storage[&"wood"] = 7
	_open(TrainMenu.Tab.STOCK)
	var cells := _cells("%StockList")
	assert_true(cells.size() == GameState.LOOT_TYPES.size(), "une case par ressource (obtenu %d)" % cells.size())
	var selected: Array[SlotCell] = cells.filter(func(cell: SlotCell) -> bool: return cell.is_selected())
	assert_true(selected.size() == 1, "une seule case choisie")
	var wood: LootData = MenuKit.loot(&"wood")
	_menu.call(&"_select", TrainMenu.Tab.STOCK, wood)
	assert_true(_detail_has_text("Bois ×7"), "la barre du bas explique la case choisie")


func test_l_atelier_fabrique_depuis_la_barre_du_bas() -> void:
	for id: StringName in PADDED.recipe:
		GameState.storage[id] = PADDED.recipe[id]
	_open(TrainMenu.Tab.WORKSHOP)
	_menu.call(&"_select", TrainMenu.Tab.WORKSHOP, PADDED)
	var craft := _detail_button("Fabriquer")
	assert_true(craft != null and not craft.disabled, "Fabriquer est prêt")
	craft.pressed.emit()
	assert_true(PADDED in GameState.owned_items, "la veste est fabriquée")


func test_une_recette_inconnue_est_un_cadenas_qui_dit_quel_plan_etudier() -> void:
	assert_false(GameState.is_known(CHEM_KIT.plan), "le kit de chimie demande un plan")
	_open(TrainMenu.Tab.WORKSHOP)
	var locked: Array[SlotCell] = _cells("%WorkshopList").filter(func(cell: SlotCell) -> bool: return cell.key == CHEM_KIT)
	assert_true(locked.size() == 1, "le kit a sa case")
	_menu.call(&"_select", TrainMenu.Tab.WORKSHOP, CHEM_KIT)
	assert_true(_detail_has_text("Recette inconnue"), "pas de recette tant que le plan n'est pas étudié")
	assert_true(_detail_has_text(BlueprintCatalog.get_plan(CHEM_KIT.plan).display_name), "le plan à étudier est nommé")
	assert_true(_detail_button("Fabriquer") == null, "rien à fabriquer")


func test_le_train_s_ouvre_sur_la_cabine_et_construit_d_en_bas() -> void:
	GameState.merit = Career.GRADES[Career.AUTHORITY[&"build"]].merit_needed
	var stock: WagonData = GameState.BUILDABLE_WAGONS.filter(func(w: WagonData) -> bool: return w.id == &"stock")[0]
	for id: StringName in stock.cost:
		GameState.storage[id] = stock.cost[id]
	_open(TrainMenu.Tab.TRAIN)
	assert_true(_detail_has_text("locomotive"), "la cabine (locomotive, état du train) est choisie d'office")
	var before: int = GameState.train.size()
	_menu.call(&"_select", TrainMenu.Tab.TRAIN, &"build:stock")
	var build := _detail_button("Construire")
	assert_true(build != null and not build.disabled, "Construire est prêt")
	build.pressed.emit()
	assert_true(GameState.train.size() == before + 1, "une voiture de plus")


func test_l_infirmerie_donne_le_medicament_choisi_au_patient_choisi() -> void:
	GameState.merit = Career.GRADES[Career.AUTHORITY[&"crew"]].merit_needed
	var iris := CrewMember.create("Iris", &"medic", "soins", true)
	iris.infection = 50
	iris.infection_known = true
	GameState.crew.append(iris)
	GameState.storage[ANTISEPTIC.id] = 1
	GameState.storage[ANTIBIOTICS.id] = 1
	_open(TrainMenu.Tab.INFIRMARY)
	_menu.call(&"_set_patient", iris)
	_menu.call(&"_select", TrainMenu.Tab.INFIRMARY, ANTIBIOTICS)
	var give := _detail_button("Donner à Iris")
	assert_true(give != null and not give.disabled, "on peut donner à Iris")
	give.pressed.emit()
	assert_true(GameState.storage_amount(ANTIBIOTICS.id) == 0, "les antibiotiques sont donnés")
	assert_true(GameState.storage_amount(ANTISEPTIC.id) == 1, "pas l'antiseptique (le plus faible)")
	assert_true(iris.infection == 50 - roundi(ANTIBIOTICS.cure * 100.0), "son infection baisse d'autant")


# --- Machines ------------------------------------------------------------------------

func test_le_journal_des_machines_garde_les_derniers_trajets() -> void:
	GameState.train.insert(0, GREENHOUSE)
	GameState.train.insert(0, LABORATORY)
	GameState.storage[&"infected_herb"] = 2
	for i: int in 7:
		GameState.prepare_next_stop()
	var log: Array[Dictionary] = GameState.production_log
	assert_true(log.size() == GameState.PRODUCTION_LOG_SIZE, "les %d derniers trajets" % GameState.PRODUCTION_LOG_SIZE)
	assert_true(int(log[0]["stop"]) == GameState.stop_number, "le plus récent d'abord")
	assert_true((log[0]["produced"] as Dictionary).get(&"herb", 0) == 2, "la serre a donné 2 plantes")
	assert_true(str(log[0]["note"]).contains("il manque"), "le labo n'avait plus de plantes infectées")
	var oldest: Dictionary = log[log.size() - 1]
	assert_true(int(oldest["stop"]) == GameState.stop_number - 4, "5 trajets, pas plus")


func test_au_tout_premier_trajet_le_labo_consomme_et_on_le_note() -> void:
	GameState.train.insert(0, LABORATORY)
	GameState.storage[&"infected_herb"] = 2
	GameState.prepare_next_stop()
	assert_true(GameState.last_consumed.get(&"infected_herb", 0) == 2, "2 plantes infectées consommées")
	assert_true(GameState.storage_amount(&"infected_herb") == 0, "prises dans le stock")
	assert_true(GameState.machine_runs_left(LABORATORY) == 0, "plus de quoi tourner")
	assert_true(GameState.machine_problem(LABORATORY).contains("il manque"), "le menu dira pourquoi")


func test_le_train_abime_arrete_les_machines_et_le_journal_le_dit() -> void:
	GameState.train.insert(0, GREENHOUSE)
	GameState.prepare_next_stop()
	GameState.train_condition = 0.3
	GameState.prepare_next_stop()
	assert_true((GameState.production_log[0]["produced"] as Dictionary).is_empty(), "rien produit")
	assert_true(str(GameState.production_log[0]["note"]).contains("abîmé"), "la raison est notée")


func test_le_journal_des_machines_est_sauvegarde() -> void:
	GameState.train.insert(0, GREENHOUSE)
	for i: int in 3:
		GameState.prepare_next_stop()
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_save()))
	GameState.new_run(2)
	assert_true(GameState.load_save(data), "relue")
	assert_true(GameState.production_log.size() == 3, "trois trajets dans le journal")
	assert_true((GameState.production_log[0]["produced"] as Dictionary).get(&"herb", 0) == 2, "avec ce qu'ils ont produit")


# --- Icônes ------------------------------------------------------------------------

func test_chaque_voiture_a_son_icone() -> void:
	for wagon: WagonData in GameState.WAGON_TYPES:
		assert_true(wagon.icon != null, "%s a une icône" % wagon.display_name)


func test_chaque_plan_montre_ce_qu_il_debloque() -> void:
	for plan: BlueprintData in BlueprintCatalog.ALL:
		assert_true(BlueprintCatalog.icon(plan.id) != null, "%s a une icône" % plan.display_name)
	assert_true(BlueprintCatalog.icon(&"horticulture") == GREENHOUSE.icon, "Horticulture : la serre")
	assert_true(BlueprintCatalog.icon(&"intercom") == BlueprintCatalog.PLAN_ICON, "Interphone : rien à montrer, un plan")
