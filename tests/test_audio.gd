extends TestCase
## Son : fichiers présents et lisibles, bus Musique / Effets, bruitages (anti-répétition,
## boutons qui cliquent), musique en fondu, ambiances liées à leur scène, volumes gardés,
## et la musique choisie par chaque moment du jeu.

const STOP_ZONE: PackedScene = preload("res://levels/stop_zone/stop_zone.tscn")
const HORDE: EventData = preload("res://data/events/horde.tres")
const TITLE: PackedScene = preload("res://levels/title/title.tscn")
const ResultScreenScript = preload("res://ui/result/result_screen.gd")
const TEST_SETTINGS: String = "user://test_settings.cfg"

var _nodes: Array[Node] = []
var _real_settings: String


func before_each() -> void:
	_real_settings = Audio.settings_path
	Audio.settings_path = TEST_SETTINGS
	Audio.stop_all()
	Audio._last_played.clear()
	Audio.enabled = true


func after_each() -> void:
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	Audio.stop_all()
	Audio._last_played.clear()
	Audio.enabled = false
	Audio._save_pending = false
	for bus: StringName in Audio.DEFAULT_VOLUMES:
		Audio.set_volume(bus, Audio.DEFAULT_VOLUMES[bus], false)
	Audio.settings_path = _real_settings
	if FileAccess.file_exists(TEST_SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	GameState.new_run()


func _add(node: Node) -> Node:
	tree.root.add_child(node)
	_nodes.append(node)
	return node


# --- Fichiers et bus ---------------------------------------------------------------

func test_chaque_son_a_ses_fichiers() -> void:
	for id: StringName in Audio.SOUNDS:
		var all: Array = Audio.variants(id)
		assert_true(all.size() == AudioCatalog.VARIANTS.get(id, 0), "bruitage %s : %d variante(s)" % [id, all.size()])
		for sound: AudioStream in all:
			assert_true(sound is AudioStreamWAV, "bruitage %s en WAV (pas de décodage pendant le jeu)" % id)
	for id: StringName in Audio.LOOPS:
		var loop := Audio.stream(id) as AudioStreamOggVorbis
		assert_true(loop != null and loop.loop, "ambiance %s, en boucle" % id)


func test_chaque_morceau_a_son_fichier() -> void:
	for moment: StringName in AudioCatalog.PLAYLISTS:
		var tracks: Array = AudioCatalog.PLAYLISTS[moment]
		for path: String in tracks:
			var music := Audio.track(path) as AudioStreamOggVorbis
			assert_true(music != null, "morceau %s" % path)
			if music:
				assert_true(music.get_length() > 20.0, "%s : un vrai morceau (%.0f s)" % [path, music.get_length()])
				assert_true(music.loop == (tracks.size() == 1), "%s : boucle seulement s'il est seul" % path)


func test_les_moments_du_jeu_ont_leur_musique() -> void:
	for moment: StringName in [&"title", &"train", &"explore_day", &"explore_night", &"danger", &"defeat"]:
		assert_true(AudioCatalog.PLAYLISTS.has(moment), "playlist %s" % moment)
	assert_true(AudioCatalog.PLAYLISTS[&"explore_day"].size() >= 10, "de quoi explorer longtemps sans redite (jour)")
	assert_true(AudioCatalog.PLAYLISTS[&"explore_night"].size() >= 8, "de quoi explorer longtemps sans redite (nuit)")


func test_les_bruitages_sont_courts() -> void:
	for id: StringName in Audio.SOUNDS:
		for sound: AudioStream in Audio.variants(id):
			assert_true(sound.get_length() > 0.01 and sound.get_length() < 8.0, "%s : %.2f s" % [id, sound.get_length()])


## Chaque son demandé dans le code existe (une faute de frappe = un son muet en jeu).
func test_le_code_ne_demande_que_des_sons_qui_existent() -> void:
	var known: Array[StringName] = [&""]
	known.append_array(Audio.SOUNDS.keys())
	known.append_array(Audio.LOOPS.keys())
	known.append_array(AudioCatalog.PLAYLISTS.keys())
	var names := RegEx.create_from_string("&\"(\\w*)\"")
	var checked: int = 0
	for path: String in _scripts("res://", []):
		if path == "res://core/audio.gd" or path.begins_with("res://tests/"):
			continue
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			if not "Audio." in line:
				continue
			for found: RegExMatch in names.search_all(line):
				checked += 1
				assert_true(StringName(found.get_string(1)) in known, "%s : son inconnu « %s »" % [path, found.get_string(1)])
	assert_true(checked > 30, "le jeu fait du bruit un peu partout (%d appels)" % checked)


func _scripts(dir: String, found: Array[String]) -> Array[String]:
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			found.append(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		if not sub.begins_with(".") and sub != "addons" and sub != "assets":
			_scripts(dir.path_join(sub), found)
	return found


func test_musique_et_effets_ont_chacun_leur_bus() -> void:
	for bus: StringName in [Audio.MUSIC_BUS, Audio.SFX_BUS]:
		var index: int = AudioServer.get_bus_index(bus)
		assert_true(index > 0, "bus %s" % bus)
		assert_true(AudioServer.get_bus_send(index) == &"Master", "%s passe par le bus principal" % bus)


# --- Bruitages ---------------------------------------------------------------------

func test_un_bruitage_part_sur_le_bus_des_effets() -> void:
	var player: AudioStreamPlayer = Audio.play(&"hit")
	assert_true(player != null and player.playing, "le son joue")
	assert_true(player.bus == Audio.SFX_BUS, "bus Effets")
	assert_true(player.stream in Audio.variants(&"hit"), "une des variantes du coup")
	assert_true(absf(player.pitch_scale - 1.0) <= 0.05, "hauteur à peine variée")


func test_une_variante_n_est_jamais_rejouee_aussitot() -> void:
	var previous: AudioStream
	for i: int in 20:
		Audio._last_played.clear()
		var player: AudioStreamPlayer = Audio.play(&"hit")
		assert_true(player.stream != previous, "coup %d : une autre variante que le précédent" % i)
		previous = player.stream
		player.stop()


func test_le_meme_son_n_est_pas_empile() -> void:
	assert_true(Audio.play(&"hit") != null, "premier coup")
	assert_true(Audio.play(&"hit") == null, "le même son, aussitôt : ignoré")
	assert_true(Audio.play(&"pickup") != null, "un autre son passe")


func test_les_petites_melodies_ne_sont_jamais_desaccordees() -> void:
	for i: int in 5:
		Audio._last_played.clear()
		var player: AudioStreamPlayer = Audio.play(&"promotion", 0.5)
		assert_true(player.pitch_scale == 1.0, "jingle à sa hauteur")


func test_un_son_place_dans_le_monde() -> void:
	var player: AudioStreamPlayer2D = Audio.play_at(&"growl", Vector2(120.0, 80.0))
	assert_true(player != null and player.playing, "le grognement joue")
	assert_true(player.global_position == Vector2(120.0, 80.0), "là où est l'ennemi")
	assert_true(player.max_distance == Audio.HEARING_DISTANCE, "on ne l'entend pas de l'autre bout de la carte")


func test_son_coupe_rien_ne_part() -> void:
	Audio.enabled = false
	assert_true(Audio.play(&"hit") == null, "pas de bruitage")
	Audio.play_music(&"train")
	assert_true(Audio.current_music == &"train", "la musique demandée reste notée")
	assert_false(Audio._music[0].playing or Audio._music[1].playing, "mais rien ne joue")


func test_les_boutons_cliquent_et_peuvent_avoir_leur_son() -> void:
	var button := _add(Button.new()) as Button
	button.pressed.emit()
	assert_true(Audio._last_played.has(&"ui_click"), "un bouton fait « clic »")
	var craft := _add(MenuKit.action("Fabriquer", Callable(), false, "", &"craft")) as Button
	craft.pressed.emit()
	assert_true(Audio._last_played.has(&"craft"), "« Fabriquer » fait le bruit du marteau")
	Audio._last_played.clear()
	var silent := _add(Audio.tag(Button.new(), &"")) as Button
	silent.pressed.emit()
	assert_true(Audio._last_played.is_empty(), "bouton silencieux")


# --- Musique et ambiances ----------------------------------------------------------

func test_la_musique_change_en_fondu() -> void:
	Audio.play_music(&"train")
	var first: AudioStreamPlayer = Audio._music[Audio._music_index]
	assert_true(Audio.current_track in AudioCatalog.PLAYLISTS[&"train"], "un morceau du train")
	assert_true(first.playing and first.stream == Audio.track(Audio.current_track), "il démarre")
	assert_true(first.bus == Audio.MUSIC_BUS, "bus Musique")
	Audio.play_music(&"train")
	assert_true(Audio._music[Audio._music_index] == first, "la même playlist ne redémarre pas")
	Audio.play_music(&"danger")
	var second: AudioStreamPlayer = Audio._music[Audio._music_index]
	assert_true(second != first and Audio.current_track in AudioCatalog.PLAYLISTS[&"danger"], "l'autre lecteur prend le relais")
	assert_true(first.playing and first.get_meta(&"stopping", false), "l'ancienne s'efface en fondu")


func test_la_playlist_enchaine_sans_redite() -> void:
	Audio.play_music(&"explore_day")
	for i: int in 25:
		var before: String = Audio.current_track
		Audio._on_track_finished(Audio._music[Audio._music_index])
		assert_true(Audio.current_track != before, "morceau %d : pas deux fois le même de suite" % i)
		assert_true(Audio.current_track in AudioCatalog.PLAYLISTS[&"explore_day"], "toujours la playlist du jour")
	Audio.play_music(&"defeat")
	assert_true(Audio.current_track == "defeat/game_over" and Audio.track(Audio.current_track).loop,
		"un moment à un seul morceau : il boucle")


func test_un_morceau_qu_on_quitte_ne_relance_rien() -> void:
	Audio.play_music(&"train")
	var old: AudioStreamPlayer = Audio._music[Audio._music_index]
	Audio.play_music(&"danger")
	var danger: String = Audio.current_track
	Audio._on_track_finished(old)
	assert_true(Audio.current_track == danger, "la fin de l'ancien morceau (en fondu) ne change pas la playlist")


func test_une_ambiance_s_arrete_avec_sa_scene() -> void:
	var scene := _add(Node.new())
	Audio.set_loop(&"rain_loop", true, scene)
	assert_true(Audio.is_loop_on(&"rain_loop"), "la pluie tombe")
	scene.free()
	assert_false(Audio.is_loop_on(&"rain_loop"), "on change de scène : la pluie s'arrête")


# --- Volumes -----------------------------------------------------------------------

func test_les_volumes_sont_gardes() -> void:
	Audio.set_volume(Audio.MUSIC_BUS, 0.3)
	Audio.set_volume(Audio.SFX_BUS, 0.0)
	Audio.save_settings()
	Audio.set_volume(Audio.MUSIC_BUS, 1.0, false)
	Audio.set_volume(Audio.SFX_BUS, 1.0, false)
	Audio.load_settings()
	assert_almost(Audio.volume(Audio.MUSIC_BUS), 0.3, "musique relue")
	assert_almost(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(Audio.MUSIC_BUS)), linear_to_db(0.3), "appliquée au bus")
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(Audio.SFX_BUS)), "effets à 0 : bus muet")
	Audio.set_volume(Audio.SFX_BUS, 0.5, false)
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index(Audio.SFX_BUS)), "remonté : on réentend")


