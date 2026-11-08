extends Node
## Autoload « Audio » : bruitages, boucles d'ambiance et musique de fond.
##
## - play(&"hit") : un bruitage, entendu partout (hauteur un peu variée à chaque fois).
## - play_at(&"growl", position) : un bruitage placé dans le monde ; il s'atténue au loin
##   et passe à gauche ou à droite selon la caméra.
## - play_music(&"train") : fondu enchaîné vers ce morceau (rien si c'est déjà lui).
## - set_loop(&"rain_loop", true, self) : boucle d'ambiance (pluie, roulement du train),
##   coupée toute seule quand le nœud `owner` quitte la scène.
## - Tous les boutons font « clic » d'eux-mêmes ; un bouton peut demander un autre son
##   (« Fabriquer » fait marteau) : tag(button, &"craft").
## - Deux volumes, Musique et Effets (menu pause > Son), gardés dans user://settings.cfg.
##
## Sons et musiques sont générés par tools/gen_audio.py (synthé maison, 8-bit) : de quoi
## faire tester le jeu en attendant de vrais sons.

const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_DIR: String = "res://assets/audio/music/"
const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"
## Les bruitages et leur volume propre (dB) : c'est ici qu'on équilibre le mélange.
const SOUNDS: Dictionary[StringName, float] = {
	&"ui_click": -8.0, &"ui_open": -6.0, &"ui_close": -7.0, &"ui_error": -5.0,
	&"swing": -6.0, &"hit": -1.0, &"hurt": 0.0, &"enemy_die": -2.0, &"shot": -3.0,
	&"growl": -4.0, &"bark": -5.0, &"freed": -3.0,
	&"pickup": -5.0, &"drop": -4.0, &"plan_found": -2.0,
	&"whistle": -1.0, &"train_depart": 0.0, &"brake": -3.0, &"door": -3.0, &"train_hit": -2.0,
	&"horde": 0.0, &"alarm": -3.0, &"thunder": 0.0, &"encounter": -4.0,
	&"craft": -3.0, &"build": -2.0, &"research": -3.0, &"coal_load": -3.0,
	&"repair_done": -2.0, &"breakdown": 0.0, &"medicine": -3.0,
	&"promotion": -1.0, &"order_done": -2.0, &"defeat": -2.0, &"infection_up": -3.0,
}
## Petites mélodies : toujours à la même hauteur, sinon elles sonnent faux sur la musique.
const STEADY: Array[StringName] = [&"plan_found", &"encounter", &"research", &"repair_done", &"medicine",
	&"promotion", &"order_done", &"defeat", &"ui_open", &"ui_close"]
## Boucles d'ambiance (OGG) et leur volume (dB).
const LOOPS: Dictionary[StringName, float] = {&"rain_loop": -6.0, &"train_loop": -8.0}
const MUSIC: Array[StringName] = [&"title", &"train", &"explore_day", &"explore_night", &"danger"]
## Les sons d'ennemis hors de ce rayon (px) ne s'entendent plus.
const HEARING_DISTANCE: float = 420.0
const POOL_SIZE: int = 10
const WORLD_POOL_SIZE: int = 8
## Un même son relancé plus vite que ça est ignoré (cinq ennemis touchés = un seul « paf »).
const REPEAT_GAP_MS: int = 50
## Sons qui lasseraient vite : un écart plus long (ms) entre deux.
const COOLDOWNS_MS: Dictionary[StringName, int] = {
	&"growl": 700, &"bark": 900, &"alarm": 1500, &"thunder": 1500, &"horde": 3000, &"train_hit": 220, &"hurt": 120,
}
const MUSIC_FADE: float = 1.2
## La musique reste un cran sous les effets.
const MUSIC_DB: float = -6.0
const SILENT_DB: float = -60.0
const DEFAULT_VOLUMES: Dictionary[StringName, float] = {MUSIC_BUS: 0.7, SFX_BUS: 0.8}

## Où les volumes sont gardés (les tests en prennent un autre).
var settings_path: String = "user://settings.cfg"
## false : plus aucun son ne part (les tests l'éteignent ; la musique demandée reste notée).
var enabled: bool = true
var current_music: StringName = &""

var _streams: Dictionary[StringName, AudioStream] = {}
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
		_music.append(_new_player(MUSIC_BUS))
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
	player.stream = stream(id)
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
	player.stream = stream(id)
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


## Le fichier d'un son, d'une boucle ou d'un morceau (chargé une fois, puis gardé).
func stream(id: StringName) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var path: String
	if SOUNDS.has(id):
		path = SFX_DIR + id + ".wav"
	elif LOOPS.has(id):
		path = SFX_DIR + id + ".ogg"
	elif id in MUSIC:
		path = MUSIC_DIR + id + ".ogg"
	var loaded: AudioStream = load(path) as AudioStream if not path.is_empty() and ResourceLoader.exists(path) else null
	if loaded == null:
		push_warning("Audio : fichier manquant pour « %s »" % id)
	elif loaded is AudioStreamOggVorbis:
		(loaded as AudioStreamOggVorbis).loop = true # musiques et ambiances tournent en boucle
	_streams[id] = loaded
	return loaded


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

## Fondu enchaîné vers un morceau. &"" : la musique s'éteint.
func play_music(id: StringName, fade: float = MUSIC_FADE) -> void:
	if id == current_music:
		return
	current_music = id
	if not enabled:
		return
	var old: AudioStreamPlayer = _music[_music_index]
	if old.playing:
		_fade(old, SILENT_DB, fade, true)
	if id == &"":
		return
	var music: AudioStream = stream(id)
	if music == null:
		return
	_music_index = 1 - _music_index
	var player: AudioStreamPlayer = _music[_music_index]
	player.stream = music
	player.volume_db = SILENT_DB
	player.play()
	_fade(player, MUSIC_DB, fade, false)


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
	var loaded: bool = config.load(settings_path) == OK
	for bus: StringName in DEFAULT_VOLUMES:
		var value: float = DEFAULT_VOLUMES[bus]
		if loaded:
			value = float(config.get_value("audio", String(bus).to_lower(), value))
		set_volume(bus, value, false)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.load(settings_path) # garde les autres réglages qu'on y mettra
	for bus: StringName in DEFAULT_VOLUMES:
		config.set_value("audio", String(bus).to_lower(), snappedf(volume(bus), 0.01))
	config.save(settings_path)
