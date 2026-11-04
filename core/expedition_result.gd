class_name ExpeditionResult
extends RefCounted
## Résultat d'une sortie hors du train.
##
## Le mode action (sortie jouée) remplit cet objet. Plus tard, l'expédition
## simulée (délégation) produira le même objet : le reste du jeu n'a pas
## besoin de savoir comment la sortie s'est déroulée.

## Butin rapporté : id de LootData -> quantité.
var loot: Dictionary[StringName, int] = {}
## Exposition à l'infection accumulée pendant la sortie (0 à 1).
var exposure: float = 0.0
## Le joueur est-il remonté à bord avant le départ du train ?
var boarded: bool = false
## Personnes recrutées pendant la sortie : elles montent à bord avec le joueur.
var recruits: Array[CrewMember] = []
## Équipements trouvés ou achetés pendant la sortie (rangés dans le train au retour).
var items: Array[ItemData] = []


func add_loot(id: StringName, amount: int) -> void:
	if amount <= 0:
		return
	loot[id] = get_amount(id) + amount


## Retire une quantité (échange, paiement). Renvoie false si le joueur n'en a pas assez.
func remove_loot(id: StringName, amount: int) -> bool:
	if amount <= 0:
		return true
	var current: int = get_amount(id)
	if current < amount:
		return false
	if current == amount:
		loot.erase(id)
	else:
		loot[id] = current - amount
	return true


func get_amount(id: StringName) -> int:
	return loot.get(id, 0)


func total_items() -> int:
	var total: int = 0
	for amount: int in loot.values():
		total += amount
	return total


## Probabilité d'être infecté au retour, selon la protection portée (0 à 1).
func infection_risk(protection: float = 0.0) -> float:
	return clampf(exposure * (1.0 - protection), 0.0, 1.0)
