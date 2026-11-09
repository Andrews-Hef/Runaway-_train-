class_name Enemy
extends CharacterBody2D
## Un ennemi des zones d'arrêt, réglé par son EnemyData (faction + profil).
##
## Machine à états :
##   ERRANCE → (voit le joueur) → POURSUITE → (à portée) → ÉLAN → action → REPOS → POURSUITE
##   - infanterie et lourd : l'action est un coup au corps à corps ;
##   - tireur : il garde ses distances, vise, puis tire un projectile ;
##   - rampant : il plaque le joueur (PRISE) et mord jusqu'à ce que le joueur se dégage,
##     puis il reste SONNÉ un moment.
##   Coup reçu → RECUL (sauf lourds) ; vie à 0 → MORT ; trop loin de chez lui → ERRANCE.
##   Membre d'une horde (besieging) : au lieu d'errer, il marche sur le train et le frappe
##   (signal train_hit) ; s'il voit le joueur, il le poursuit, puis retourne au train.
##
## Il ne sait pas ce que fait son action : il émet un signal, la zone applique les effets
## (dégâts, exposition, vol, plaquage).

signal attack_landed(enemy: Enemy)
signal shot_fired(enemy: Enemy, projectile: Projectile)
signal grabbed(enemy: Enemy)
signal died(enemy: Enemy)
## Membre d'une horde : son coup a porté sur le train.
signal train_hit(enemy: Enemy)

enum State { WANDER, CHASE, WINDUP, RECOVER, HURT, DEAD, GRAB, STUNNED }

const GROUP: StringName = &"enemies"
## Durée du recul quand il est touché.
const HURT_TIME: float = 0.25
const KNOCKBACK: float = 140.0
## Temps pendant lequel un rampant reste sonné quand le joueur se dégage.
const STUN_TIME: float = 2.0
## Fin de la visée : la ligne se fige, c'est le moment d'esquiver.
const AIM_LOCK: float = 0.3
## D'où part le tir (le buste).
const MUZZLE: Vector2 = Vector2(0.0, -14.0)
## Marge de portée au moment du coup (un lourd frappe large).
const MELEE_MARGIN: float = 6.0
const HEAVY_MARGIN: float = 10.0
## Alarme : durée de l'alerte et portée de vue multipliée pendant ce temps.
const ALERT_TIME: float = 8.0
const ALERT_SIGHT: float = 3.0
## Horde : distance au point du train où il s'arrête pour frapper, et vitesse de marche.
const SIEGE_REACH: float = 8.0
const SIEGE_SPEED: float = 0.9
## La nuit : infectés plus dangereux, pilleurs moins vigilants.
const NIGHT_INFECTED_SIGHT: float = 1.4
const NIGHT_INFECTED_SPEED: float = 1.15
const NIGHT_RAIDER_SIGHT: float = 0.65

@export var data: EnemyData

## Qui il chasse (le joueur). Null = il erre.
var target: Node2D
## false : il ne bouge plus (fin de l'arrêt, dialogue).
var active: bool = true
## Ce qu'il a volé (rendu à sa mort).
var carried: Dictionary[StringName, int] = {}
var state: State = State.WANDER
var home: Vector2
var facing: Vector2 = Vector2.DOWN

@onready var health: HealthComponent = $Health
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _telegraph: Node2D = $Telegraph

var _timer: float = 0.0
var _pause: float = 0.0
var _wander_point: Vector2
var _aim_point: Vector2
var _rng := RandomNumberGenerator.new()
## Temps restant d'alerte (alarme) : il voit beaucoup plus loin et accourt.
var _alerted: float = 0.0
## Membre d'une horde : il marche sur `siege_point` (le flanc du train) et le frappe.
var besieging: bool = false
var siege_point: Vector2
## Le coup en cours vise le train (pas le joueur).
var _hitting_train: bool = false
## Réglages de la nuit (voir set_night) : portée de vue et vitesse de poursuite.
var sight_scale: float = 1.0
var speed_scale: float = 1.0


func _ready() -> void:
	add_to_group(GROUP)
	home = global_position
	_wander_point = home
	if data:
		_sprite.sprite_frames = data.frames
		_sprite.offset = data.sprite_offset
		health.reset(data.max_health)
	_rng.seed = hash(global_position)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_telegraph.draw.connect(_draw_telegraph)
	_play(&"idle")


func _physics_process(delta: float) -> void:
	think(delta)
	if state != State.GRAB:
		move_and_slide()
	_update_animation()


