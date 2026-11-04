class_name GradeData
extends Resource
## Un grade, de Recrue à Capitaine. On l'obtient en cumulant du mérite (ordres du
## capitaine réussis, ennemis éliminés). À chaque promotion, on choisit un talent.
##
## Un grade = un fichier .tres dans data/grades/, listé dans Career.GRADES.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Mérite total à atteindre pour ce grade.
@export var merit_needed: int = 0
## Les deux talents proposés à la promotion (vide pour Recrue).
@export var perks: Array[PerkData] = []
