class_name EnemyCatalog
## Tous les ennemis du jeu, par faction puis par profil (infanterie, rampant, tireur, lourd).
## L'ordre compte pour le générateur de zones (même graine = mêmes ennemis).

const ALL: Array[EnemyData] = [
	preload("res://data/enemies/infected.tres"),
	preload("res://data/enemies/infected_crawler.tres"),
	preload("res://data/enemies/infected_spitter.tres"),
	preload("res://data/enemies/infected_bloated.tres"),
	preload("res://data/enemies/raider.tres"),
	preload("res://data/enemies/raider_lurker.tres"),
	preload("res://data/enemies/raider_marksman.tres"),
	preload("res://data/enemies/raider_brute.tres"),
]


static func get_enemy(id: StringName) -> EnemyData:
	for enemy: EnemyData in ALL:
		if enemy.id == id:
			return enemy
	return null
