class_name ItemCatalog
## Tous les équipements du jeu, dans l'ordre d'affichage de l'atelier.

const ALL: Array[ItemData] = [
	preload("res://data/items/outfit_worn.tres"),
	preload("res://data/items/outfit_padded.tres"),
	preload("res://data/items/outfit_hazmat.tres"),
	preload("res://data/items/mask_worn.tres"),
	preload("res://data/items/mask_filter.tres"),
	preload("res://data/items/bag_small.tres"),
	preload("res://data/items/bag_hiking.tres"),
	preload("res://data/items/bag_military.tres"),
	preload("res://data/items/tool_crowbar.tres"),
	preload("res://data/items/tool_hatchet.tres"),
	preload("res://data/items/tool_shears.tres"),
	preload("res://data/items/weapon_pipe.tres"),
	preload("res://data/items/weapon_machete.tres"),
	preload("res://data/items/weapon_axe.tres"),
]


static func starters() -> Array[ItemData]:
	var list: Array[ItemData] = []
	for item: ItemData in ALL:
		if item.starter:
			list.append(item)
	return list


static func craftables() -> Array[ItemData]:
	var list: Array[ItemData] = []
	for item: ItemData in ALL:
		if item.is_craftable():
			list.append(item)
	return list


static func get_item(id: StringName) -> ItemData:
	for item: ItemData in ALL:
		if item.id == id:
			return item
	return null
