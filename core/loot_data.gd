class_name LootData
extends Resource
## Un type de ressource récoltable (ferraille, bois, plante...).
## Une ressource = un fichier .tres dans data/loot/ : ajouter un type ne demande pas de code.

## Identifiant stable, utilisé dans les sauvegardes et le butin.
@export var id: StringName
@export var display_name: String
## Une ligne pour l'inventaire (à quoi ça sert). Les médicaments la complètent seuls.
@export_multiline var description: String = ""
## Couleur du texte de la ressource (listes, bilan).
@export var color: Color = Color.WHITE
## Icône 12x12 (HUD, menus, bilan). Générées par tools/gen_icons.py.
@export var icon: Texture2D
## Ressource infectée : vaut plus, mais expose le joueur quand il la récolte.
@export var infected: bool = false
## Rare : n'apparaît dans le HUD qu'une fois trouvée.
@export var rare: bool = false
## Médicament : infection retirée quand on le prend (0.2 = −20 points). 0 = pas un médicament.
@export_range(0.0, 1.0) var cure: float = 0.0
## Énergie qu'une unité donne en brûlant dans la chaudière (0 : ne brûle pas). Voir EngineRules.
@export var fuel: int = 0


func is_medicine() -> bool:
	return cure > 0.0


## Texte de l'inventaire : la description, puis l'effet du médicament ou du combustible.
func describe() -> String:
	var effect: String = ""
	if cure > 0.0:
		effect = "Médicament : l'infection baisse de %d %%." % roundi(cure * 100.0)
	elif fuel > 0:
		effect = "Chaudière : %d d'énergie." % fuel
	if effect.is_empty():
		return description
	return effect if description.is_empty() else description + " " + effect
