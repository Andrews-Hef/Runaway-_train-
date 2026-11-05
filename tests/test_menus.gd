extends TestCase
## Postes du train séparés (plan Interphone), inventaire, menu pause, icônes,
## barre d'équipement, frappe au clic, animation de travail à l'établi.

const TRAIN_MENU: PackedScene = preload("res://ui/train/train_menu.tscn")
const INTERIOR: PackedScene = preload("res://levels/train_interior/train_interior.tscn")
const PLAYER: PackedScene = preload("res://entities/player/player.tscn")
const TrainMenu = preload("res://ui/train/train_menu.gd")
const GameMenuScript = preload("res://ui/game_menu/game_menu.gd")


func before_each() -> void:
	GameState.new_run(55)


func after_each() -> void:
	GameState.new_run()


# --- Postes séparés ----------------------------------------------------------------

func test_les_postes_ne_sont_pas_relies_au_depart() -> void:
	assert_false(GameState.stations_linked(), "chaque poste a son menu au départ")
	GameState.researched_plans.append(GameState.INTERCOM_PLAN)
	assert_true(GameState.stations_linked(), "plan Interphone étudié : postes reliés")


func test_le_plan_interphone_existe_et_dit_ce_qu_il_fait() -> void:
	var plan: BlueprintData = BlueprintCatalog.get_plan(GameState.INTERCOM_PLAN)
	assert_true(plan != null, "plan Interphone dans le catalogue")
	assert_true(plan.requires.is_empty(), "sans prérequis : on peut le trouver tôt")
	assert_true("tous les postes du train reliés" in BlueprintCatalog.unlocks(plan.id), "« Débloque » l'annonce")
	assert_true(GameState.INTERCOM_PLAN in GameState.unfound_plans(), "on peut le trouver dès le premier arrêt")


func test_l_etabli_n_ouvre_que_l_atelier() -> void:
	var menu: CanvasLayer = TRAIN_MENU.instantiate()
	tree.root.add_child(menu)
	menu.call(&"open", TrainMenu.Tab.WORKSHOP)
	var tabs: TabContainer = menu.get_node("%Tabs")
	for i: int in tabs.get_tab_count():
		assert_true(tabs.is_tab_hidden(i) == (i != TrainMenu.Tab.WORKSHOP), "onglet %d : seul l'atelier est visible" % i)
	assert_true(tabs.current_tab == TrainMenu.Tab.WORKSHOP, "sur l'atelier")
	assert_true((menu.get_node("%Hint") as Label).visible, "le menu explique comment relier les postes")
	menu.free()


func test_avec_l_interphone_tous_les_onglets_s_ouvrent() -> void:
	GameState.researched_plans.append(GameState.INTERCOM_PLAN)
	var menu: CanvasLayer = TRAIN_MENU.instantiate()
	tree.root.add_child(menu)
	menu.call(&"open", TrainMenu.Tab.STOCK)
	var tabs: TabContainer = menu.get_node("%Tabs")
	for i: int in tabs.get_tab_count():
		assert_false(tabs.is_tab_hidden(i), "onglet %d visible" % i)
	assert_true(tabs.current_tab == TrainMenu.Tab.STOCK, "ouvert sur le stock")
	assert_false((menu.get_node("%Hint") as Label).visible, "plus besoin d'explication")
	menu.free()


func test_les_machines_ont_leur_onglet() -> void:
	var menu: CanvasLayer = TRAIN_MENU.instantiate()
	tree.root.add_child(menu)
	menu.call(&"open", TrainMenu.Tab.MACHINES)
	var list: VBoxContainer = menu.get_node("%MachinesList")
	assert_true(list.get_child_count() > 0, "l'onglet Machines explique quoi construire")
	menu.free()


func test_les_postes_du_train_ont_une_animation() -> void:
	var interior: Node = INTERIOR.instantiate()
	tree.root.add_child(interior)
	var animations: Dictionary[String, StringName] = {}
	for child: Node in interior.get_node("Train/World").get_children():
		if child is Interactable:
			animations[String(child.name)] = (child as Interactable).animation
	assert_true(animations.get("Station_workshop") == &"work", "à l'établi, il travaille debout")
	assert_true(animations.get("Station_stock") == &"harvest", "il fouille le coffre du stock")
	interior.free()


# --- Joueur : frappe au clic, pose de travail ------------------------------------------

func test_frapper_au_clic_gauche_mais_pas_au_toucher() -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.device = 0
	assert_true(InputMode.is_attack_pressed(click), "un vrai clic gauche frappe")
	var emulated := click.duplicate() as InputEventMouseButton
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	assert_false(InputMode.is_attack_pressed(emulated), "le clic imité par un doigt ne frappe pas")
	var right := click.duplicate() as InputEventMouseButton
	right.button_index = MOUSE_BUTTON_RIGHT
	assert_false(InputMode.is_attack_pressed(right), "clic droit : rien")
	var space := InputEventAction.new()
	space.action = &"attack"
	space.pressed = true
	assert_true(InputMode.is_attack_pressed(space), "l'action Coup frappe toujours")


