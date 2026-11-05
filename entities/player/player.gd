class_name Player
extends CharacterBody2D
## Personnage joueur en vue de dessus.
##
## Il ne lit QUE les actions de l'InputMap (move_*, attack, interact).
## Clavier, manette et contrôles tactiles passent tous par ces actions :
## le joueur ne sait pas (et n'a pas à savoir) quel périphérique est utilisé.
##
## Animations td2d (voir art/) : idle, walk, harvest, attack, work, chacune en
## 4 directions (suffixes _s, _e, _n, _w).

signal attacked(direction: Vector2)
## Le coup a touché des ennemis.
signal struck(hits: int)
## Plaqué au sol par un rampant (true), ou dégagé (false).
signal pinned_changed(pinned: bool)
## Progression pour se dégager (appuis sur Coup).
signal mash_changed(progress: float, needed: int)
## Dégagé : `by` est le rampant qui le tenait.
signal freed(by: Node2D)

## Perte de progression par seconde quand on arrête de marteler.
const MASH_DECAY: float = 1.0

## Vitesse de déplacement max, en pixels de jeu par seconde (16 px = 1 m).
@export var move_speed: float = 72.0
## Vitesse à laquelle on atteint move_speed (px/s²).
@export var acceleration: float = 900.0
## Vitesse à laquelle on s'arrête quand on lâche les commandes (px/s²).
@export var friction: float = 1100.0
## Vitesse de lecture du coup (1 = vitesse de l'animation td2d).
@export var attack_speed: float = 1.6
## Portée du coup devant soi, en pixels.
@export var attack_reach: float = 26.0
## Délai entre le début du coup et l'impact (secondes, à vitesse 1).
@export var strike_delay: float = 0.25

## Dégâts d'un coup (ceux de l'arme portée, réglés par la zone).
var attack_damage: int = 1
## Force de chaque appui pour se dégager d'un rampant (talent « Insaisissable »).
var mash_power: float = 1.0

## Dernière direction regardée.
var facing: Vector2 = Vector2.DOWN
## false : le joueur ne répond plus aux commandes (fin de sortie, cinématique...).
var controls_enabled: bool = true

@onready var exposure: ExposureComponent = $Exposure
@onready var interactor: Interactor = $Interactor
@onready var health: HealthComponent = $Health
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

var _attacking: bool = false
## Le rampant qui le tient au sol (null = libre).
var pinned_by: Node2D
var _base_offset_x: float = 0.0
var _mash: float = 0.0
var _mash_needed: int = 8
## Pose tenue tant qu'un menu de poste est ouvert (vide = aucune).
var _held_pose: StringName = &""


func _ready() -> void:
	_base_offset_x = _sprite.offset.x
	_sprite.animation_finished.connect(_on_animation_finished)
	health.damaged.connect(_on_damaged)


