class_name MissionSim
extends RefCounted
## Mission d'équipage (mode gestion, grade Capitaine) : un équipier descend seul à
## l'arrêt pendant que le joueur reste à bord. L'arrêt est simulé, sans le jouer.
## Pur : modifie l'équipier et renvoie le résultat ; GameState l'applique.
##
## Il rapporte une part de ce que la zone offre (plus s'il est éclaireur ou fidèle, moins
## s'il est blessé ou fatigué), se blesse selon le danger, peut ramener l'infection sans
## le savoir, se fatigue beaucoup, et peut ne pas revenir.
##
## Ses stats et son équipement comptent : Force, arme et armure le protègent des coups,
## Adresse et outil le font rapporter plus, son sac aussi ; Endurance et masque limitent
## fatigue et infection ; Sang-froid le fait décrocher avant d'y laisser sa peau.

## Place dans son sac sans sac (2 cases de 5) ; un sac en ajoute (voir Loadout).
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
## Stats (3 = moyen) et équipement.
const SKILL_LOOT: float = 0.05
const TOOL_LOOT: float = 0.1
const STRENGTH_WOUNDS: float = 0.08
const WEAPON_WOUNDS: float = 0.06
const ARMOR_WOUNDS: float = 0.12
const WOUND_FACTOR_RANGE: Vector2 = Vector2(0.35, 1.4)
const ENDURANCE_FATIGUE: int = 5
const ENDURANCE_INFECTION: float = 0.07
## Sang-froid : il ne prend jamais plus de 100 − 10 × sang-froid PV en une mission
## (il décroche), mais rapporte alors moins.
const NERVE_CAP_PER_POINT: int = 10
const RETREAT_LOOT: float = 0.6


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
		+ (LOYAL_BONUS if CrewLife.is_loyal(member) else 0.0) + loot_bonus(member)
	efficiency *= member.health / 100.0 * (1.0 - member.fatigue / 200.0)
	var bag: int = bag_size(member)
	var total: int = 0
	for entry: Array in YIELDS:
		var count: Vector2i = zone.count_range(entry[0])
		var amount: int = roundi((count.x + count.y) / 2.0 * entry[2] * efficiency * rng.randf_range(0.7, 1.3))
		amount = mini(amount, bag - total)
		if amount > 0:
			result.loot[entry[1]] = amount
			total += amount
	var caution: float = SCOUT_CAUTION if member.role == &"scout" else 1.0
	var wounds: int = roundi(zone.expected_enemies(stop_number) * WOUNDS_PER_ENEMY * caution * wound_factor(member)
		* rng.randf_range(0.5, 1.5))
	# Sang-froid : il décroche avant d'y laisser sa peau, les mains moins pleines.
	var retreated: bool = wounds > wound_cap(member)
	if retreated:
		wounds = wound_cap(member)
		for id: StringName in result.loot:
			result.loot[id] = roundi(result.loot[id] * RETREAT_LOOT)
	var infection: int = roundi((zone.infected_patches.x + zone.infected_patches.y) / 2.0 * INFECTION_PER_PATCH
		* infection_factor(member) * rng.randf_range(0.5, 1.5))
	member.health = maxi(member.health - wounds, 0)
	member.fatigue = mini(member.fatigue + maxi(FATIGUE - ENDURANCE_FATIGUE * (member.endurance - 3), 0), 100)
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
		var retreat: String = " Ça tournait mal : il a décroché à temps." if retreated else ""
		result.lines.append("%s revient de : %s, avec %s%s.%s" % [member.display_name, zone.display_name, found, hurt, retreat])
	if horde:
		result.lines.append("Une horde a attaqué le train pendant ce temps : −%d %%." % roundi(HORDE_TRAIN_DAMAGE * 100.0))
	return result


## Ce que son adresse et son outil ajoutent à sa récolte.
static func loot_bonus(member: CrewMember) -> float:
	var tool: ItemData = member.loadout.get_item(ItemData.Slot.TOOL)
	return SKILL_LOOT * (member.skill - 3) + (TOOL_LOOT if tool else 0.0)


## Ce qu'il peut rapporter : 2 cases sans sac, plus avec (piles de BagSlots.STACK_SIZE).
static func bag_size(member: CrewMember) -> int:
	return BagSlots.max_items(member.loadout.capacity())


## Multiplie ses blessures : moins avec de la force, une arme, une armure.
static func wound_factor(member: CrewMember) -> float:
	var factor: float = 1.0 - STRENGTH_WOUNDS * (member.strength - 3) - WEAPON_WOUNDS * member.loadout.damage() \
		- ARMOR_WOUNDS * member.loadout.armor()
	return clampf(factor, WOUND_FACTOR_RANGE.x, WOUND_FACTOR_RANGE.y)


## Le plus de PV qu'il accepte de perdre avant de décrocher.
static func wound_cap(member: CrewMember) -> int:
	return 100 - NERVE_CAP_PER_POINT * member.nerve


## Multiplie l'infection ramenée : moins avec un masque, une tenue protectrice, de l'endurance.
static func infection_factor(member: CrewMember) -> float:
	return maxf((1.0 - member.loadout.protection()) * (1.2 - ENDURANCE_INFECTION * member.endurance), 0.0)
