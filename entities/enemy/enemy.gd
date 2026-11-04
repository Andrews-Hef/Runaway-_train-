class_name Enemy
extends CharacterBody2D
## Un ennemi des zones d'arrêt : infecté ou pilleur, selon son EnemyData.
##
## Machine à états simple :
##   ERRANCE → (voit le joueur) → POURSUITE → (à portée) → ÉLAN → coup → REPOS → POURSUITE
##   coup reçu → RECUL ; vie à 0 → MORT. Trop loin de chez lui → retour en ERRANCE.
##
## Il ne sait pas ce que fait son coup : il émet attack_landed, et la zone applique
## les effets (dégâts, exposition, vol). Pareil à sa mort (died : butin à rendre).

signal attack_landed(enemy: Enemy)
signal died(enemy: Enemy)

enum State { WANDER, CHASE, WINDUP, RECOVER, HURT, DEAD }

const GROUP: StringName = &"enemies"
## Durée du recul quand il est touché.
const HURT_TIME: float = 0.25
const KNOCKBACK: float = 140.0

@export var data: EnemyData

## Qui il chasse (le joueur). Null = il erre.
var target: Node2D
## false : il ne bouge plus (fin de l'arrêt).
var active: bool = true
## Ce qu'il a volé (rendu à sa mort).
var carried: Dictionary[StringName, int] = {}
var state: State = State.WANDER
var home: Vector2
var facing: Vector2 = Vector2.DOWN

@onready var health: HealthComponent = $Health
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

var _timer: float = 0.0
var _pause: float = 0.0
var _wander_point: Vector2
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(GROUP)
	home = global_position
	_wander_point = home
	if data:
		_sprite.sprite_frames = data.frames
		health.reset(data.max_health)
	_rng.seed = hash(global_position)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_play(&"idle")


func _physics_process(delta: float) -> void:
	think(delta)
	move_and_slide()
	_update_animation()


## Une étape de réflexion : change d'état et choisit la vitesse. Séparé du
## déplacement pour être testable sans moteur physique.
func think(delta: float) -> void:
	if state == State.DEAD:
		velocity = Vector2.ZERO
		return
	if not active:
		velocity = Vector2.ZERO
		return
	_timer -= delta
	var to_target: Vector2 = target.global_position - global_position if is_instance_valid(target) else Vector2.INF
	var distance: float = to_target.length() if is_instance_valid(target) else INF
	match state:
		State.WANDER:
			if distance <= data.sight_range:
				state = State.CHASE
			else:
				_wander(delta)
		State.CHASE:
			if distance > data.sight_range * 1.6 or global_position.distance_to(home) > data.leash_range:
				state = State.WANDER
				_wander_point = home
			elif distance <= data.attack_range:
				state = State.WINDUP
				_timer = data.windup
				velocity = Vector2.ZERO
				facing = to_target.normalized()
				_play(&"attack", true)
			else:
				facing = to_target.normalized()
				velocity = facing * data.chase_speed
		State.WINDUP:
			velocity = Vector2.ZERO
			if _timer <= 0.0:
				# Le coup ne porte que si le joueur est encore là (on peut esquiver).
				if distance <= data.attack_range + 6.0:
					attack_landed.emit(self)
				state = State.RECOVER
				_timer = data.cooldown
		State.RECOVER:
			velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
			if _timer <= 0.0:
				state = State.CHASE
		State.HURT:
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			if _timer <= 0.0:
				state = State.CHASE


## Encaisse un coup du joueur : recul, puis il reprend la poursuite.
func take_hit(amount: int, from: Vector2) -> void:
	if state == State.DEAD:
		return
	health.take_damage(amount, from)


func is_dead() -> bool:
	return state == State.DEAD


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


func _on_damaged(_amount: int, from: Vector2) -> void:
	if health.is_dead():
		return
	state = State.HURT
	_timer = HURT_TIME
	var away: Vector2 = (global_position - from).normalized()
	velocity = (away if away != Vector2.ZERO else Vector2.DOWN) * KNOCKBACK
	_flash(Color(1.0, 0.55, 0.55))


func _on_died() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	remove_from_group(GROUP)
	$CollisionShape2D.set_deferred(&"disabled", true)
	died.emit(self)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.5)
	tween.parallel().tween_property(_sprite, "position:y", _sprite.position.y + 4.0, 0.5)
	tween.tween_callback(queue_free)


func _flash(color: Color) -> void:
	_sprite.modulate = color
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.2)


func _update_animation() -> void:
	if state == State.DEAD or state == State.WINDUP:
		return
	_play(&"walk" if velocity.length() > 4.0 else &"idle")


func _play(action: StringName, restart: bool = false) -> void:
	if _sprite.sprite_frames == null:
		return
	var animation_name := StringName(String(action) + "_" + Player.direction_name(facing))
	if restart or _sprite.animation != animation_name:
		_sprite.play(animation_name)
