extends TestCase
## Équipiers : prénom et nom, une des 20 apparences, quatre stats, un équipement de
## départ ; on les équipe depuis l'inventaire, à bord ; stats et équipement comptent
## en mission.

const PIPE: ItemData = preload("res://data/items/weapon_pipe.tres")
const MACHETE: ItemData = preload("res://data/items/weapon_machete.tres")
const KEVLAR: ItemData = preload("res://data/items/outfit_kevlar.tres")
const FILTER_MASK: ItemData = preload("res://data/items/mask_filter.tres")
const HIKING_BAG: ItemData = preload("res://data/items/bag_hiking.tres")
const CROWBAR: ItemData = preload("res://data/items/tool_crowbar.tres")

var _nodes: Array[Node] = []


func before_each() -> void:
	GameState.new_run(8)


func after_each() -> void:
	GameMenu.close()
	tree.paused = false
	tree.current_scene = null
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	GameState.new_run()


func _rng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng


func _recruit(seed_value: int = 3, role: StringName = &"mechanic") -> CrewMember:
	return CrewFactory.recruit(_rng(seed_value), role, "mécanique", false, 50, [] as Array[String])


func _bare(member_name: String = "Léa") -> CrewMember:
	var member := CrewMember.create(member_name, &"scout", "repérage", false)
	GameState.crew.append(member)
	return member


# --- Identité -------------------------------------------------------------------------

func test_une_recrue_a_un_nom_une_apparence_et_des_stats() -> void:
	var member := _recruit()
	assert_true(member.display_name in CrewNames.FIRST_NAMES, "un prénom de la liste")
	assert_false(member.surname.is_empty(), "et un nom")
	assert_true(member.full_name().begins_with(member.display_name + " "), "« Prénom Nom »")
	assert_true(member.look >= 1 and member.look <= CrewLooks.COUNT, "une des %d apparences" % CrewLooks.COUNT)
	for entry: Array in CrewMember.STATS:
		var value: int = member.stat(entry[0])
		assert_true(value >= 1 and value <= 5, "%s entre 1 et 5 (%d)" % [entry[1], value])


func test_meme_hasard_meme_recrue() -> void:
	var a := _recruit(42)
	var b := _recruit(42)
	assert_true(a.full_name() == b.full_name() and a.look == b.look and a.skill == b.skill, "reproductible")


func test_le_metier_pousse_sa_stat() -> void:
	var total_mechanic: int = 0
	var total_other: int = 0
	for i: int in 40:
		total_mechanic += _recruit(i, &"mechanic").skill
		total_other += _recruit(i, &"scout").skill
	assert_true(total_mechanic > total_other, "les mécaniciens sont plus adroits (%d contre %d)" % [total_mechanic, total_other])


func test_vingt_recrues_vingt_visages_et_pas_deux_fois_le_meme_prenom() -> void:
	var names: Array[String] = []
	var looks: Array[int] = []
	var rng := _rng(5)
	for i: int in CrewLooks.COUNT:
		var member := CrewFactory.recruit(rng, &"medic", "soins", false, 50, names, looks)
		assert_false(member.display_name in names, "prénom libre : %s" % member.display_name)
		assert_false(member.look in looks, "apparence libre : %d" % member.look)
		names.append(member.display_name)
		looks.append(member.look)
	assert_true(CrewNames.FIRST_NAMES.size() >= 40, "assez de prénoms pour tourner")


func test_l_equipement_de_depart_suit_l_avancee_sur_la_ligne() -> void:
	var rng := _rng(9)
	var rare_early: int = 0
	var rare_late: int = 0
	for i: int in 60:
		for item: ItemData in CrewFactory.starting_gear(rng, 1):
			rare_early += 1 if item.tier > 1 else 0
		for item: ItemData in CrewFactory.starting_gear(rng, 20):
			rare_late += 1 if item.tier > 1 else 0
	assert_true(rare_early == 0, "au début : que du courant")
	assert_true(rare_late > 0, "plus loin : du rare")