func test_sans_reglage_les_volumes_par_defaut() -> void:
	Audio.load_settings()
	assert_almost(Audio.volume(Audio.MUSIC_BUS), Audio.DEFAULT_VOLUMES[Audio.MUSIC_BUS], "musique par défaut")
	assert_almost(Audio.volume(Audio.SFX_BUS), Audio.DEFAULT_VOLUMES[Audio.SFX_BUS], "effets par défaut")


func test_les_curseurs_reglent_le_son() -> void:
	var settings := _add(SoundSettings.create()) as SoundSettings
	assert_true(settings.sliders.size() == 2, "Musique et Effets")
	assert_almost(settings.sliders[0].value, Audio.volume(Audio.MUSIC_BUS), "le curseur part du réglage actuel")
	settings.sliders[0].value = 0.25
	assert_almost(Audio.volume(Audio.MUSIC_BUS), 0.25, "le curseur Musique règle la musique")
	settings.sliders[1].value = 0.6
	assert_almost(Audio.volume(Audio.SFX_BUS), 0.6, "le curseur Effets règle les effets")


func test_le_menu_pause_a_un_reglage_du_son() -> void:
	GameMenu.call(&"_show_sound")
	assert_true(GameMenu.view == GameMenu.View.SOUND, "écran Son")
	var found: bool = false
	for child: Node in GameMenu._pause_box.get_children():
		found = found or child is SoundSettings
	assert_true(found, "les curseurs de volume")
	GameMenu.call(&"_show_pause_buttons")
	GameMenu.close()


