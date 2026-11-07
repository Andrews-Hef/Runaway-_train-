class_name CrewLife
extends RefCounted
## La vie de l'équipage pendant un trajet. Pur : modifie les équipiers et renvoie un
## compte rendu (Report). GameState l'appelle dans prepare_next_stop.
##
## Pendant un trajet, chacun :
## - travaille selon son rôle s'il est en état (pas épuisé, pas trop blessé, pas au
##   repos ni en quarantaine) : le mécanicien répare le train, le soigneur soigne le
##   plus blessé et repère les infectés, l'éclaireur repère les hordes. Travailler fatigue.
## - sinon récupère (couchettes ; mieux dans un dortoir agrandi, encore mieux au repos).
## - L'infection monte, se voit aux symptômes, contamine les voisins (sauf quarantaine),
##   rend malade, et à 100 % l'équipier rejoint la ruche.
## - La confiance monte quand il va bien, baisse quand il est épuisé ou qu'on perd
##   quelqu'un. Loyal, il travaille mieux ; méfiant, il quitte le train à la gare refuge.

## Fatigue due au travail, par rôle.
const WORK_FATIGUE: Dictionary[StringName, int] = {&"mechanic": 20, &"medic": 15, &"scout": 15}
## Récupération sans travailler, + par niveau de dortoir au-delà du premier, + au repos.
const REST_RECOVERY: int = 25
const DORM_LEVEL_BONUS: int = 10
const RESTING_BONUS: int = 20
## Épuisé : ne travaille plus. Poussé au bout (COLLAPSE_AT après un travail) : s'effondre.
const EXHAUSTED: int = 80
const COLLAPSE_AT: int = 95
const COLLAPSE_DAMAGE: int = 10
## Trop blessé pour travailler.
const TOO_HURT: int = 25
## Infection : progression par trajet, symptômes visibles, malade (vie en moins), ruche.
const INFECTION_GROWTH: int = 10
const SYMPTOMS: int = 40
const SICK: int = 70
const SICK_DAMAGE: int = 10
const TURNED: int = 100
## Contagion : chance par trajet d'infecter chaque voisin non isolé, et infection reçue.
const SPREAD_CHANCE: float = 0.15
const SPREAD_START: int = 10
## Soins naturels (au repos), et soins du soigneur (vie, infection).
const HEALTH_REGEN: int = 5
const MEDIC_HEAL: int = 20
const MEDIC_CURE: int = 8
## Mécanicien : réparation du train (au plus MAX_MECHANICS comptent), mieux s'il est loyal.
const MECHANIC_REPAIR: float = 0.1
const MAX_MECHANICS: int = 2
## Réparation en plus (ou en moins) par point d'Adresse au-dessus (en dessous) de 3.
const SKILL_REPAIR: float = 0.15
const LOYAL_BONUS: float = 1.5
## Blessures de l'équipage quand la horde frappe le train : 10 PV par tranche de 10 %.
const HORDE_HURT_STEP: float = 0.1
const HORDE_HURT: int = 10
## Confiance.
const LOYAL: int = 70
const SUSPICIOUS: int = 25
const TRUST_WELL: int = 5
const TRUST_EXHAUSTED: int = -5
const TRUST_LOSS: int = -10
## Chance qu'un équipier méfiant quitte le train en arrivant en gare refuge.
const DESERT_CHANCE: float = 0.5
## Ruche : un équipier qui se transforme abîme le train.
const TURN_TRAIN_DAMAGE: float = 0.1


## Ce qui s'est passé pendant le trajet.
class Report:
	## Récit, une ligne par fait (« Léa a réparé le train : +10 % »).
	var events: Array[String] = []
	## Réparation du train par les mécaniciens.
	var repair: float = 0.0
	## Un éclaireur a travaillé : les hordes sont repérées sur l'aiguillage.
	var scouted: bool = false
	## Dégâts au train (ruche).
	var train_damage: float = 0.0
	var dead: Array[CrewMember] = []
	var turned: Array[CrewMember] = []
	var deserted: Array[CrewMember] = []


