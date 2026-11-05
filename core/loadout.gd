class_name Loadout
extends RefCounted
## Ce que le joueur porte : un équipement par emplacement, et les effets cumulés.
##
## Pur : aucune scène. GameState en garde un ; la zone d'arrêt lit ses effets.

## Protection maximale : même bien équipé, sortir n'est jamais sans risque.
const MAX_PROTECTION: float = 0.8
## Capacité de transport sans sac.
const BASE_CAPACITY: int = 6

## Emplacement (ItemData.Slot) -> équipement porté.
var equipped: Dictionary[int, ItemData] = {}


func equip(item: ItemData) -> void:
	equipped[item.slot] = item


func unequip(slot: ItemData.Slot) -> void:
	equipped.erase(slot)


func get_item(slot: ItemData.Slot) -> ItemData:
	return equipped.get(slot, null)


func protection() -> float:
	var total: float = 0.0
	for item: ItemData in equipped.values():
		total += item.protection
	return minf(total, MAX_PROTECTION)


## Dégâts en moins à chaque coup reçu (tenue, masque).
func armor() -> int:
	var total: int = 0
	for item: ItemData in equipped.values():
		total += item.armor
	return total


## Dégâts vraiment reçus après l'armure : il en reste toujours au moins 1.
static func damage_after_armor(damage: int, armor_value: int) -> int:
	return maxi(damage - armor_value, 1) if damage > 0 else 0


func capacity() -> int:
	var bag: ItemData = get_item(ItemData.Slot.BAG)
	return bag.capacity if bag and bag.capacity > 0 else BASE_CAPACITY


## Multiplicateur de vitesse de récolte pour un type d'objet (1.0 = normal).
func harvest_speed_for(tag: StringName) -> float:
	var tool: ItemData = get_item(ItemData.Slot.TOOL)
	if tool and tag in tool.harvest_tags:
		return tool.harvest_speed
	return 1.0


## Un équipement porté protège-t-il de cette règle de biome (&"cold", &"toxic") ?
func resists(tag: StringName) -> bool:
	for item: ItemData in equipped.values():
		if tag in item.resists:
			return true
	return false


func damage() -> int:
	var weapon: ItemData = get_item(ItemData.Slot.WEAPON)
	return weapon.damage if weapon else 0


## Résumé d'une ligne pour l'interface.
func describe() -> String:
	return "Armure %d · Protection %d %% · Sac %d · Dégâts %d" % [armor(), roundi(protection() * 100.0), capacity(), damage()]