# --- Quelle musique, quand -----------------------------------------------------------

func _zone(minutes: int, surprise: EventData = null) -> Node:
	GameState.new_run(5)
	GameState.stop_number = 8
	GameState.clock_minutes = minutes
	var zone := STOP_ZONE.instantiate()
	zone.set(&"zone_override", preload("res://data/zones/boulevard.tres"))
	zone.set(&"seed_override", 23)
	if surprise:
		zone.set(&"surprise_override", surprise)
	return _add(zone)


func test_la_zone_joue_le_jour_la_nuit_et_la_horde() -> void:
	Audio.enabled = false # seule la musique choisie compte ici
	_zone(12 * 60)
	assert_true(Audio.current_music == &"explore_day", "de jour : exploration")
	_nodes.pop_back().free()
	var zone := _zone(23 * 60, HORDE)
	assert_true(Audio.current_music == &"explore_night", "de nuit : la musique inquiétante")
	var horde: Horde = zone.get(&"horde")
	horde.tick(60.0)
	assert_true(Audio.current_music == &"danger", "la horde : ça cogne")
	zone.call(&"_on_horde_repelled")
	assert_true(Audio.current_music == &"explore_night", "repoussée : retour au calme")


func test_le_bilan_choisit_sa_petite_musique() -> void:
	var result := ExpeditionResult.new()
	assert_true(ResultScreenScript.result_sound(result) == &"defeat", "train raté")
	result.boarded = true
	assert_true(ResultScreenScript.result_sound(result) == &"ui_open", "simple retour")
	result.order_completed = true
	assert_true(ResultScreenScript.result_sound(result) == &"order_done", "ordre rempli")
	result.promotions.append(Career.GRADES[1])
	assert_true(ResultScreenScript.result_sound(result) == &"promotion", "promu")


