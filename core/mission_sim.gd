class_name MissionSim
extends RefCounted
## Mission d'équipage (mode gestion, grade Capitaine) : un équipier descend seul à
## l'arrêt pendant que le joueur reste à bord. L'arrêt est simulé, sans le jouer.
## Équipier de sortie (à partir de Caporal) : il descend AVEC le joueur, hors de vue, et
## le rejoint au train avec sa part (run_companion).
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
## Équipier de sortie : part du butin d'une mission, part du danger, fatigue, confiance.
const COMPANION_LOOT: float = 0.5
const COMPANION_DANGER: float = 0.5
const COMPANION_FATIGUE: int = 20
const COMPANION_TRUST: int = 2


class Result:
	var loot: Dictionary[StringName, int] = {}
	var lines: Array[String] = []
	var died: bool = false
	var horde: bool = false
	var wounds: int = 0
	var retreated: bool = false


## Peut-il partir en mission ? Même règle que pour travailler.
static func can_go(member: CrewMember) -> bool:
	return CrewLife.can_work(member)


static func run(member: CrewMember, zone: ZoneProfile, stop_number: int, rng: RandomNumberGenerator,
		horde: bool = false) -> Result:
	var result: Result = _simulate(member, zone, stop_number, rng, 1.0, 1.0, FATIGUE, TRUST_GAIN)
	result.horde = horde
	if result.died:
		result.lines.append("%s ne revient pas de : %s." % [member.display_name, zone.display_name])
	else:
		var found: String = MenuKit.describe_amounts(result.loot) if not result.loot.is_empty() else "rien"
		var hurt: String = " (blessé : −%d PV)" % result.wounds if result.wounds > 0 else ""
		var retreat: String = " Ça tournait mal : il a décroché à temps." if result.retreated else ""
		result.lines.append("%s revient de : %s, avec %s%s.%s" % [member.display_name, zone.display_name, found, hurt, retreat])
	if horde:
		result.lines.append("Une horde a attaqué le train pendant ce temps : −%d %%." % roundi(HORDE_TRAIN_DAMAGE * 100.0))
	return result


## Équipier de sortie : il descend avec le joueur, fouille de son côté (on ne le voit
## pas) et le rejoint au train. Moitié moins de butin qu'en mission, autant que le joueur
## est resté (`share` : part de l'arrêt passée dehors, 0 à 1), et moitié moins de danger
## (le joueur attire les ennemis).
static func run_companion(member: CrewMember, zone: ZoneProfile, stop_number: int, rng: RandomNumberGenerator,
		share: float) -> Result:
	var result: Result = _simulate(member, zone, stop_number, rng, COMPANION_LOOT * clampf(share, 0.0, 1.0),
		COMPANION_DANGER * clampf(share, 0.2, 1.0), COMPANION_FATIGUE, COMPANION_TRUST)
	if result.died:
		result.lines.append("%s ne revient pas. On l'a attendu jusqu'au sifflet." % member.display_name)
	else:
		var hurt: String = " (blessé : −%d PV)" % result.wounds if result.wounds > 0 else ""
		var retreat: String = " Ça tournait mal : il a décroché à temps." if result.retreated else ""
		result.lines.append("%s te rejoint au train%s.%s" % [member.display_name, hurt, retreat])
	return result


## Le cœur commun : ce qu'il récolte, ses blessures, l'infection, la fatigue.
## `loot_scale` et `danger_scale` : 1 pour une mission.
static func _simulate(member: CrewMember, zone: ZoneProfile, stop_number: int, rng: RandomNumberGenerator,
		loot_scale: float, danger_scale: float, fatigue: int, trust: int) -> Result:
	var result := Result.new()
	var efficiency: float = EFFICIENCY + (SCOUT_BONUS if member.role == &"scout" else 0.0) \
		+ (LOYAL_BONUS if CrewLife.is_loyal(member) else 0.0) + loot_bonus(member)
	efficiency *= member.health / 100.0 * (1.0 - member.fatigue / 200.0) * loot_scale
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
		* danger_scale * rng.randf_range(0.5, 1.5))
	# Sang-froid : il décroche avant d'y laisser sa peau, les mains moins pleines.
	result.retreated = wounds > wound_cap(member)
	if result.retreated:
		wounds = wound_cap(member)
		for id: StringName in result.loot:
			result.loot[id] = roundi(result.loot[id] * RETREAT_LOOT)
	var infection: int = roundi((zone.infected_patches.x + zone.infected_patches.y) / 2.0 * INFECTION_PER_PATCH
		* infection_factor(member) * danger_scale * rng.randf_range(0.5, 1.5))
	result.wounds = wounds
	member.health = maxi(member.health - wounds, 0)
	member.fatigue = mini(member.fatigue + maxi(fatigue - ENDURANCE_FATIGUE * (member.endurance - 3), 0), 100)
	member.trust = mini(member.trust + trust, 100)
	if infection > 0:
		member.infection = mini(member.infection + infection, 99)
		member.infected = true
	if member.health <= 0:
		result.died = true
		result.loot.clear()
	for id: StringName in result.loot.keys():
		if result.loot[id] <= 0:
			result.loot.erase(id)
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
