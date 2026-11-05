class_name ExpeditionResult
extends RefCounted
## Résultat d'une sortie hors du train.
##
## Le mode action (sortie jouée) remplit cet objet. Plus tard, l'expédition
## simulée (délégation) produira le même objet : le reste du jeu n'a pas
## besoin de savoir comment la sortie s'est déroulée.

## Butin rapporté : id de LootData -> quantité.
var loot: Dictionary[StringName, int] = {}
## Infection au départ de la sortie (elle continue celle des arrêts précédents).
var exposure_start: float = 0.0
## Infection à la fin de la sortie (0 à 1). Voir Infection.
var exposure: float = 0.0
## Le joueur est-il remonté à bord avant le départ du train ?
var boarded: bool = false
## Le joueur est tombé au combat (il n'est donc pas remonté à bord).
var fell: bool = false
## L'infection a atteint 100 % : le joueur a rejoint la ruche.
var turned: bool = false
## Plans trouvés pendant la sortie (ids), rangés dans le train au retour.
var plans: Array[StringName] = []
## Personnes recrutées pendant la sortie : elles montent à bord avec le joueur.
var recruits: Array[CrewMember] = []
## Équipements trouvés ou achetés pendant la sortie (rangés dans le train au retour).
var items: Array[ItemData] = []
## Ressources laissées sur le quai au retour, faute de place dans le stock du train.
var left_behind: Dictionary[StringName, int] = {}
## Ennemis éliminés : id d'EnemyData -> nombre.
var kills: Dictionary[StringName, int] = {}
## Rempli au retour (GameState.record_expedition) : l'ordre du capitaine, le mérite gagné,
## et les grades obtenus.
var order_completed: bool = false
## Une horde a attaqué pendant l'arrêt, et tous ses membres ont été éliminés.
var horde_repelled: bool = false
var merit_gained: int = 0
var promotions: Array[GradeData] = []


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


func record_kill(enemy: EnemyData) -> void:
	kills[enemy.id] = kills.get(enemy.id, 0) + 1


## Ennemis éliminés d'une faction (&"infected" ou &"raider").
func kills_of_faction(faction: StringName) -> int:
	var total: int = 0
	for id: StringName in kills:
		var enemy: EnemyData = EnemyCatalog.get_enemy(id)
		if enemy and enemy.faction_name() == faction:
			total += kills[id]
	return total


## Mérite des ennemis éliminés.
func kill_merit() -> int:
	var total: int = 0
	for id: StringName in kills:
		var enemy: EnemyData = EnemyCatalog.get_enemy(id)
		if enemy:
			total += enemy.merit * kills[id]
	return total


func get_amount(id: StringName) -> int:
	return loot.get(id, 0)


func total_items() -> int:
	var total: int = 0
	for amount: int in loot.values():
		total += amount
	return total


## Infection prise pendant cette sortie (0 à 1).
func exposure_gained() -> float:
	return maxf(exposure - exposure_start, 0.0)
