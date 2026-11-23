class_name RefugeData
extends Resource
## Une gare refuge : ville fortifiée sur la ligne, où le train s'arrête tous les
## GameState.REFUGE_EVERY arrêts. Zone sûre : pas d'infection, pas de chrono.
##
## Une gare = un fichier .tres dans data/refuges/, listé dans GameState.REFUGES.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Ressources qui abondent ici : le marchand les vend et les reprend moins cher (Barter).
@export var abundant: Array[StringName] = []
## Ressources qui manquent ici : il les paie plus cher, et en a peu.
@export var scarce: Array[StringName] = []
## Échanges du comptoir (répétables).
@export var trades: Array[RefugeOffer] = []
## Recrues du bureau de quarantaine (une fois chacune par passage).
@export var recruits: Array[RefugeOffer] = []