## Contexte du trajet.
class Context:
	var dorm_level: int = 1
	## Dégâts du train pendant l'arrêt (horde) : l'équipage à bord est blessé.
	var horde_damage: float = 0.0
	## Le train arrive en gare refuge : les méfiants peuvent descendre.
	var to_refuge: bool = false
	var rng: RandomNumberGenerator


## Est-il en état de travailler pendant ce trajet ?
static func can_work(member: CrewMember) -> bool:
	return not member.resting and not member.quarantined and member.fatigue < EXHAUSTED \
		and member.health > TOO_HURT


static func is_loyal(member: CrewMember) -> bool:
	return member.trust >= LOYAL


static func is_suspicious(member: CrewMember) -> bool:
	return member.trust < SUSPICIOUS


## L'état en mots (neutres), pour l'interface : « épuisement », « infection », « méfiance »...
static func status(member: CrewMember) -> PackedStringArray:
	var tags: PackedStringArray = []
	if member.quarantined:
		tags.append("en quarantaine")
	elif member.resting:
		tags.append("au repos")
	if member.fatigue >= EXHAUSTED:
		tags.append("épuisement")
	if member.health <= TOO_HURT:
		tags.append("blessure grave")
	if member.infection_known and member.infection >= SICK:
		tags.append("infection grave")
	elif member.infection_known and member.infection > 0:
		tags.append("infection")
	if is_loyal(member):
		tags.append("fidèle")
	elif is_suspicious(member):
		tags.append("méfiance")
	return tags


## Un trajet pour tout l'équipage. Les morts, transformés et déserteurs sont retirés de `crew`.
static func run_trajet(crew: Array[CrewMember], context: Context) -> Report:
	var report := Report.new()
	var rng: RandomNumberGenerator = context.rng if context.rng else RandomNumberGenerator.new()
	_horde_wounds(crew, context, report, rng)
	var medic_working: bool = false
	var mechanics: int = 0
	for member: CrewMember in crew:
		if not can_work(member):
			continue
		match member.role:
			&"mechanic":
				if mechanics < MAX_MECHANICS:
					mechanics += 1
					# Adresse : un mécano adroit répare mieux (3 = normal).
					var repair: float = MECHANIC_REPAIR * (LOYAL_BONUS if is_loyal(member) else 1.0) \
						* (1.0 + SKILL_REPAIR * (member.skill - 3))
					report.repair += repair
					report.events.append("%s a réparé le train : +%d %%." % [member.display_name, roundi(repair * 100.0)])
			&"medic":
				medic_working = true
				_medic_work(member, crew, report)
			&"scout":
				report.scouted = true
				report.events.append("%s guette la voie : les hordes seront repérées à l'aiguillage." % member.display_name)
		member.fatigue = mini(member.fatigue + WORK_FATIGUE.get(member.role, 10), 100)
		member.set_meta(&"worked", true)
	for member: CrewMember in crew:
		var worked: bool = member.get_meta(&"worked", false)
		member.remove_meta(&"worked")
		if not worked:
			var recovery: int = REST_RECOVERY + DORM_LEVEL_BONUS * (context.dorm_level - 1) + (RESTING_BONUS if member.resting else 0)
			member.fatigue = maxi(member.fatigue - recovery, 0)
			if member.fatigue < EXHAUSTED:
				member.health = mini(member.health + HEALTH_REGEN, 100)
		member.resting = false
		if member.fatigue >= COLLAPSE_AT:
			member.health = maxi(member.health - COLLAPSE_DAMAGE, 0)
			report.events.append("%s s'écroule de fatigue (−%d PV)." % [member.display_name, COLLAPSE_DAMAGE])
		if medic_working:
			member.infection_known = true
	_infection(crew, report, rng)
	_trust(crew, report)
	_losses(crew, context, report, rng)
	CrewRequests.tick(crew, rng, report.events)
	return report


