class_name EncounterData
extends Resource
## Une rencontre pendant une sortie : un survivant, un marchand, un sac abandonné...
##
## Une rencontre = un fichier .tres dans data/encounters/ : ajouter une rencontre
## ne demande pas de code.

@export var id: StringName
@export var title: String
@export_multiline var text: String
@export var choices: Array[EncounterChoice] = []
## Texte du point d'intérêt dans le HUD (« Parler », « Examiner »...).
@export var prompt: String = "Parler"
## true : on peut choisir plusieurs fois (un marchand). false : un seul choix, puis c'est fini.
@export var repeatable: bool = false