## Une étape de réflexion : change d'état et choisit la vitesse. Séparé du
## déplacement pour être testable sans moteur physique.
func think(delta: float) -> void:
	if state == State.DEAD or not active:
		velocity = Vector2.ZERO
		return
	_timer -= delta
	_alerted = maxf(_alerted - delta, 0.0)
	var sight: float = data.sight_range * sight_scale * (ALERT_SIGHT if _alerted > 0.0 else 1.0)
	var has_target: bool = is_instance_valid(target)
	var to_target: Vector2 = target.global_position - global_position if has_target else Vector2.ZERO
	var distance: float = to_target.length() if has_target else INF
	match state:
		State.WANDER:
			if distance <= sight:
				state = State.CHASE
				_cry()
			elif besieging:
				_besiege()
			else:
				_wander(delta)
		State.CHASE:
			if distance > sight * 1.6 or global_position.distance_to(home) > data.leash_range:
				state = State.WANDER
				_wander_point = home
			elif data.archetype == EnemyData.Archetype.SNIPER:
				_keep_distance(to_target, distance)
			elif distance <= data.attack_range:
				_start_windup(to_target)
			else:
				facing = to_target.normalized()
				velocity = facing * chase_speed()
		State.WINDUP:
			velocity = Vector2.ZERO
			# Le tireur suit sa cible du regard, puis fige sa visée juste avant de tirer.
			if has_target and _timer > AIM_LOCK and not _hitting_train:
				_aim_point = target.global_position
				facing = to_target.normalized()
			if _timer <= 0.0:
				_release(distance)
			_telegraph.queue_redraw()
		State.RECOVER, State.HURT, State.STUNNED:
			velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
			if _timer <= 0.0:
				state = State.CHASE
		State.GRAB:
			velocity = Vector2.ZERO
			if has_target:
				global_position = target.global_position + Vector2(-facing.x * 6.0, 2.0)
			if _timer <= 0.0:
				attack_landed.emit(self) # une morsure (ou une main dans le sac)
				_timer = data.grab_tick


## Le joueur s'est dégagé : le rampant est repoussé et reste sonné.
func release_grab() -> void:
	if state != State.GRAB:
		return
	state = State.STUNNED
	_timer = STUN_TIME
	velocity = -facing * KNOCKBACK
	_flash(Color(0.7, 0.7, 1.0))


## Encaisse un coup du joueur.
func take_hit(amount: int, from: Vector2) -> void:
	if state == State.DEAD:
		return
	health.take_damage(amount, from)


func is_dead() -> bool:
	return state == State.DEAD


func is_grabbing() -> bool:
	return state == State.GRAB


# --- Comportements ------------------------------------------------------------------

func _start_windup(to_target: Vector2) -> void:
	state = State.WINDUP
	_timer = data.windup
	velocity = Vector2.ZERO
	facing = to_target.normalized()
	_aim_point = global_position + to_target
	_play(&"attack", true)


## Le tireur garde ses distances : il recule si on approche, avance si on s'éloigne.
func _keep_distance(to_target: Vector2, distance: float) -> void:
	facing = to_target.normalized()
	if distance < data.flee_range:
		velocity = -facing * chase_speed()
	elif distance > data.attack_range:
		velocity = facing * chase_speed()
	else:
		_start_windup(to_target)


## Fin de l'élan : le coup, le tir ou le plaquage.
func _release(distance: float) -> void:
	_telegraph.queue_redraw()
	if _hitting_train:
		_hitting_train = false
		if global_position.distance_to(siege_point) <= SIEGE_REACH * 2.0:
			train_hit.emit(self)
		state = State.RECOVER
		_timer = data.cooldown
		return
	match data.archetype:
		EnemyData.Archetype.SNIPER:
			_fire()
		EnemyData.Archetype.CRAWLER:
			if distance <= data.attack_range + MELEE_MARGIN:
				state = State.GRAB
				_timer = data.grab_tick
				Audio.play_at(&"growl", global_position, 0.1, 3.0)
				grabbed.emit(self)
				attack_landed.emit(self)
				return
		EnemyData.Archetype.HEAVY:
			if distance <= data.attack_range + HEAVY_MARGIN:
				attack_landed.emit(self)
		_:
			# Le coup ne porte que si le joueur est encore là (on peut esquiver).
			if distance <= data.attack_range + MELEE_MARGIN:
				attack_landed.emit(self)
	state = State.RECOVER
	_timer = data.cooldown


func _fire() -> void:
	var origin: Vector2 = global_position + MUZZLE
	# Fusil : sur la visée figée. Crachat : sur la position du moment (lent, à esquiver).
	var aim: Vector2 = _aim_point if data.shows_aim_line or not is_instance_valid(target) else target.global_position
	var projectile := Projectile.new()
	projectile.source = data
	projectile.target = target
	projectile.direction = ((aim - Vector2(0.0, Projectile.TARGET_HEIGHT)) - origin).normalized()
	projectile.speed = data.projectile_speed
	projectile.color = data.projectile_color
	projectile.position = origin
	Audio.play_at(&"spit" if _infected() else &"shot", global_position) # crachat ou balle
	shot_fired.emit(self, projectile)


