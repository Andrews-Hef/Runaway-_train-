extends Node
## Autoload « Audio » : bruitages, boucles d'ambiance et musique de fond.
##
## - play(&"hit") : un bruitage, entendu partout. S'il a plusieurs variantes (4 coups,
##   3 cris…), une au hasard, jamais deux fois la même de suite ; hauteur un peu variée.
## - play_at(&"growl", position) : un bruitage placé dans le monde ; il s'atténue au loin
##   et passe à gauche ou à droite selon la caméra.
## - play_music(&"explore_day") : la playlist de ce moment du jeu, en fondu enchaîné (rien si
##   c'est déjà elle). Les morceaux s'enchaînent au hasard, sans répéter celui qui vient de
##   passer ; un moment qui n'a qu'un morceau le joue en boucle.
## - set_loop(&"rain_loop", true, self) : boucle d'ambiance (pluie, roulement du train),
##   coupée toute seule quand le nœud `owner` quitte la scène.
## - Tous les boutons font « clic » d'eux-mêmes ; un bouton peut demander un autre son
##   (« Fabriquer » fait marteau) : tag(button, &"craft").
## - Deux volumes, Musique et Effets (menu pause > Son), gardés dans user://settings.cfg.
##
## Sons et musiques libres (CC0 pour la plupart, voir assets/audio/CREDITS.md), préparés
## par tools/build_audio.py, qui écrit aussi le catalogue (AudioCatalog : playlists,
## variantes, crédits).

const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_DIR: String = "res://assets/audio/music/"
const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"
## Les bruitages et leur volume propre (dB) : c'est ici qu'on équilibre le mélange.
## (Les fichiers sont déjà au même volume moyen : ces chiffres disent qui passe devant.)
const SOUNDS: Dictionary[StringName, float] = {
	&"ui_click": -10.0, &"ui_open": -9.0, &"ui_close": -9.0, &"ui_error": -8.0, &"encounter": -6.0,
	&"swing": -8.0, &"hit": -3.0, &"hurt": -3.0, &"enemy_die": -4.0, &"raider_die": -4.0,
	&"shot": -4.0, &"spit": -5.0, &"growl": -6.0, &"bark": -6.0, &"freed": -6.0,
	&"pickup": -6.0, &"drop": -6.0, &"plan_found": -4.0,
	&"whistle": -4.0, &"train_depart": -4.0, &"brake": -6.0, &"door": -6.0, &"train_hit": -4.0,
	&"horde": -2.0, &"alarm": -8.0, &"thunder": -2.0,
	&"craft": -6.0, &"build": -6.0, &"research": -6.0, &"coal_load": -6.0,
	&"repair_done": -5.0, &"breakdown": -3.0, &"medicine": -5.0,
	&"promotion": -3.0, &"order_done": -4.0, &"defeat": -4.0, &"infection_up": -4.0,
}
## Petites mélodies : toujours à la même hauteur, sinon elles sonnent faux sur la musique.
const STEADY: Array[StringName] = [&"plan_found", &"encounter", &"research", &"repair_done", &"medicine",
	&"promotion", &"order_done", &"defeat", &"ui_open", &"ui_close"]
## Boucles d'ambiance (OGG) et leur volume (dB).
const LOOPS: Dictionary[StringName, float] = {&"rain_loop": -6.0, &"train_loop": -8.0}
## Les sons d'ennemis hors de ce rayon (px) ne s'entendent plus.
const HEARING_DISTANCE: float = 420.0
const POOL_SIZE: int = 10
const WORLD_POOL_SIZE: int = 8
## Un même son relancé plus vite que ça est ignoré (cinq ennemis touchés = un seul « paf »).
const REPEAT_GAP_MS: int = 50
## Sons qui lasseraient vite : un écart plus long (ms) entre deux.
const COOLDOWNS_MS: Dictionary[StringName, int] = {
	&"growl": 700, &"bark": 900, &"alarm": 1500, &"thunder": 1500, &"horde": 3000, &"train_hit": 220, &"hurt": 120,
	&"spit": 300,
}
const MUSIC_FADE: float = 1.2
## La musique reste un cran sous les effets.
const MUSIC_DB: float = -6.0
## Entre deux morceaux d'une même playlist : petit fondu d'entrée.
const NEXT_TRACK_FADE: float = 0.6
const SILENT_DB: float = -60.0
const DEFAULT_VOLUMES: Dictionary[StringName, float] = {MUSIC_BUS: 0.7, SFX_BUS: 0.8}

