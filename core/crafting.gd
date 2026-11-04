class_name Crafting
extends RefCounted
## Fabrication à l'atelier du train, avec les matériaux du stock.
##
## Pur : on lui passe le stock et la liste des objets possédés.


## Ce qui manque dans le stock pour fabriquer : id -> quantité (vide = possible).
static func missing(item: ItemData, storage: Dictionary[StringName, int]) -> Dictionary[StringName, int]:
	var lacking: Dictionary[StringName, int] = {}
	for id: StringName in item.recipe:
		var short: int = item.recipe[id] - storage.get(id, 0)
		if short > 0:
			lacking[id] = short
	return lacking


static func can_craft(item: ItemData, storage: Dictionary[StringName, int], owned: Array[ItemData]) -> bool:
	return item.is_craftable() and not item in owned and missing(item, storage).is_empty()


## Fabrique l'objet : retire les matériaux du stock et l'ajoute aux objets possédés.
static func craft(item: ItemData, storage: Dictionary[StringName, int], owned: Array[ItemData]) -> bool:
	if not can_craft(item, storage, owned):
		return false
	for id: StringName in item.recipe:
		var left: int = storage[id] - item.recipe[id]
		if left > 0:
			storage[id] = left
		else:
			storage.erase(id)
	owned.append(item)
	return true
