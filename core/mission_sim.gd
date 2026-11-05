class_name MissionSim
extends RefCounted
## Mission d'équipage (mode gestion, grade Capitaine) : un équipier descend seul à
## l'arrêt pendant que le joueur reste à bord. L'arrêt est simulé, sans le jouer.
## Pur : modifie l'équipier et renvoie le résultat ; GameState l'applique.
##
## Il rapporte une part de ce que la zone offre (plus s'il est éclaireur ou fidèle, moins
## s'il est blessé ou fatigué), se blesse selon le danger, peut ramener l'infection sans
## le savoir, se fatigue beaucoup, et peut ne pas revenir.

## Place dans son sac.
const BAG: int = 10
## Part de la zone qu'il récolte, et bonus.
const EFFICIENCY: float = 0.5
const SCOUT_BONUS: float = 0.25
const LOYAL_BONUS: float = 0.15
## Ce que donne chaque objet de la zone (en moyenne), par ressource.
const YIELDS: Array[Array] = [
	[&"wreck", &"scrap", 2.0],
	[&"dead_tree", &"wood", 1.5],
	[&"herb", &"herb", 1.0],
	[&"infected_herb", &"infected_herb", 0.8],
	[&"barrel", &"chemicals", 1.0],
	[&"cache", &"cloth", 1.0],
]
## Blessures par ennemi attendu (PV), moins pour un éclaireur qui sait les éviter.
const WOUNDS_PER_ENEMY: float = 6.0
const SCOUT_CAUTION: float = 0.6
## Infection par zone infectée.
const INFECTION_PER_PATCH: float = 5.0
const FATIGUE: int = 40
## On lui confie une mission : un peu de confiance.
const TRUST_GAIN: int = 5
## Une horde pendant la mission : le train sans défenseur s'abîme.
const HORDE_TRAIN_DAMAGE: float = 0.1


class Result:
	var loot: Dictionary[StringName, int] = {}
	var lines: Array[String] = []
	var died: bool = false
	var horde: bool = false


## Peut-il partir en mission ? Même règle que pour travailler.
static func can_go(member: CrewMember) -> bool:
	return CrewLife.can_work(member)


static func run(member: CrewMember, zone: ZoneProfile, stop_number: int, rng: RandomNumberGenerator,
		horde: bool = false) -> Result:
	var result := Result.new()
	var efficiency: float = EFFICIENCY + (SCOUT_BONUS if member.role == &"scout" else 0.0) \
		+ (LOYAL_BONUS if CrewLife.is_loyal(member) else 0.0)
	efficiency *= member.health / 100.0 * (1.0 - member.fatigue / 200.0)
	var total: int = 0
	for entry: Array in YIELDS:
		var count: Vector2i = zone.count_range(entry[0])
		var amount: int = roundi((count.x + count.y) / 2.0 * entry[2] * efficiency * rng.randf_range(0.7, 1.3))
		amount = mini(amount, BAG - total)
		if amount > 0:
			result.loot[entry[1]] = amount
			total += amount
	var caution: float = SCOUT_CAUTION if member.role == &"scout" else 1.0
	var wounds: int = roundi(zone.expected_enemies(stop_number) * WOUNDS_PER_ENEMY * caution * rng.randf_range(0.5, 1.5))
	var infection: int = roundi((zone.infected_patches.x + zone.infected_patches.y) / 2.0 * INFECTION_PER_PATCH * rng.randf_range(0.5, 1.5))
	member.health = maxi(member.health - wounds, 0)
	member.fatigue = mini(member.fatigue + FATIGUE, 100)
	member.trust = mini(member.trust + TRUST_GAIN, 100)
	if infection > 0:
		member.infection = mini(member.infection + infection, 99)
		member.infected = true
	result.horde = horde
	if member.health <= 0:
		result.died = true
		result.loot.clear()
		result.lines.append("%s ne revient pas de : %s." % [member.display_name, zone.display_name])
	else:
		var found: String = MenuKit.describe_amounts(result.loot) if not result.loot.is_empty() else "rien"
		var hurt: String = " (blessé : −%d PV)" % wounds if wounds > 0 else ""
		result.lines.append("%s revient de : %s, avec %s%s." % [member.display_name, zone.display_name, found, hurt])
	if horde:
		result.lines.append("Une horde a attaqué le train pendant ce temps : −%d %%." % roundi(HORDE_TRAIN_DAMAGE * 100.0))
	return result
