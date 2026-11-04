class_name EnemyData
extends Resource
## Un type d'ennemi. Chaque faction (infectés, pilleurs) a les quatre profils :
##
## - INFANTERIE : poursuit et frappe au corps à corps.
## - LOURD : lent, beaucoup de vie, ne recule pas quand on le frappe, gros coup
##   long à venir (zone rouge au sol).
## - TIREUR : garde ses distances, vise (ligne de visée), tire un projectile ;
##   fuit si on s'approche.
## - RAMPANT : se traîne au sol, plaque le joueur et ne le lâche plus : il faut
##   marteler Coup pour se dégager, en perdant de la vie.
##
## Un type = un fichier .tres dans data/enemies/. Le comportement est dans Enemy.

enum Archetype { INFANTRY, HEAVY, SNIPER, CRAWLER }
enum Faction { INFECTED, RAIDER }

@export var id: StringName
@export var display_name: String
@export var faction: Faction = Faction.INFECTED
@export var archetype: Archetype = Archetype.INFANTRY
@export var frames: SpriteFrames
## Décalage du sprite (= -pivot de td2d, pieds au sol).
@export var sprite_offset: Vector2 = Vector2(-18, -35)
## Premier arrêt où il peut apparaître (les plus dangereux arrivent plus tard).
@export var min_stop: int = 1
## Mérite gagné quand on l'élimine.
@export var merit: int = 2

@export_group("Vie et déplacement")
@export var max_health: int = 3
## Vitesse en errance et en poursuite (px/s ; le joueur marche à 72).
@export var wander_speed: float = 18.0
@export var chase_speed: float = 40.0
## Distance à laquelle il repère le joueur.
@export var sight_range: float = 80.0
## Il abandonne la poursuite au-delà de cette distance de son point de départ.
@export var leash_range: float = 180.0
## Il ne recule pas quand on le frappe (lourds).
@export var stagger_immune: bool = false

@export_group("Attaque")
## Distance à laquelle il frappe (ou commence à viser, pour un tireur).
@export var attack_range: float = 14.0
## Temps d'élan avant le coup (le joueur peut l'esquiver en s'éloignant).
@export var windup: float = 0.45
## Temps de repos après un coup.
@export var cooldown: float = 0.9
@export var damage: int = 1
## Exposition ajoutée au joueur quand le coup porte (0 à 1, avant protection).
@export_range(0.0, 1.0) var exposure_on_hit: float = 0.0
## Ressources volées dans le sac du joueur quand le coup porte.
@export var steal_amount: int = 0
## Recul donné au joueur quand le coup porte (px/s).
@export var hit_knockback: float = 160.0

@export_group("Tireur")
## Il recule si le joueur s'approche à moins de cette distance.
@export var flee_range: float = 50.0
@export var projectile_speed: float = 200.0
## Ligne de visée visible pendant l'élan (fusil) ; sinon le tir part sans prévenir.
@export var shows_aim_line: bool = false
@export var projectile_color: Color = Color(1.0, 0.9, 0.5)

@export_group("Rampant")
## Coups de Coup à marteler pour se dégager.
@export var mash_needed: int = 8
## Intervalle entre deux morsures pendant qu'il tient le joueur (secondes).
@export var grab_tick: float = 1.0

@export_group("Butin")
## Ressources lâchées à sa mort (en plus de ce qu'il a volé).
@export var drop: Dictionary[StringName, int] = {}


## &"infected" ou &"raider" (pour les ordres « Élimine N pilleurs »).
func faction_name() -> StringName:
	return &"infected" if faction == Faction.INFECTED else &"raider"
