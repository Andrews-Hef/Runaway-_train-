class_name CrewFactory
extends RefCounted
## Fabrique les recrues : prénom et nom, apparence, stats, équipement de départ.
## Pur : même hasard, même recrue. Utilisé par les rencontres et les gares refuges.
##
## Stats de 1 à 5, la plupart entre 2 et 4, +1 dans celle de son métier. L'équipement
## dépend de l'avancée sur la ligne : du courant au début, du rare plus loin.

## La stat que chaque métier pousse.
const ROLE_STAT: Dictionary[StringName, StringName] = {
	&"mechanic": &"skill",
	&"medic": &"nerve",
	&"scout": &"endurance",
}
## Chance d'arriver avec quelque chose dans chaque emplacement.
const GEAR_CHANCES: Dictionary[int, float] = {
	ItemData.Slot.OUTFIT: 0.7,
	ItemData.Slot.WEAPON: 0.6,
	ItemData.Slot.MASK: 0.35,
	ItemData.Slot.TOOL: 0.25,
	ItemData.Slot.BAG: 0.2,
}
## Rareté accessible : une de plus tous les 6 arrêts (1 à 5 : courant, 6 à 11 : rare...).
const STOPS_PER_TIER: int = 6


## Une recrue complète. `taken_names`, `taken_looks` : ce que l'équipage porte déjà.
static func recruit(rng: RandomNumberGenerator, role: StringName, role_label: String, infected: bool, trust: int,
		taken_names: Array[String], taken_looks: Array[int] = [], stop_number: int = 1) -> CrewMember:
	var member := CrewMember.create(CrewNames.first_name(rng, taken_names), role, role_label, infected, trust)
	member.surname = CrewNames.surname(rng)
	member.look = CrewLooks.pick(rng, taken_looks)
	roll_stats(member, rng)
	for item: ItemData in starting_gear(rng, stop_number):
		member.loadout.equip(item)
	return member


static func roll_stats(member: CrewMember, rng: RandomNumberGenerator) -> void:
	for entry: Array in CrewMember.STATS:
		var value: int = rng.randi_range(2, 4)
		# Un sur cinq sort du lot, en bien ou en mal.
		if rng.randf() < 0.2:
			value += 1 if rng.randf() < 0.5 else -1
		member.set(entry[0], clampi(value, 1, 5))
	var favourite: StringName = ROLE_STAT.get(member.role, &"")
	if favourite != &"":
		member.set(favourite, mini(member.stat(favourite) + 1, 5))


static func max_tier(stop_number: int) -> int:
	return clampi(1 + stop_number / STOPS_PER_TIER, 1, 3)


static func starting_gear(rng: RandomNumberGenerator, stop_number: int) -> Array[ItemData]:
	var gear: Array[ItemData] = []
	var tier: int = max_tier(stop_number)
	for slot: int in GEAR_CHANCES:
		if rng.randf() >= GEAR_CHANCES[slot]:
			continue
		var pool: Array[ItemData] = ItemCatalog.ALL.filter(func(item: ItemData) -> bool:
			return item.slot == slot and item.tier <= tier)
		if not pool.is_empty():
			gear.append(pool[rng.randi_range(0, pool.size() - 1)])
	return gear