func _physics_process(delta: float) -> void:
	if is_pinned():
		# Au sol : impossible de bouger, il faut marteler Coup.
		velocity = Vector2.ZERO
		if _mash > 0.0:
			_mash = maxf(_mash - MASH_DECAY * delta, 0.0)
			mash_changed.emit(_mash, _mash_needed)
		_sprite.offset.x = _base_offset_x + (1.0 if Engine.get_physics_frames() % 6 < 3 else -1.0)
		return
	var input_dir: Vector2 = Vector2.ZERO
	var harvesting: bool = interactor.is_holding()
	# Pendant un coup ou une récolte, le personnage est occupé : il ne marche pas.
	if controls_enabled and not harvesting and not _attacking:
		input_dir = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")

	if input_dir != Vector2.ZERO:
		facing = input_dir.normalized()
		velocity = velocity.move_toward(input_dir * move_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()

	if harvesting:
		facing = (interactor.target.global_position - global_position).normalized()
	_update_animation(input_dir != Vector2.ZERO, harvesting)


## Tient une pose (ex. &"work" devant un établi) tournée vers `target`, jusqu'à
## hold_pose(&"") : le personnage travaille pendant que le menu du poste est ouvert.
func hold_pose(pose: StringName, target: Vector2 = Vector2.ZERO) -> void:
	_held_pose = pose
	if pose != &"" and target != global_position:
		facing = (target - global_position).normalized()


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	interactor.set_physics_process(enabled)


func _unhandled_input(event: InputEvent) -> void:
	var attack_pressed: bool = InputMode.is_attack_pressed(event)
	if is_pinned():
		if attack_pressed or event.is_action_pressed(&"interact"):
			mash()
			get_viewport().set_input_as_handled()
		return
	if controls_enabled and not _attacking and attack_pressed:
		_attack()


# --- Plaqué au sol --------------------------------------------------------------------

## Un rampant le plaque : il faut `mash_needed` appuis rapides pour se dégager.
func pin(by: Node2D, mash_needed: int) -> void:
	pinned_by = by
	_mash = 0.0
	_mash_needed = maxi(mash_needed, 1)
	_attacking = false
	velocity = Vector2.ZERO
	interactor.set_physics_process(false)
	_sprite.speed_scale = 1.0
	_sprite.play(StringName("harvest_" + direction_name(facing)))
	pinned_changed.emit(true)
	mash_changed.emit(_mash, _mash_needed)


func is_pinned() -> bool:
	return pinned_by != null and is_instance_valid(pinned_by)


## Un appui pour se dégager. Renvoie true si le joueur est libre.
func mash() -> bool:
	if not is_pinned():
		return true
	_mash += mash_power
	mash_changed.emit(_mash, _mash_needed)
	if _mash >= _mash_needed:
		release()
		return true
	return false


## Le joueur se relève (dégagé, ou le rampant est mort).
func release() -> void:
	if pinned_by == null:
		return
	var by: Node2D = pinned_by
	pinned_by = null
	_mash = 0.0
	_sprite.offset.x = _base_offset_x
	interactor.set_physics_process(controls_enabled)
	pinned_changed.emit(false)
	freed.emit(by)


## Recul après un coup reçu (rien si on est plaqué au sol).
func knock_back(from: Vector2, force: float) -> void:
	if is_pinned():
		return
	var away: Vector2 = (global_position - from).normalized()
	velocity = (away if away != Vector2.ZERO else Vector2.UP) * force


func _attack() -> void:
	_attacking = true
	_sprite.speed_scale = attack_speed
	_sprite.play(StringName("attack_" + direction_name(facing)))
	attacked.emit(facing)
	# process_always = false : l'impact attend si le jeu est mis en pause.
	get_tree().create_timer(strike_delay / attack_speed, false).timeout.connect(strike)


## L'impact du coup : touche les ennemis devant soi (et ceux collés à soi).
## Renvoie le nombre d'ennemis touchés.
func strike() -> int:
	var hits: int = 0
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		var to_enemy: Vector2 = enemy.global_position - global_position
		var distance: float = to_enemy.length()
		if distance > attack_reach:
			continue
		if distance > 8.0 and facing.dot(to_enemy / distance) < 0.35:
			continue # derrière ou trop sur le côté
		enemy.take_hit(attack_damage, global_position)
		hits += 1
	if hits > 0:
		struck.emit(hits)
	return hits


## Coup reçu : flash rouge (le recul est donné par la zone, selon l'ennemi).
func _on_damaged(_amount: int, _from: Vector2) -> void:
	_sprite.modulate = Color(1.0, 0.45, 0.45)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.25)


func _on_animation_finished() -> void:
	if _attacking:
		_attacking = false
		_sprite.speed_scale = 1.0


func _update_animation(moving: bool, harvesting: bool) -> void:
	if _attacking:
		return
	var action: String = "walk" if moving else "idle"
	if harvesting:
		action = String(interactor.target.animation)
	elif _held_pose != &"" and not moving:
		action = String(_held_pose)
	var animation_name := StringName(action + "_" + direction_name(facing))
	if _sprite.animation != animation_name:
		_sprite.play(animation_name)


## Direction cardinale la plus proche d'un vecteur : "s", "e", "n" ou "w".
static func direction_name(direction: Vector2) -> String:
	if absf(direction.x) > absf(direction.y):
		return "e" if direction.x > 0.0 else "w"
	return "s" if direction.y >= 0.0 else "n"