# --- Crédits -----------------------------------------------------------------------

func test_les_credits_nomment_chaque_oeuvre() -> void:
	var view := _add(CreditsView.create()) as CreditsView
	var expected: int = AudioCatalog.MUSIC_CREDITS.size() + AudioCatalog.SFX_CREDITS.size() + CreditsView.OTHER_CREDITS.size()
	assert_true(view.lines.size() == expected, "une ligne par œuvre (%d)" % expected)
	for entry: Array in AudioCatalog.MUSIC_CREDITS + AudioCatalog.SFX_CREDITS:
		assert_true(entry.size() == 4 and (entry[3] as String).begins_with("https://"), "%s : auteur, licence et lien" % entry[0])
		assert_true(entry[2] in ["CC0", "CC-BY 3.0", "CC-BY 4.0"], "%s : licence connue (%s)" % [entry[0], entry[2]])
	var shown: Array[String] = []
	for line: Button in view.lines:
		shown.append(line.text)
	assert_true("Gunshot Sounds — Vincent Sevedge (publié par Tabasco) (CC-BY 3.0)" in shown,
		"le CC-BY exige le crédit : il est à l'écran")


func test_credits_dans_la_pause_et_sur_l_ecran_titre() -> void:
	GameMenu.call(&"_show_credits")
	assert_true(GameMenu.view == GameMenu.View.CREDITS, "menu pause > Crédits")
	GameMenu.call(&"_show_pause_buttons")
	GameMenu.close()
	var title := _add(TITLE.instantiate())
	title.call(&"toggle_credits")
	assert_true(title.get(&"_credits") != null, "écran titre : les crédits s'ouvrent")
	assert_false((title.get(&"_new_game") as Control).visible, "à la place des boutons")
	title.call(&"go_back")
	assert_true(title.get(&"_credits") == null and (title.get(&"_new_game") as Control).visible, "Retour : les boutons reviennent")
