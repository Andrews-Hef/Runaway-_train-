class_name RefugeOffer
extends Resource
## Une offre d'une gare refuge : un échange ou une recrue.
##
## Elle se paie avec le stock du train (on est à quai, pas besoin de porter).

@export var label: String
## Matériaux pris dans le stock.
@export var cost: Dictionary[StringName, int] = {}
## Matériaux ajoutés au stock.
@export var reward: Dictionary[StringName, int] = {}

@export_group("Recrue")
## Rôle de la recrue (vide = pas de recrue). Les recrues de la gare sortent de
## quarantaine : jamais infectées.
@export var recruit_role: StringName
@export var recruit_role_label: String


func recruits() -> bool:
	return recruit_role != &""
