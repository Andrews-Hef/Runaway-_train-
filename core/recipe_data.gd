class_name RecipeData
extends Resource
## Une recette qui transforme des ressources en d'autres ressources : plaques de
## métal à l'atelier, médicaments à l'infirmerie...
## (Les équipements ont leur recette dans ItemData.)
##
## Une recette = un fichier .tres dans data/recipes/, listé dans RecipeCatalog.ALL.

enum Station { WORKBENCH, INFIRMARY }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Où on la prépare : l'établi de l'atelier, ou l'infirmerie (voiture à construire).
@export var station: Station = Station.WORKBENCH
## Matériaux pris dans le stock.
@export var cost: Dictionary[StringName, int] = {}
## Ce qui est ajouté au stock.
@export var output: Dictionary[StringName, int] = {}
## Plan à étudier avant de pouvoir la préparer (vide = connue dès le départ).
@export var plan: StringName