static func _horde_wounds(crew: Array[CrewMember], context: Context, report: Report, rng: RandomNumberGenerator) -> void:
	if crew.is_empty():
		return
	var wounds: int = floori(context.horde_damage / HORDE_HURT_STEP)
	for i: int in wounds:
		var member: CrewMember = crew[rng.randi_range(0, crew.size() - 1)]
		member.health = maxi(member.health - HORDE_HURT, 0)
		report.events.append("%s : blessure pendant l'attaque du train (−%d PV)." % [member.display_name, HORDE_HURT])


## Le soigneur : soigne le plus blessé, freine l'infection connue la plus avancée.
static func _medic_work(medic: CrewMember, crew: Array[CrewMember], report: Report) -> void:
	var hurt: CrewMember = null
	var sick: CrewMember = null
	for member: CrewMember in crew:
		if member.health < 100 and (hurt == null or member.health < hurt.health):
			hurt = member
		if member.infection > 0 and (sick == null or member.infection > sick.infection):
			sick = member
	if hurt:
		hurt.health = mini(hurt.health + MEDIC_HEAL, 100)
		report.events.append("%s a soigné %s (+%d PV)." % [medic.display_name, hurt.display_name, MEDIC_HEAL])
	if sick:
		sick.infection = maxi(sick.infection - MEDIC_CURE, 0)
		sick.infection_known = true


static func _infection(crew: Array[CrewMember], report: Report, rng: RandomNumberGenerator) -> void:
	var spreaders: Array[CrewMember] = []
	for member: CrewMember in crew:
		if member.infection <= 0:
			member.infected = false
			continue
		member.infected = true
		var was_hidden: bool = not member.infection_known
		member.infection = mini(member.infection + INFECTION_GROWTH, 100)
		if member.infection >= SYMPTOMS and not member.infection_known:
			member.infection_known = true
		if was_hidden and member.infection_known:
			report.events.append("%s tousse et a de la fièvre : infection à %d %%." % [member.display_name, member.infection])
		if member.infection >= SICK:
			member.health = maxi(member.health - SICK_DAMAGE, 0)
		if not member.quarantined:
			spreaders.append(member)
	if spreaders.is_empty():
		return
	for member: CrewMember in crew:
		if member.infection > 0 or member.quarantined:
			continue
		for spreader: CrewMember in spreaders:
			if rng.randf() < SPREAD_CHANCE:
				member.infection = SPREAD_START
				member.infected = true
				break


static func _trust(crew: Array[CrewMember], report: Report) -> void:
	for member: CrewMember in crew:
		if member.fatigue >= EXHAUSTED:
			member.trust = clampi(member.trust + TRUST_EXHAUSTED, 0, 100)
			report.events.append("%s n'en peut plus : plus de travail sans repos." % member.display_name)
		elif member.health >= 60 and member.fatigue < 50:
			member.trust = clampi(member.trust + TRUST_WELL, 0, 100)


## Morts, ruche, départs. Chaque perte fait baisser la confiance des autres.
static func _losses(crew: Array[CrewMember], context: Context, report: Report, rng: RandomNumberGenerator) -> void:
	for member: CrewMember in crew.duplicate():
		if member.infection >= TURNED:
			crew.erase(member)
			report.turned.append(member)
			report.train_damage += TURN_TRAIN_DAMAGE
			report.events.append("%s a rejoint la ruche ! Une voiture est saccagée avant le saut du train." % member.display_name)
		elif member.health <= 0:
			crew.erase(member)
			report.dead.append(member)
			report.events.append("%s n'a pas survécu." % member.display_name)
	if context.to_refuge:
		for member: CrewMember in crew.duplicate():
			if is_suspicious(member) and rng.randf() < DESERT_CHANCE:
				crew.erase(member)
				report.deserted.append(member)
				report.events.append("%s ne te fait plus confiance et descend à la gare refuge." % member.display_name)
	var losses: int = report.turned.size() + report.dead.size()
	if losses > 0:
		for member: CrewMember in crew:
			member.trust = clampi(member.trust + TRUST_LOSS * losses, 0, 100)