func test_les_vingt_apparences_ont_leur_sprite_et_leur_portrait() -> void:
	for look: int in range(1, CrewLooks.COUNT + 1):
		var frames: SpriteFrames = CrewLooks.frames(look)
		assert_true(frames != null, "sprite n°%d" % look)
		for animation: StringName in [&"idle_s", &"walk_e", &"walk_n", &"attack_w", &"harvest_s"]:
			assert_true(frames.has_animation(animation), "n°%d : %s" % [look, animation])
		var portrait: Texture2D = CrewLooks.portrait(look)
		assert_true(portrait != null and portrait.get_width() == 12, "portrait 12 px n°%d" % look)


func test_identite_stats_et_equipement_sont_sauvegardes() -> void:
	var member := _recruit(11)
	member.loadout.equip(MACHETE)
	var copy := CrewMember.from_dict(JSON.parse_string(JSON.stringify(member.to_dict())))
	assert_true(copy.full_name() == member.full_name(), "le nom")
	assert_true(copy.look == member.look, "l'apparence")
	assert_true([copy.strength, copy.endurance, copy.skill, copy.nerve] == [member.strength, member.endurance, member.skill, member.nerve], "les stats")
	assert_true(copy.loadout.get_item(ItemData.Slot.WEAPON) == MACHETE, "ce qu'il porte")


func test_un_equipier_d_une_vieille_sauvegarde_recoit_une_apparence() -> void:
	var old := {"name": "Malik", "role": "scout", "role_label": "repérage", "infected": false}
	var member := CrewMember.from_dict(old)
	assert_true(member.look == CrewLooks.from_name("Malik"), "tirée de son prénom, toujours la même")
	assert_true(member.skill == 3 and member.nerve == 3, "stats moyennes")


# --- Équiper ses équipiers -------------------------------------------------------------

func test_on_donne_un_objet_du_casier_et_on_le_reprend() -> void:
	var lea := _bare()
	GameState.owned_items.append(MACHETE)
	assert_true(GameState.equip_member(lea, MACHETE), "donnée")
	assert_true(lea.loadout.get_item(ItemData.Slot.WEAPON) == MACHETE, "Léa a la machette")
	assert_false(MACHETE in GameState.spare_items(), "plus dans le casier")
	assert_false(GameState.equip_member(lea, KEVLAR), "on ne donne pas ce qu'on n'a pas")
	assert_true(GameState.unequip_member(lea, ItemData.Slot.WEAPON), "reprise")
	assert_true(MACHETE in GameState.spare_items(), "de retour au casier")


func test_ce_qu_il_portait_revient_au_casier() -> void:
	var lea := _bare()
	lea.loadout.equip(PIPE)
	GameState.owned_items.append(MACHETE)
	GameState.equip_member(lea, MACHETE)
	assert_true(PIPE in GameState.spare_items(), "sa barre de fer est au casier")


func test_un_objet_en_double_compte_deux_fois() -> void:
	# Le joueur porte sa barre de fer ; il reprend celle d'une recrue : une au casier.
	var lea := _bare()
	lea.loadout.equip(PIPE)
	assert_true(GameState.loadout.get_item(ItemData.Slot.WEAPON) == PIPE, "le joueur a la sienne")
	GameState.unequip_member(lea, ItemData.Slot.WEAPON)
	assert_true(GameState.spare_items().count(PIPE) == 1, "la deuxième est au casier")
	assert_true(GameState.equip_member(lea, PIPE), "on peut la lui rendre")
	assert_true(GameState.loadout.get_item(ItemData.Slot.WEAPON) == PIPE, "le joueur garde la sienne")


func test_renvoye_il_rend_son_equipement() -> void:
	var lea := _bare()
	lea.loadout.equip(KEVLAR)
	GameState.dismiss(lea)
	assert_true(KEVLAR in GameState.owned_items, "le kevlar reste à bord")