## Horde : marcher sur le train, puis le frapper en boucle.
func _besiege() -> void:
	var to_point: Vector2 = siege_point - global_position
	if to_point.length() <= SIEGE_REACH:
		_hitting_train = true
		_start_windup(Vector2.UP * 8.0)
		return
	facing = to_point.normalized()
	velocity = facing * chase_speed() * SIEGE_SPEED


func chase_speed() -> float:
	return data.chase_speed * speed_scale


## La nuit, la ruche chasse (les infectés voient plus loin et courent plus vite) et les
## pilleurs dorment à moitié (ils voient moins loin).
func set_night(night: bool) -> void:
	if not night or data == null:
		sight_scale = 1.0
		speed_scale = 1.0
	elif data.faction == EnemyData.Faction.INFECTED:
		sight_scale = NIGHT_INFECTED_SIGHT
		speed_scale = NIGHT_INFECTED_SPEED
	else:
		sight_scale = NIGHT_RAIDER_SIGHT
		speed_scale = 1.0


## En fait un membre de horde : il fonce sur ce point du train (son nouveau « chez lui »).
func join_siege(point: Vector2) -> void:
	besieging = true
	siege_point = point
	home = point


func _wander(delta: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 200.0 * delta)
		return
	# Arrivé (ou bloqué trop longtemps) : petite pause, puis un autre point autour de chez lui.
	if global_position.distance_to(_wander_point) < 4.0 or _timer <= 0.0:
		_pause = _rng.randf_range(0.8, 2.0)
		_wander_point = home + Vector2(_rng.randf_range(-40.0, 40.0), _rng.randf_range(-30.0, 30.0))
		_timer = 4.0
		return
	facing = (_wander_point - global_position).normalized()
	velocity = facing * data.wander_speed


# --- Réactions ----------------------------------------------------------------------

## Une alarme sonne en `at` (voiture fouillée en ville) : il accourt, et voit loin
## pendant ALERT_TIME secondes. Son point d'attache devient l'alarme.
## Il repère le joueur : grognement (infecté) ou « Hé ! » (pilleur).
func _cry() -> void:
	Audio.play_at(&"growl" if _infected() else &"bark", global_position)


func _infected() -> bool:
	return data.faction == EnemyData.Faction.INFECTED


func alert(at: Vector2) -> void:
	if state == State.DEAD:
		return
	home = at
	_alerted = ALERT_TIME
	if state == State.WANDER:
		state = State.CHASE


func _on_damaged(_amount: int, from: Vector2) -> void:
	if health.is_dead():
		return
	_flash(Color(1.0, 0.55, 0.55))
	# Un lourd encaisse sans broncher ; un rampant qui tient sa proie ne lâche pas.
	if data.stagger_immune or state == State.GRAB:
		return
	_hitting_train = false
	state = State.HURT
	_timer = HURT_TIME
	_telegraph.queue_redraw()
	var away: Vector2 = (global_position - from).normalized()
	velocity = (away if away != Vector2.ZERO else Vector2.DOWN) * KNOCKBACK


func _on_died() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	remove_from_group(GROUP)
	_telegraph.queue_redraw()
	$CollisionShape2D.set_deferred(&"disabled", true)
	Audio.play_at(&"enemy_die" if _infected() else &"raider_die", global_position)
	died.emit(self)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.5)
	tween.parallel().tween_property(_sprite, "position:y", _sprite.position.y + 4.0, 0.5)
	tween.tween_callback(queue_free)


func _flash(color: Color) -> void:
	_sprite.modulate = color
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.2)


## Ce qui prévient le joueur : zone rouge au sol (lourd), ligne de visée (fusil).
func _draw_telegraph() -> void:
	if state != State.WINDUP or data == null:
		return
	var progress: float = 1.0 - clampf(_timer / maxf(data.windup, 0.01), 0.0, 1.0)
	if data.archetype == EnemyData.Archetype.HEAVY:
		var radius: float = data.attack_range + HEAVY_MARGIN
		_telegraph.draw_circle(Vector2.ZERO, radius * progress, Color(1.0, 0.2, 0.15, 0.25))
		_telegraph.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(1.0, 0.3, 0.2, 0.8), 1.0)
	elif data.archetype == EnemyData.Archetype.SNIPER and data.shows_aim_line:
		var locked: bool = _timer <= AIM_LOCK
		var end: Vector2 = _aim_point - global_position - Vector2(0.0, Projectile.TARGET_HEIGHT)
		_telegraph.draw_line(MUZZLE, end, Color(1.0, 0.15, 0.1, 0.9 if locked else 0.35), 1.0 if not locked else 1.5)


func _update_animation() -> void:
	if state in [State.DEAD, State.WINDUP, State.GRAB]:
		return
	_play(&"walk" if velocity.length() > 4.0 else &"idle")


func _play(action: StringName, restart: bool = false) -> void:
	if _sprite.sprite_frames == null:
		return
	var animation_name := StringName(String(action) + "_" + Player.direction_name(facing))
	if restart or _sprite.animation != animation_name:
		_sprite.play(animation_name)