func test_le_personnage_travaille_a_l_etabli() -> void:
	var frames: SpriteFrames = preload("res://assets/sprites/survivor/survivor.tres")
	for direction: String in ["s", "e", "n", "w"]:
		assert_true(frames.has_animation(StringName("work_" + direction)), "animation work_%s" % direction)
	var player: Player = PLAYER.instantiate()
	tree.root.add_child(player)
	player.hold_pose(&"work", player.global_position + Vector2(0.0, -20.0))
	player.call(&"_update_animation", false, false)
	var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
	assert_true(sprite.animation == &"work_n", "au travail, tourné vers l'établi (obtenu %s)" % sprite.animation)
	player.hold_pose(&"")
	player.call(&"_update_animation", false, false)
	assert_true(sprite.animation == &"idle_n", "menu fermé : il se repose")
	player.free()


# --- Icônes et barre d'équipement -------------------------------------------------------

func test_chaque_equipement_a_son_icone() -> void:
	var seen: Array[Texture2D] = []
	for item: ItemData in ItemCatalog.ALL:
		assert_true(item.icon != null, "%s sans icône" % item.id)
		assert_false(item.icon in seen, "%s : icône déjà utilisée" % item.id)
		seen.append(item.icon)


func test_la_barre_montre_l_equipement_porte() -> void:
	var bar := EquipmentBar.new()
	tree.root.add_child(bar)
	var weapon: ItemData = GameState.loadout.get_item(ItemData.Slot.WEAPON)
	assert_true(bar.icon_for(ItemData.Slot.WEAPON) == weapon.icon, "arme de départ affichée")
	assert_true(bar.icon_for(ItemData.Slot.TOOL) == null, "pas d'outil au départ")
	var crowbar: ItemData = ItemCatalog.get_item(&"tool_crowbar")
	GameState.owned_items.append(crowbar)
	GameState.equip(crowbar)
	assert_true(bar.icon_for(ItemData.Slot.TOOL) == crowbar.icon, "la barre suit le changement d'équipement")
	bar.free()


# --- Menu pause et inventaire ----------------------------------------------------------

func test_pas_de_menu_pause_hors_du_jeu() -> void:
	# Pendant les tests, aucune scène de jeu n'est chargée (comme sur l'écran titre).
	assert_false(GameMenu.is_available(), "pas de menu sans scène de jeu")
	GameMenu.open_pause()
	assert_false(GameMenu.is_open(), "Échap ne fait rien sur l'écran titre")
	assert_false(tree.paused, "le jeu n'est pas mis en pause")


func test_les_commandes_sont_expliquees_pour_chaque_appareil() -> void:
	for device: int in [InputMode.Device.KEYBOARD, InputMode.Device.GAMEPAD, InputMode.Device.TOUCH]:
		var lines: Array[Array] = GameMenuScript.controls_lines(device)
		var actions: Array[String] = []
		for line: Array in lines:
			actions.append(line[0])
		for expected: String in ["Se déplacer", "Frapper", "Agir, fouiller", "Inventaire", "Pause"]:
			assert_true(expected in actions, "appareil %d : %s" % [device, expected])
	var keyboard: String = str(GameMenuScript.controls_lines(InputMode.Device.KEYBOARD))
	assert_true("clic gauche" in keyboard, "le clavier dit qu'on frappe aussi au clic")


func test_rappel_des_touches_a_l_arrivee() -> void:
	var zone: String = GameMenuScript.hint_text(&"zone", InputMode.Device.KEYBOARD)
	assert_true("frapper" in zone and "Espace" in zone, "en zone : comment frapper")
	assert_true("I : inventaire" in zone and "Échap : pause" in zone, "et les menus")
	assert_false("frapper" in GameMenuScript.hint_text(&"train", InputMode.Device.KEYBOARD), "dans le train : pas de combat")
	assert_true(GameMenuScript.hint_text(&"zone", InputMode.Device.TOUCH).is_empty(), "téléphone : les boutons sont à l'écran")


func test_quitter_previent_de_ce_qu_on_perd() -> void:
	assert_true("perdu" in GameMenuScript.quit_warning(&"zone"), "en zone, le butin est perdu")
	assert_true("sauvegardée" in GameMenuScript.quit_warning(&"train"), "dans le train, rien n'est perdu")


# --- Style de l'interface ----------------------------------------------------------------

