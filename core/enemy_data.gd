class_name EnemyData
extends Resource
## Un type d'ennemi : infecté (membre de la ruche), pilleur...
##
## Un type = un fichier .tres dans data/enemies/. Le comportement est le même pour
## tous (Enemy) ; ce sont ces réglages qui les distinguent.

@export var id: StringName
@export var display_name: String
@export var frames: SpriteFrames

@export_group("Vie et déplacement")
@export var max_health: int = 3
## Vitesse en errance et en poursuite (px/s ; le joueur marche à 72).
@export var wander_speed: float = 18.0
@export var chase_speed: float = 40.0
## Distance à laquelle il repère le joueur.
@export var sight_range: float = 80.0
## Il abandonne la poursuite au-delà de cette distance de son point de départ.
@export var leash_range: float = 180.0

@export_group("Attaque")
## Distance à laquelle il frappe.
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

@export_group("Butin")
## Ressources lâchées à sa mort (en plus de ce qu'il a volé).
@export var drop: Dictionary[StringName, int] = {}
