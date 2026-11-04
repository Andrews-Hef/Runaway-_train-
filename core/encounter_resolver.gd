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
	var exposure: float = 0.0


## Le joueur porte-t-il de quoi payer ce choix ?
static func can_afford(choice: EncounterChoice, result: ExpeditionResult) -> bool:
	return missing(choice, result).is_empty()


## Ce qui manque pour payer : id -> quantité manquante (vide si tout va bien).
static func missing(choice: EncounterChoice, result: ExpeditionResult) -> Dictionary[StringName, int]:
	var lacking: Dictionary[StringName, int] = {}
	for id: StringName in choice.cost:
		var short: int = choice.cost[id] - result.get_amount(id)
		if short > 0:
			lacking[id] = short
	return lacking


## Applique le choix. `taken_names` évite de recruter deux personnes du même nom.
static func apply(choice: EncounterChoice, result: ExpeditionResult, rng: RandomNumberGenerator,
		taken_names: Array[String] = []) -> Outcome:
	assert(can_afford(choice, result), "Choix appliqué sans pouvoir le payer")
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
