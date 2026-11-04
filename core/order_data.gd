class_name OrderData
extends Resource
## Un type d'ordre du capitaine. Le nombre exact est tiré à chaque arrêt.
##
## Un ordre = un fichier .tres dans data/orders/, listé dans CaptainOrders.ORDERS.

enum Kind {
	COLLECT, ## ramener `amount` d'une ressource (target = id de LootData)
	COLLECT_ANY, ## ramener au moins `amount` ressources, toutes confondues
	ELIMINATE, ## éliminer `amount` ennemis d'une faction (target = &"infected" ou &"raider")
	LOW_EXPOSURE, ## revenir avec moins de `amount` % d'exposition
}

@export var id: StringName
## Texte de l'ordre ; {n} est remplacé par le nombre tiré.
@export var title: String
@export var kind: Kind = Kind.COLLECT
@export var target: StringName
## Fourchette (min, max) du nombre demandé.
@export var amount: Vector2i = Vector2i(4, 6)
## Mérite gagné si l'ordre est rempli.
@export var merit: int = 15
@export var min_stop: int = 1
