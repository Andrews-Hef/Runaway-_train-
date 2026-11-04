class_name RefugeRules
extends RefCounted
## Règles des offres d'une gare refuge (échanges et recrues), payées avec le stock.
##
## Pur : on lui passe le stock, la place libre, les couchettes libres.

enum Problem { NONE, MISSING_MATERIALS, NO_SPACE, NO_BED, ALREADY_DONE }

const PROBLEM_TEXTS: Dictionary[Problem, String] = {
	Problem.MISSING_MATERIALS: "Il manque des matériaux dans le stock.",
	Problem.NO_SPACE: "Pas assez de place dans le stock du train.",
	Problem.NO_BED: "Plus de couchette libre : construis un dortoir.",
	Problem.ALREADY_DONE: "Déjà fait pendant ce passage.",
}


## Peut-on prendre cette offre ? `done` : offre déjà prise pendant ce passage.
static func problem(offer: RefugeOffer, storage: Dictionary[StringName, int], free_space: int,
		free_beds: int, done: bool = false) -> Problem:
	# `done` : recrue déjà prise pendant ce passage, ou plan déjà connu.
	if done and (offer.recruits() or offer.reward_plan != &""):
		return Problem.ALREADY_DONE
	if not TrainRules.missing(offer.cost, storage).is_empty():
		return Problem.MISSING_MATERIALS
	if net_gain(offer) > free_space:
		return Problem.NO_SPACE
	if offer.recruits() and free_beds <= 0:
		return Problem.NO_BED
	return Problem.NONE


## Ressources gagnées moins ressources payées (place prise dans le stock).
static func net_gain(offer: RefugeOffer) -> int:
	var total: int = 0
	for amount: int in offer.reward.values():
		total += amount
	for amount: int in offer.cost.values():
		total -= amount
	return total


## Applique l'offre au stock. Renvoie la recrue, s'il y en a une (jamais infectée).
static func apply(offer: RefugeOffer, storage: Dictionary[StringName, int], rng: RandomNumberGenerator,
		taken_names: Array[String] = []) -> CrewMember:
	TrainRules.pay(offer.cost, storage)
	for id: StringName in offer.reward:
		storage[id] = storage.get(id, 0) + offer.reward[id]
	if not offer.recruits():
		return null
	return CrewMember.create(EncounterResolver.pick_name(rng, taken_names), offer.recruit_role, offer.recruit_role_label, false)
