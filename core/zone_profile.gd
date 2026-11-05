class_name ZoneProfile
extends Resource
## Type de zone où le train peut s'arrêter (plaine, forêt morte, casse...).
##
## Un profil = un fichier .tres dans data/zones/. Il ne décrit pas une carte
## précise mais des fourchettes : le ZoneGenerator tire au sort une zone
## différente à chaque arrêt, dans ces limites.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Biome (région) auquel ce type d'arrêt appartient : sol, décors, règle.
@export var biome: BiomeData
## Ce qu'on vient y chercher, en quelques mots : affiché sur l'aiguillage pour choisir
## son arrêt (ex. « Médicaments · beaucoup d'infectés »).
@export var specialty: String
## Chance relative d'être tirée comme prochain arrêt.
@export var weight: float = 1.0
@export var size_in_tiles: Vector2i = Vector2i(48, 28)
## Durée de l'arrêt en secondes (min, max).
@export var stop_duration: Vector2 = Vector2(80.0, 100.0)

@export_group("Sol")
@export_range(0.0, 1.0) var dirt_ratio: float = 0.1
@export_range(0.0, 1.0) var grass_variant_ratio: float = 0.35
## Nombre de zones infectées (min, max).
@export var infected_patches: Vector2i = Vector2i(1, 2)
## Rayon d'une zone infectée, en tuiles (min, max).
@export var infected_radius: Vector2 = Vector2(3.0, 6.0)
## Nappes de sol piégeux du biome (eau, glace, flaque toxique), (min, max).
@export var hazard_patches: Vector2i = Vector2i.ZERO
## Rayon d'une nappe de sol piégeux, en tuiles (min, max).
@export var hazard_radius: Vector2 = Vector2(2.0, 4.0)

@export_group("Objets (min, max)")
@export var wrecks: Vector2i = Vector2i(3, 5)
@export var dead_trees: Vector2i = Vector2i(4, 7)
@export var rocks: Vector2i = Vector2i(6, 10)
@export var herbs: Vector2i = Vector2i(8, 12)
@export var infected_herbs: Vector2i = Vector2i(4, 7)

@export_group("Points d'intérêt")
## Chance qu'un village abandonné (maisons en ruine, caches à fouiller) soit présent.
@export_range(0.0, 1.0) var village_chance: float = 0.3
## Chance qu'un refuge avec un survivant à recruter soit présent.
@export_range(0.0, 1.0) var refuge_chance: float = 0.4
## Chance qu'un marchand ambulant soit présent.
@export_range(0.0, 1.0) var merchant_chance: float = 0.3
## Nombre de petites rencontres isolées (sac abandonné...), (min, max).
@export var lone_events: Vector2i = Vector2i(0, 1)


@export_group("Ennemis")
## Nombre de chaque ennemi (id d'EnemyData -> (min, max)). Les infectés rôdent dans
## les zones violettes, les pilleurs dans les zones saines. Un ennemi n'apparaît qu'à
## partir de son min_stop.
@export var enemies: Dictionary[StringName, Vector2i] = {}


## Épaves de camion (il faut un chalumeau), (min, max).
@export var heavy_wrecks: Vector2i = Vector2i(0, 1)
## Objets propres à certains arrêts (id du générateur -> (min, max)) : &"barrel" (fûts
## chimiques), &"cache" (caisses à fouiller hors des villages).
@export var extras: Dictionary[StringName, Vector2i] = {}


## Fourchette (min, max) du nombre d'objets d'un type.
func count_range(kind: StringName) -> Vector2i:
	match kind:
		&"wreck":
			return wrecks
		&"heavy_wreck":
			return heavy_wrecks
		&"dead_tree":
			return dead_trees
		&"rock":
			return rocks
		&"herb":
			return herbs
		&"infected_herb":
			return infected_herbs
		_:
			if extras.has(kind):
				return extras[kind]
			return enemies.get(kind, Vector2i.ZERO)


## Nombre moyen d'ennemis attendus à cet arrêt (ceux déjà apparus à ce numéro d'arrêt).
func expected_enemies(stop_number: int) -> float:
	var total: float = 0.0
	for id: StringName in enemies:
		var enemy: EnemyData = EnemyCatalog.get_enemy(id)
		if enemy and stop_number >= enemy.min_stop:
			total += (enemies[id].x + enemies[id].y) / 2.0
	return total


## Danger affiché sur l'aiguillage : 0 faible, 1 moyen, 2 élevé.
func danger(stop_number: int) -> int:
	var expected: float = expected_enemies(stop_number)
	if expected >= 5.0:
		return 2
	return 1 if expected >= 3.0 else 0