## Où les volumes sont gardés (les tests en prennent un autre).
var settings_path: String = "user://settings.cfg"
## false : plus aucun son ne part (les tests l'éteignent ; la musique demandée reste notée).
var enabled: bool = true
## Le moment du jeu dont la playlist joue (&"" : pas de musique)…
var current_music: StringName = &""
## …et le morceau en cours (chemin sous assets/audio/music/, sans extension).
var current_track: String = ""

var _streams: Dictionary[StringName, AudioStream] = {}
var _variants: Dictionary[StringName, Array] = {}
var _last_variant: Dictionary[StringName, int] = {}
var _tracks: Dictionary[String, AudioStream] = {}
var _players: Array[AudioStreamPlayer] = []
var _world_players: Array[AudioStreamPlayer2D] = []
var _next_player: int = 0
var _next_world: int = 0
var _last_played: Dictionary[StringName, int] = {}
var _music: Array[AudioStreamPlayer] = []
var _music_index: int = 0
var _loops: Dictionary[StringName, AudioStreamPlayer] = {}
var _tweens: Dictionary[AudioStreamPlayer, Tween] = {}
var _volumes: Dictionary[StringName, float] = DEFAULT_VOLUMES.duplicate()
var _save_pending: bool = false
## Son propre hasard : ne touche pas à celui du jeu (graines reproductibles).
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # la musique et les clics continuent en pause
	_rng.randomize()
	for i: int in POOL_SIZE:
		_players.append(_new_player(SFX_BUS))
	for i: int in WORLD_POOL_SIZE:
		var player := AudioStreamPlayer2D.new()
		player.bus = SFX_BUS
		player.max_distance = HEARING_DISTANCE
		player.attenuation = 1.2
		player.panning_strength = 0.6
		add_child(player)
		_world_players.append(player)
	for i: int in 2:
		var music := _new_player(MUSIC_BUS)
		music.finished.connect(_on_track_finished.bind(music))
		_music.append(music)
	load_settings()
	get_tree().node_added.connect(_on_node_added)
	_hook_buttons(get_tree().root)


func _process(_delta: float) -> void:
	if _save_pending:
		_save_pending = false
		save_settings()


