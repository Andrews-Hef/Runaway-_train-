class_name EncounterResolver
extends RefCounted
## Applique un choix de rencontre au résultat de la sortie en cours.
##
## Pur : pas de scène, pas d'interface. Testable seul.

## Prénoms possibles des recrues.
const NAMES: Array[String] = [
	"Léa", "Malik", "Sofia", "Yanis", "Inès", "Hugo", "Nora", "Bastien",
	"Aya", "Théo", "Camille", "Jules", "Salomé", "Idris", "Maëlle", "Oscar",
]


## Ce qu'un choix a produit, pour l'afficher et l'appliquer au joueur.
class Outcome:
	var text: String
	var gained: Dictionary[StringName, int] = {}
	var recruit: CrewMember
	var item: ItemData
	var exposure: float = 0.0


## Clé spéciale de missing() : le sac est trop plein pour ce que le choix rapporte.
const NO_SPACE: StringName = &"_space"
## Clé spéciale de missing() : plus de couchette libre dans le train pour une recrue.
const NO_BED: StringName = &"_bed"


## Le joueur porte-t-il de quoi payer ce choix (et la place pour ce qu'il rapporte) ?
## capacity < 0 : pas de limite de sac. free_beds < 0 : pas de limite de couchettes.
static func can_afford(choice: EncounterChoice, result: ExpeditionResult, capacity: int = -1,
		free_beds: int = -1) -> bool:
	return missing(choice, result, capacity, free_beds).is_empty()


## Ce qui manque : id -> quantité manquante, NO_SPACE -> place manquante dans le sac,
## NO_BED -> couchettes manquantes. `free_beds` : couchettes libres au début de la sortie
## (les recrues de la sortie en cours en prennent).
static func missing(choice: EncounterChoice, result: ExpeditionResult, capacity: int = -1,
		free_beds: int = -1) -> Dictionary[StringName, int]:
	var lacking: Dictionary[StringName, int] = {}
	if free_beds >= 0 and choice.recruits() and result.recruits.size() >= free_beds:
		lacking[NO_BED] = 1
	for id: StringName in choice.cost:
		var short: int = choice.cost[id] - result.get_amount(id)
		if short > 0:
			lacking[id] = short
	if capacity >= 0 and lacking.is_empty():
		var overflow: int = result.total_items() + max_gain(choice) - _cost_total(choice) - capacity
		if overflow > 0:
			lacking[NO_SPACE] = overflow
	return lacking


## Ressources gagnées au maximum (gain fixe + gain aléatoire au plus haut).
static func max_gain(choice: EncounterChoice) -> int:
	var total: int = 0
	for amount: int in choice.reward.values():
		total += amount
	if not choice.random_reward_pool.is_empty():
		total += choice.random_reward_amount.y
	return total


static func _cost_total(choice: EncounterChoice) -> int:
	var total: int = 0
	for amount: int in choice.cost.values():
		total += amount
	return total


## Applique le choix. `taken_names` évite de recruter deux personnes du même nom.
static func apply(choice: EncounterChoice, result: ExpeditionResult, rng: RandomNumberGenerator,
		taken_names: Array[String] = []) -> Outcome:
	assert(missing(choice, result).is_empty(), "Choix appliqué sans pouvoir le payer")
	var outcome := Outcome.new()
	outcome.text = choice.outcome_text

	for id: StringName in choice.cost:
		result.remove_loot(id, choice.cost[id])
	for id: StringName in choice.reward:
		_gain(outcome, result, id, choice.reward[id])
	if not choice.random_reward_pool.is_empty() and choice.random_reward_amount.y > 0:
		var id: StringName = choice.random_reward_pool[rng.randi_range(0, choice.random_reward_pool.size() - 1)]
		_gain(outcome, result, id, rng.randi_range(choice.random_reward_amount.x, choice.random_reward_amount.y))

	if choice.recruits():
		var infected: bool = rng.randf() < choice.recruit_infection_chance
		outcome.recruit = CrewMember.create(_pick_name(rng, taken_names), choice.recruit_role, choice.recruit_role_label, infected)
		result.recruits.append(outcome.recruit)
		outcome.text = outcome.text.replace("{nom}", outcome.recruit.display_name)

	if choice.reward_item and not choice.reward_item in result.items:
		outcome.item = choice.reward_item
		result.items.append(choice.reward_item)

	outcome.exposure = choice.exposure
	return outcome


static func _gain(outcome: Outcome, result: ExpeditionResult, id: StringName, amount: int) -> void:
	if amount <= 0:
		return
	result.add_loot(id, amount)
	outcome.gained[id] = outcome.gained.get(id, 0) + amount


static func _pick_name(rng: RandomNumberGenerator, taken: Array[String]) -> String:
	var free: Array[String] = []
	for candidate: String in NAMES:
		if not candidate in taken:
			free.append(candidate)
	if free.is_empty():
		return NAMES[rng.randi_range(0, NAMES.size() - 1)]
	return free[rng.randi_range(0, free.size() - 1)]
