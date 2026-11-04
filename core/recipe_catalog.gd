class_name RecipeCatalog
## Toutes les recettes de transformation, dans l'ordre d'affichage.

const ALL: Array[RecipeData] = [
	preload("res://data/recipes/metal_plate.tres"),
	preload("res://data/recipes/chemicals.tres"),
	preload("res://data/recipes/antibiotics.tres"),
	preload("res://data/recipes/serum.tres"),
	preload("res://data/recipes/vaccine.tres"),
]


static func for_station(station: RecipeData.Station) -> Array[RecipeData]:
	var list: Array[RecipeData] = []
	for recipe: RecipeData in ALL:
		if recipe.station == station:
			list.append(recipe)
	return list
