class_name ItemData
extends Resource
## Un équipement : tenue, masque, sac, outil ou arme.
##
## Un équipement = un fichier .tres dans data/items/. Il se fabrique à
## l'atelier du train (si `recipe` n'est pas vide) ou se trouve en sortie.

enum Slot { OUTFIT, MASK, BAG, TOOL, WEAPON }

## Nom de chaque emplacement, pour l'interface.
const SLOT_NAMES: Array[String] = ["Tenue", "Masque", "Sac", "Outil", "Arme"]

@export var id: StringName
@export var display_name: String
## Icône 12x12 (atelier, inventaire, barre du HUD). Générées par tools/gen_icons.py.
@export var icon: Texture2D
@export_multiline var description: String
@export var slot: Slot = Slot.OUTFIT

@export_group("Effets")
## Réduit l'exposition reçue (0 à 1). Tenue et masque s'additionnent.
@export_range(0.0, 1.0) var protection: float = 0.0
## Armure : dégâts en moins à chaque coup reçu (il en reste toujours au moins 1).
@export var armor: int = 0
## Nombre de ressources qu'on peut porter pendant une sortie (sacs).
@export var capacity: int = 0
## Types d'objets récoltés plus vite avec cet outil : &"scrap", &"wood", &"plant", &"cache".
@export var harvest_tags: Array[StringName] = []
## Multiplicateur de vitesse de récolte sur ces objets (1.8 = 80 % plus vite).
@export var harvest_speed: float = 1.0
## Dégâts au combat (armes).
@export var damage: int = 0
## Protège d'une règle de biome : &"cold" (tenue chaude, toundra), &"toxic" (tenue
## étanche, flaques de la zone industrielle).
@export var resists: Array[StringName] = []
## Extraction : en récoltant cette ressource (id de LootData), on obtient aussi `extra_loot`
## (ex. le kit de chimie tire des produits chimiques des plantes infectées).
@export var extra_from: StringName
@export var extra_loot: Dictionary[StringName, int] = {}

@export_group("Fabrication")
## Matériaux à prendre dans le stock du train. Vide = ne se fabrique pas.
@export var recipe: Dictionary[StringName, int] = {}
## Équipement de départ, porté dès le début de la partie.
@export var starter: bool = false
## Plan à étudier avant de pouvoir le fabriquer (vide = recette connue).
@export var plan: StringName


func slot_name() -> String:
	return SLOT_NAMES[slot]


func is_craftable() -> bool:
	return not recipe.is_empty()


## Résumé des effets, ex. « Protection 15 % » ou « Sac 20 ».
func describe_effects() -> String:
	var parts: PackedStringArray = []
	if armor > 0:
		parts.append("Armure %d" % armor)
	if protection > 0.0:
		parts.append("Protection %d %%" % roundi(protection * 100.0))
	if capacity > 0:
		parts.append("Sac %d" % capacity)
	if not harvest_tags.is_empty() and harvest_speed > 1.0:
		parts.append("Récolte +%d %%" % roundi((harvest_speed - 1.0) * 100.0))
	if damage > 0:
		parts.append("Dégâts %d" % damage)
	if &"heavy_wreck" in harvest_tags:
		parts.append("Découpe les épaves de camion")
	if not extra_loot.is_empty():
		parts.append("Extrait des produits chimiques")
	if &"cold" in resists:
		parts.append("Tient chaud")
	if &"toxic" in resists:
		parts.append("Étanche aux flaques toxiques")
	return " · ".join(parts) if not parts.is_empty() else "Aucun effet"
