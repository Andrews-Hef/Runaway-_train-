class_name BlueprintData
extends Resource
## Un plan : on le trouve en fouillant (caisses, armoires, sacs), on l'achète à un
## marchand ou en gare, puis on l'étudie à l'atelier. Étudié, il débloque des
## recettes, des équipements ou des voitures (ceux dont le champ `plan` vaut son id).
##
## Les prérequis en font un arbre : on n'étudie pas la Distillerie sans la Chimie.
## Un plan = un fichier .tres dans data/plans/, listé dans BlueprintCatalog.ALL.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Ressources dépensées pour l'étudier.
@export var research_cost: Dictionary[StringName, int] = {}
## Plans à avoir étudiés avant (ids).
@export var requires: Array[StringName] = []
## Premier arrêt où on peut le trouver par hasard.
@export var min_stop: int = 1
## Effet propre au plan, qui n'est ni une recette ni une voiture
## (ex. l'interphone relie les postes du train). Affiché dans « Débloque ».
@export var effect_text: String
