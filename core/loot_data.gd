class_name LootData
extends Resource
## Un type de ressource récoltable (ferraille, bois, plante...).
## Une ressource = un fichier .tres dans data/loot/ : ajouter un type ne demande pas de code.

## Identifiant stable, utilisé dans les sauvegardes et le butin.
@export var id: StringName
@export var display_name: String
## Couleur du compteur dans le HUD, en attendant les icônes.
@export var color: Color = Color.WHITE
## Ressource infectée : vaut plus, mais expose le joueur quand il la récolte.
@export var infected: bool = false
