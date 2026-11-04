class_name EncounterChoice
extends Resource
## Un choix proposé pendant une rencontre : échanger, recruter, fouiller, partir...
##
## Tout est optionnel : un choix « Partir » n'a ni coût ni gain.

## Texte du bouton.
@export var label: String
## « Partir » : ferme la rencontre sans rien faire ; on pourra revenir plus tard.
@export var leave: bool = false
## Ce que le joueur donne, pris dans ce qu'il porte : id de LootData -> quantité.
@export var cost: Dictionary[StringName, int] = {}
## Ce que le joueur reçoit : id de LootData -> quantité.
@export var reward: Dictionary[StringName, int] = {}
## Gain aléatoire en plus de `reward` : une ressource tirée parmi `random_reward_pool`.
@export var random_reward_pool: Array[StringName] = []
## Quantité du gain aléatoire (min, max).
@export var random_reward_amount: Vector2i = Vector2i.ZERO
## Exposition à l'infection ajoutée au joueur.
@export_range(0.0, 1.0) var exposure: float = 0.0

@export_group("Recrutement")
## Rôle de la personne recrutée. Vide = ce choix ne recrute personne.
@export var recruit_role: StringName
@export var recruit_role_label: String
## Probabilité que la recrue soit infectée (caché au joueur).
@export_range(0.0, 1.0) var recruit_infection_chance: float = 0.0

@export_group("Résultat")
## Texte affiché après le choix.
@export_multiline var outcome_text: String


func recruits() -> bool:
	return recruit_role != &""
