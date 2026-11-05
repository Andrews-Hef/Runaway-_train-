class_name CaptainDecisions
extends RefCounted
## Ce que décide le capitaine (le PNJ) tant que le joueur n'a pas le grade pour le faire
## (voir Career.AUTHORITY) : il choisit la voie, dirige l'équipage, fait construire le
## train et renforce la locomotive. Chaque décision renvoie une phrase pour le récit.

## Il met au repos un équipier à partir de cette fatigue.
const REST_AT: int = 60
## Il fait construire un stock quand il reste moins de cette part de place.
const STOCK_LOW: float = 0.2


## La voie la plus sûre : danger le plus bas, en évitant une horde repérée et la pluie.
static func pick_route(options: Array, stop_number: int) -> int:
	var best: int = 0
	var best_score: float = INF
	for i: int in options.size():
		var option: Object = options[i]
		var zone: ZoneProfile = option.get(&"zone")
		var score: float = zone.danger(stop_number) * 10.0 + zone.expected_enemies(stop_number)
		if option.get(&"horde_spotted"):
			score += 15.0
		if option.get(&"event") != null:
			score += 3.0
		if score < best_score:
			best_score = score
			best = i
	return best


## Avant le trajet : les épuisés au repos, les infectés connus à l'infirmerie (s'il y a de
## la place), les guéris en sortent.
static func manage_crew(crew: Array[CrewMember], has_infirmary: bool, quarantine_beds: int) -> Array[String]:
	var notes: Array[String] = []
	var isolated: int = 0
	for member: CrewMember in crew:
		if member.quarantined and member.infection == 0:
			member.quarantined = false
			notes.append("Le capitaine fait sortir %s de quarantaine." % member.display_name)
		if member.quarantined:
			isolated += 1
	for member: CrewMember in crew:
		if not member.quarantined and has_infirmary and isolated < quarantine_beds \
				and member.infection_known and member.infection >= CrewLife.SYMPTOMS:
			member.quarantined = true
			isolated += 1
			notes.append("Le capitaine isole %s à l'infirmerie." % member.display_name)
		elif not member.quarantined and member.fatigue >= REST_AT and not member.resting:
			member.resting = true
			notes.append("Le capitaine met %s au repos." % member.display_name)
	return notes


## Pendant le trajet : un dortoir s'il n'y a plus de couchette, un stock s'il est presque
## plein. Une construction au plus. Renvoie la phrase du récit (vide : rien).
static func build(state: Node) -> String:
	var wanted: Array[StringName] = []
	if state.call(&"free_beds") == 0:
		wanted.append(&"dormitory")
	if state.call(&"storage_free") < state.call(&"storage_capacity") * STOCK_LOW:
		wanted.append(&"stock")
	for id: StringName in wanted:
		for wagon: WagonData in state.get(&"BUILDABLE_WAGONS"):
			if wagon.id == id and state.call(&"build_wagon", wagon):
				return "Le capitaine a fait construire : %s." % wagon.display_name.to_lower()
	return ""


## Au dépôt d'une gare refuge : il fait renforcer la locomotive s'il a de quoi payer.
static func depot(state: Node) -> String:
	var next: LocomotiveLevel = TrainRules.next_level(state.get(&"locomotive_level"))
	if next and state.call(&"upgrade_locomotive"):
		return "Le capitaine a fait renforcer la locomotive : elle tire maintenant %d voitures." % next.max_cars
	return ""