func test_le_theme_a_ses_plaques_et_ses_variantes() -> void:
	var theme: Theme = preload("res://ui/theme/game_theme.tres")
	assert_true(theme.get_stylebox(&"panel", &"PanelContainer") is StyleBoxTexture, "plaque des menus")
	assert_true(theme.get_stylebox(&"normal", &"Button") is StyleBoxTexture, "boutons en relief")
	for variation: StringName in [&"HudPanel", &"PaperPanel", &"AlertPanel", &"SlotPanel", &"InsetPanel"]:
		assert_true(theme.get_type_variation_base(variation) == &"PanelContainer", "variante %s" % variation)
		assert_true(theme.get_stylebox(&"panel", variation) is StyleBoxTexture, "%s a sa texture" % variation)
	assert_true(theme.get_type_variation_base(&"BannerLabel") == &"Label", "bandeau d'alerte")


func test_le_hud_montre_la_vie_en_segments_et_les_paliers() -> void:
	var hud: CanvasLayer = preload("res://ui/hud/hud.tscn").instantiate()
	tree.root.add_child(hud)
	var health: Control = hud.get_node("%HealthBar")
	var exposure: Control = hud.get_node("%ExposureBar")
	assert_true(health is SegmentBar, "vie en segments")
	assert_true(exposure is StageBar, "infection avec repères")
	assert_true((exposure as StageBar).marks == [0.3, 0.6, 0.9], "repères Fièvre, Contaminé, Critique")
	assert_true((hud.get_node("Root/Order") as PanelContainer).theme_type_variation == &"PaperPanel", "ordre sur télégramme")
	hud.free()


# --- Android : bouton retour, arrière-plan, version -----------------------------------

const TITLE: PackedScene = preload("res://levels/title/title.tscn")


## Fait comme si `path` était la scène en cours (pour GameMenu.scene_kind()).
func _fake_scene(path: String) -> Node:
	var scene := Node.new()
	scene.scene_file_path = path
	tree.root.add_child(scene)
	tree.current_scene = scene
	return scene


func _leave_fake_scene(scene: Node) -> void:
	GameMenu.close()
	tree.current_scene = null
	scene.free()
	tree.paused = false


func test_le_bouton_retour_ne_quitte_pas_le_jeu() -> void:
	assert_false(ProjectSettings.get_setting("application/config/quit_on_go_back"), "réglage du projet")


func test_le_bouton_retour_fait_comme_echap() -> void:
	var scene := _fake_scene("res://levels/stop_zone/stop_zone.tscn")
	GameMenu.go_back()
	assert_true(GameMenu.is_open() and GameMenu.view == GameMenuScript.View.PAUSE, "ouvre la pause")
	assert_true(tree.paused, "jeu en pause")
	GameMenu.go_back()
	assert_false(GameMenu.is_open(), "referme la pause")
	assert_false(tree.paused, "le jeu reprend")
	_leave_fake_scene(scene)


func test_le_bouton_retour_ferme_d_abord_le_menu_du_train() -> void:
	var scene := _fake_scene("res://levels/train_interior/train_interior.tscn")
	var menu: Node = TRAIN_MENU.instantiate()
	scene.add_child(menu)
	menu.call(&"open", TrainMenu.Tab.STOCK)
	GameMenu.go_back()
	assert_false(menu.call(&"is_open"), "le menu du train se ferme")
	assert_false(GameMenu.is_open(), "sans ouvrir la pause")
	_leave_fake_scene(scene)


func test_en_arriere_plan_le_jeu_se_met_en_pause_et_sauvegarde() -> void:
	SaveStore.erase(SaveStore.RESUME)
	var scene := _fake_scene("res://levels/train_interior/train_interior.tscn")
	GameMenu.on_app_hidden()
	assert_true(GameMenu.is_open() and tree.paused, "pause")
	assert_true(SaveStore.exists(SaveStore.RESUME), "partie sauvegardée")
	_leave_fake_scene(scene)
	SaveStore.erase(SaveStore.RESUME)
	scene = _fake_scene("res://levels/stop_zone/stop_zone.tscn")
	GameMenu.on_app_hidden()
	assert_true(GameMenu.is_open(), "en zone : pause aussi")
	assert_false(SaveStore.exists(SaveStore.RESUME), "mais pas de sauvegarde au milieu d'un arrêt")
	_leave_fake_scene(scene)


func test_la_version_est_affichee() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version")
	assert_true(MenuKit.version_text() == "v" + version, "v + version du projet")
	var title: Node = TITLE.instantiate()
	tree.root.add_child(title)
	var label: Label = title.get_node("Ui/Root/Version")
	assert_true(label.text == MenuKit.version_text(), "sur l'écran titre")
	title.free()


func test_sur_l_ecran_titre_retour_annule_la_confirmation() -> void:
	var title: Node = TITLE.instantiate()
	tree.root.add_child(title)
	title.set(&"_confirm_new", true)
	title.call(&"go_back")
	assert_false(title.get(&"_confirm_new"), "confirmation annulée (le jeu ne quitte pas)")
	title.free()