func _new_player(bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


# --- Bruitages ---------------------------------------------------------------------

## Joue un bruitage. `pitch_spread` : écart de hauteur au hasard (0 = toujours pareil).
func play(id: StringName, pitch_spread: float = 0.05, volume_db: float = 0.0) -> AudioStreamPlayer:
	if not _may_play(id):
		return null
	var player: AudioStreamPlayer = _free_player()
	player.stream = _pick_variant(id)
	player.volume_db = SOUNDS[id] + volume_db
	player.pitch_scale = _pitch(id, pitch_spread)
	player.play()
	return player


## Joue un bruitage à un endroit du monde (s'atténue avec la distance à la caméra).
func play_at(id: StringName, at: Vector2, pitch_spread: float = 0.08, volume_db: float = 0.0) -> AudioStreamPlayer2D:
	if not _may_play(id):
		return null
	var player: AudioStreamPlayer2D = _world_players[_next_world]
	for offset: int in WORLD_POOL_SIZE:
		var candidate: AudioStreamPlayer2D = _world_players[(_next_world + offset) % WORLD_POOL_SIZE]
		if not candidate.playing:
			player = candidate
			break
	_next_world = (_world_players.find(player) + 1) % WORLD_POOL_SIZE
	player.global_position = at
	player.stream = _pick_variant(id)
	player.volume_db = SOUNDS[id] + volume_db
	player.pitch_scale = _pitch(id, pitch_spread)
	player.play()
	return player


func has_sound(id: StringName) -> bool:
	return SOUNDS.has(id) and stream(id) != null


func _may_play(id: StringName) -> bool:
	if not enabled:
		return false
	if not SOUNDS.has(id):
		push_warning("Audio : son inconnu « %s »" % id)
		return false
	var now: int = Time.get_ticks_msec()
	var gap: int = COOLDOWNS_MS.get(id, REPEAT_GAP_MS)
	if _last_played.has(id) and now - _last_played[id] < gap:
		return false
	_last_played[id] = now
	return stream(id) != null


func _pitch(id: StringName, spread: float) -> float:
	return 1.0 if id in STEADY else 1.0 + _rng.randf_range(-spread, spread)


## Un lecteur libre ; s'ils jouent tous, on coupe le plus ancien.
func _free_player() -> AudioStreamPlayer:
	for offset: int in POOL_SIZE:
		var candidate: AudioStreamPlayer = _players[(_next_player + offset) % POOL_SIZE]
		if not candidate.playing:
			_next_player = (_players.find(candidate) + 1) % POOL_SIZE
			return candidate
	var oldest: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	return oldest


## Le fichier d'un bruitage (sa première variante) ou d'une ambiance.
func stream(id: StringName) -> AudioStream:
	if SOUNDS.has(id):
		var all: Array = variants(id)
		return all[0] if not all.is_empty() else null
	if _streams.has(id):
		return _streams[id]
	var loop := _load(SFX_DIR + id + ".ogg") as AudioStreamOggVorbis if LOOPS.has(id) else null
	if loop:
		loop.loop = true
	_streams[id] = loop
	return loop


## Toutes les variantes d'un bruitage (chargées une fois, puis gardées).
func variants(id: StringName) -> Array:
	if _variants.has(id):
		return _variants[id]
	var found: Array = []
	var count: int = AudioCatalog.VARIANTS.get(id, 1)
	for index: int in count:
		var path: String = SFX_DIR + id + (".wav" if count == 1 else "_%d.wav" % (index + 1))
		var sound: AudioStream = _load(path)
		if sound:
			found.append(sound)
	_variants[id] = found
	return found


## Une variante au hasard, jamais deux fois la même de suite.
func _pick_variant(id: StringName) -> AudioStream:
	var all: Array = variants(id)
	if all.size() <= 1:
		return all[0] if not all.is_empty() else null
	var index: int = _random_except(all.size(), _last_variant.get(id, -1))
	_last_variant[id] = index
	return all[index]


## Un index de 0 à count - 1, au hasard, différent de `except` (-1 : aucun à éviter).
func _random_except(count: int, except: int) -> int:
	if except < 0 or except >= count:
		return _rng.randi_range(0, count - 1)
	var index: int = _rng.randi_range(0, count - 2)
	return index + 1 if index >= except else index


func _load(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	push_warning("Audio : fichier manquant « %s »" % path)
	return null


## Un bouton qui fait un autre son que le clic (&"" : silencieux). Renvoie le bouton.
func tag(button: BaseButton, id: StringName) -> BaseButton:
	button.set_meta(&"sound", id)
	return button


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_hook_button(node as BaseButton)


func _hook_buttons(node: Node) -> void:
	if node is BaseButton:
		_hook_button(node as BaseButton)
	for child: Node in node.get_children():
		_hook_buttons(child)


func _hook_button(button: BaseButton) -> void:
	if not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed.bind(button))


func _on_button_pressed(button: BaseButton) -> void:
	var id: StringName = button.get_meta(&"sound", &"ui_click")
	if id != &"":
		play(id, 0.03)


# --- Musique -----------------------------------------------------------------------

## Fondu enchaîné vers la playlist d'un moment du jeu. &"" : la musique s'éteint.
func play_music(moment: StringName, fade: float = MUSIC_FADE) -> void:
	if moment == current_music:
		return
	if moment != &"" and not AudioCatalog.PLAYLISTS.has(moment):
		push_warning("Audio : pas de musique pour « %s »" % moment)
	current_music = moment
	_start_track(next_track(moment), fade)


## Le prochain morceau d'une playlist : au hasard, pas celui qui joue déjà.
func next_track(moment: StringName) -> String:
	var tracks: Array = AudioCatalog.PLAYLISTS.get(moment, [])
	if tracks.is_empty():
		return ""
	if tracks.size() == 1:
		return tracks[0]
	return tracks[_random_except(tracks.size(), tracks.find(current_track))]


## Le fichier d'un morceau ; seul dans sa playlist, il boucle.
func track(path: String) -> AudioStream:
	if _tracks.has(path):
		return _tracks[path]
	var music := _load(MUSIC_DIR + path + ".ogg") as AudioStreamOggVorbis
	if music:
		var moment: StringName = StringName(path.get_slice("/", 0))
		music.loop = (AudioCatalog.PLAYLISTS.get(moment, []) as Array).size() == 1
	_tracks[path] = music
	return music


func _start_track(path: String, fade: float) -> void:
	current_track = path
	if not enabled:
		return
	var old: AudioStreamPlayer = _music[_music_index]
	if old.playing:
		_fade(old, SILENT_DB, fade, true)
	var music: AudioStream = track(path) if not path.is_empty() else null
	if music == null:
		return
	_music_index = 1 - _music_index
	var player: AudioStreamPlayer = _music[_music_index]
	player.stream = music
	player.volume_db = SILENT_DB
	player.play()
	_fade(player, MUSIC_DB, fade, false)


## Un morceau se termine : le suivant de la même playlist.
func _on_track_finished(player: AudioStreamPlayer) -> void:
	if player == _music[_music_index] and not player.get_meta(&"stopping", false) and current_music != &"":
		_start_track(next_track(current_music), NEXT_TRACK_FADE)


func stop_music(fade: float = MUSIC_FADE) -> void:
	play_music(&"", fade)


## Coupe net tous les sons, la musique et les ambiances.
func stop_all() -> void:
	for tween: Tween in _tweens.values():
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	for child: Node in get_children():
		if child is AudioStreamPlayer:
			(child as AudioStreamPlayer).stop()
		elif child is AudioStreamPlayer2D:
			(child as AudioStreamPlayer2D).stop()
	current_music = &""
	current_track = ""


# --- Ambiances ---------------------------------------------------------------------

## Allume ou coupe une boucle d'ambiance. Avec `holder`, elle s'arrête quand ce nœud
## quitte l'arbre (changement de scène) : pas de pluie qui suit le joueur dans le train.
func set_loop(id: StringName, on: bool, holder: Node = null, fade: float = 1.0) -> void:
	if not LOOPS.has(id):
		push_warning("Audio : boucle inconnue « %s »" % id)
		return
	var player: AudioStreamPlayer = _loops.get(id)
	if not on or not enabled:
		if player and player.playing:
			_fade(player, SILENT_DB, fade, true)
		return
	if player == null:
		player = _new_player(SFX_BUS)
		_loops[id] = player
	if holder:
		var stopper: Callable = set_loop.bind(id, false, null, 0.4)
		if not holder.tree_exiting.is_connected(stopper):
			holder.tree_exiting.connect(stopper, CONNECT_ONE_SHOT)
	if not player.playing:
		player.stream = stream(id)
		player.volume_db = SILENT_DB
		player.play()
	_fade(player, LOOPS[id], fade, false)


func is_loop_on(id: StringName) -> bool:
	var player: AudioStreamPlayer = _loops.get(id)
	return player != null and player.playing and not player.get_meta(&"stopping", false)


func _fade(player: AudioStreamPlayer, to_db: float, seconds: float, then_stop: bool) -> void:
	if _tweens.has(player) and _tweens[player].is_valid():
		_tweens[player].kill()
	player.set_meta(&"stopping", then_stop)
	if seconds <= 0.0:
		player.volume_db = to_db
		if then_stop:
			player.stop()
		return
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", to_db, seconds)
	if then_stop:
		tween.tween_callback(player.stop)
	_tweens[player] = tween


# --- Volumes -----------------------------------------------------------------------

## Volume d'un bus, de 0 (muet) à 1.
func volume(bus: StringName) -> float:
	return _volumes.get(bus, 1.0)


func set_volume(bus: StringName, value: float, save: bool = true) -> void:
	value = clampf(value, 0.0, 1.0)
	_volumes[bus] = value
	var index: int = AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_mute(index, value <= 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.001)))
	if save:
		_save_pending = true


func load_settings() -> void:
	var config := ConfigFile.new()
	var loaded: bool = FileAccess.file_exists(settings_path) and config.load(settings_path) == OK
	for bus: StringName in DEFAULT_VOLUMES:
		var value: float = DEFAULT_VOLUMES[bus]
		if loaded:
			value = float(config.get_value("audio", String(bus).to_lower(), value))
		set_volume(bus, value, false)


func save_settings() -> void:
	var config := ConfigFile.new()
	if FileAccess.file_exists(settings_path):
		config.load(settings_path) # garde les autres réglages qu'on y mettra
	for bus: StringName in DEFAULT_VOLUMES:
		config.set_value("audio", String(bus).to_lower(), snappedf(volume(bus), 0.01))
	config.save(settings_path)
