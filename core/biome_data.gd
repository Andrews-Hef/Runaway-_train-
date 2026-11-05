class_name BiomeData
extends Resource
## Un biome : la région que le train traverse (campagne, marais, ville, zone
## industrielle, toundra). Il donne son sol, ses décors, son ambiance et une règle.
##
## Les types d'arrêt (ZoneProfile) disent à quel biome ils appartiennent. La ligne
## change de biome à chaque gare refuge (GameState.REGIONS).
## Un biome = un fichier .tres dans data/biomes/.

## Règle propre au biome, appliquée par la zone d'arrêt.
enum Rule {
	NONE,
	## L'eau stagnante (sol piégeux) ralentit le joueur.
	MARSH,
	## Le froid fait perdre de la vie sans tenue chaude ; la glace (sol piégeux) fait glisser.
	COLD,
	## Fouiller une voiture peut déclencher une alarme qui attire les ennemis.
	CAR_ALARMS,
	## Les flaques toxiques (sol piégeux) brûlent, sauf avec une tenue étanche.
	TOXIC,
}

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var rule: Rule = Rule.NONE
## La règle en une phrase, annoncée à l'arrivée et sur l'aiguillage.
@export var rule_text: String
## Atlas du sol (96x16, même disposition que ground_placeholder.png) : sol A, sol B,
## sol secondaire, sol infecté, rails, sol piégeux. Généré par tools/gen_placeholders.py.
@export var ground_atlas: Texture2D
## Teinte de la lumière sur le monde (CanvasModulate). Blanc = aucune.
@export var ambient: Color = Color.WHITE
## Effet d'ambiance à l'écran : &"snow", &"spores", &"" pour aucun.
@export var weather: StringName
## Scènes propres au biome : type d'objet du générateur (&"dead_tree", &"wreck"...)
## -> scène qui le remplace (sapin enneigé, voiture de ville...).
@export var scenes: Dictionary[StringName, PackedScene] = {}


## Met le sol du biome sur une couche de tuiles (zone, trajet, intérieur du train) :
## le TileSet est copié pour ne pas changer celui des autres scènes.
static func apply_ground(layer: TileMapLayer, biome: BiomeData) -> void:
	if biome == null or biome.ground_atlas == null or layer.tile_set == null:
		return
	var tile_set: TileSet = layer.tile_set.duplicate(true)
	var source := tile_set.get_source(0) as TileSetAtlasSource
	if source:
		source.texture = biome.ground_atlas
	layer.tile_set = tile_set