func test_mort_a_bord_on_recupere_son_equipement() -> void:
	var lea := _bare()
	lea.loadout.equip(KEVLAR)
	# Presque morte, et l'infection la ronge (sans tourner en ruche) : elle ne survit pas.
	lea.health = 1
	lea.infected = true
	lea.infection = 75
	GameState.prepare_next_stop()
	assert_false(lea in GameState.crew, "Léa n'a pas survécu")
	assert_true(KEVLAR in GameState.owned_items, "son kevlar est récupéré")


func test_l_inventaire_equipe_l_equipier_choisi() -> void:
	var lea := _bare()
	GameState.owned_items.append(MACHETE)
	var scene := Node.new()
	scene.scene_file_path = "res://levels/train_interior/train_interior.tscn"
	tree.root.add_child(scene)
	tree.current_scene = scene
	_nodes.append(scene)
	GameMenu.open_inventory(GameMenu.InventoryTab.ITEMS, lea)
	var wearers: Node = GameMenu.find_child("Wearers", true, false)
	assert_true(wearers != null and (wearers as Control).visible, "les portraits : toi et l'équipage")
	assert_true(wearers.find_children("*", "SlotCell", true, false).size() == 2, "toi + Léa")
	var give: Button = null
	for node: Node in GameMenu.find_children("*", "Button", true, false):
		if (node as Button).text == "Donner à Léa":
			give = node
	assert_true(give != null, "« Donner à Léa » pour l'objet du casier")
	give.pressed.emit()
	assert_true(lea.loadout.get_item(ItemData.Slot.WEAPON) == MACHETE, "Léa a la machette")
	assert_true(GameState.loadout.get_item(ItemData.Slot.WEAPON) == PIPE, "le joueur garde sa barre")


# --- En mission --------------------------------------------------------------------------

func test_force_arme_et_armure_evitent_les_blessures() -> void:
	var bare := CrewMember.create("A", &"scout", "repérage", false)
	var armed := CrewMember.create("B", &"scout", "repérage", false)
	armed.strength = 5
	armed.loadout.equip(MACHETE)
	armed.loadout.equip(KEVLAR)
	assert_true(MissionSim.wound_factor(bare) == 1.0, "moyen sans rien : comme avant")
	assert_true(MissionSim.wound_factor(armed) < 0.6, "fort, armé, protégé : bien moins de coups")


func test_adresse_outil_et_sac_font_rapporter_plus() -> void:
	var member := CrewMember.create("A", &"scout", "repérage", false)
	var before: float = MissionSim.loot_bonus(member)
	var bag_before: int = MissionSim.bag_size(member)
	member.skill = 5
	member.loadout.equip(CROWBAR)
	member.loadout.equip(HIKING_BAG)
	assert_true(MissionSim.loot_bonus(member) > before, "plus de récolte")
	assert_true(MissionSim.bag_size(member) > bag_before, "plus de place")


func test_masque_et_endurance_limitent_l_infection() -> void:
	var member := CrewMember.create("A", &"scout", "repérage", false)
	var before: float = MissionSim.infection_factor(member)
	member.endurance = 5
	member.loadout.equip(FILTER_MASK)
	assert_true(MissionSim.infection_factor(member) < before * 0.75, "bien moins d'infection")


func test_le_sang_froid_le_fait_decrocher_a_temps() -> void:
	var calm := CrewMember.create("A", &"scout", "repérage", false)
	calm.nerve = 5
	var hothead := CrewMember.create("B", &"scout", "repérage", false)
	hothead.nerve = 1
	assert_true(MissionSim.wound_cap(calm) < MissionSim.wound_cap(hothead), "le calme décroche plus tôt")
	assert_true(MissionSim.wound_cap(calm) < 100, "jamais tué d'un coup en pleine forme")
