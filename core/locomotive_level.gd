class_name LocomotiveLevel
extends Resource
## Un niveau de la locomotive : combien de voitures elle peut tirer.
##
## Un niveau = un fichier .tres dans data/locomotive/, listé dans TrainRules.LEVELS.

@export var level: int = 1
## Voitures tirées au maximum, cabine comprise.
@export var max_cars: int = 5
## Matériaux pour passer à ce niveau depuis le précédent (vide pour le niveau 1).
@export var cost: Dictionary[StringName, int] = {}
