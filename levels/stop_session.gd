class_name StopSession
extends Node
## Un arrêt du train : compte à rebours, sifflet, butin et fin de la sortie.
##
## Arrêt forcé (panne) : la session est bloquée (HELD), sans compte à rebours ; on ne
## monte pas à bord. Une fois la locomotive réparée, release() fait siffler le train
## et lance le départ.
##
## Logique pure, sans affichage : le HUD, le train et l'écran de bilan
## écoutent ses signaux. Le temps avance via tick(), testable sans attendre.

enum State { RUNNING, WHISTLE, ENDED, HELD }

signal time_changed(remaining: float)
## Le train siffle : il reste whistle_time secondes pour remonter.
signal whistle_blown
signal ended(result: ExpeditionResult)
signal loot_changed(result: ExpeditionResult)
signal recruited(member: CrewMember)
## Le joueur a jeté des ressources de son sac (la zone pose un tas à ses pieds).
signal dropped(id: StringName, amount: int)

## Durée de l'arrêt, en secondes.
@export var duration: float = 90.0
## Le sifflet retentit quand il reste ce nombre de secondes.
@export var whistle_time: float = 15.0

var state: State = State.RUNNING
var remaining: float = 0.0
## Temps passé dehors depuis le début de l'arrêt (même train en panne).
var elapsed: float = 0.0
var result: ExpeditionResult = ExpeditionResult.new()
## Source de l'exposition à recopier dans le résultat à la fin (injectée par la zone).
var exposure_source: ExposureComponent
## Cases du sac (piles de BagSlots.STACK_SIZE). < 0 = illimité.
var capacity: int = -1
## Couchettes libres dans le train au début de l'arrêt (-1 = illimité) : limite les recrues.
var free_beds: int = -1
## Plans qu'on peut encore trouver pendant cet arrêt (ids).
var plan_pool: Array[StringName] = []


## Groupe : l'inventaire (touche I) y trouve le sac de l'arrêt en cours.
const GROUP: StringName = &"stop_session"


func _ready() -> void:
	remaining = duration
	add_to_group(GROUP)


## (Re)lance l'arrêt avec une durée donnée (tirée par le générateur de zone).
func start(stop_duration: float) -> void:
	duration = stop_duration
	remaining = stop_duration
	elapsed = 0.0
	state = State.RUNNING
	result = ExpeditionResult.new()
	if exposure_source:
		result.exposure_start = exposure_source.value
	time_changed.emit(remaining)


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if state == State.ENDED:
		return
	elapsed += delta
	if state == State.HELD:
		return
	remaining = maxf(remaining - delta, 0.0)
	time_changed.emit(remaining)
	if state == State.RUNNING and remaining <= whistle_time:
		state = State.WHISTLE
		whistle_blown.emit()
	if remaining <= 0.0:
		_finish(false)


## Arrêt forcé : le train est en panne, pas de compte à rebours tant qu'il n'est pas réparé.
func hold() -> void:
	if state != State.ENDED:
		state = State.HELD
		remaining = 0.0


## La locomotive est réparée : le train siffle et part dans `seconds` secondes.
func release(seconds: float) -> void:
	if state != State.HELD:
		return
	remaining = seconds
	state = State.WHISTLE
	time_changed.emit(remaining)
	whistle_blown.emit()


func is_held() -> bool:
	return state == State.HELD


## Ajoute du butin dans la limite du sac. Renvoie la quantité vraiment prise.
func add_loot(loot: LootData, amount: int) -> int:
	if state == State.ENDED or loot == null:
		return 0
	var taken: int = amount if capacity < 0 else mini(amount, room_for(loot.id))
	if taken <= 0:
		return 0
	result.add_loot(loot.id, taken)
	loot_changed.emit(result)
	return taken


## Jette `amount` d'une ressource du sac (pour faire de la place). Renvoie la
## quantité vraiment jetée (pas plus que ce qu'on porte).
func drop(id: StringName, amount: int) -> int:
	if state == State.ENDED:
		return 0
	var thrown: int = mini(amount, result.get_amount(id))
	if thrown <= 0:
		return 0
	result.remove_loot(id, thrown)
	loot_changed.emit(result)
	dropped.emit(id, thrown)
	return thrown


## Combien de cette ressource peut encore entrer (la fin de sa pile, plus les cases
## libres ; très grand si le sac est illimité).
func room_for(id: StringName) -> int:
	if capacity < 0:
		return 1 << 30
	return BagSlots.room_for(result.loot, id, capacity)


## Cases occupées (piles de BagSlots.STACK_SIZE).
func used_slots() -> int:
	return BagSlots.used(result.loot)


## Cases libres (très grand si illimité).
func free_slots() -> int:
	if capacity < 0:
		return 1 << 30
	return maxi(capacity - used_slots(), 0)


## Plus aucune case libre (on peut encore compléter une pile entamée).
func is_bag_full() -> bool:
	return free_slots() <= 0


## Applique un choix de rencontre (échange, recrutement...) au butin de la sortie.
## Renvoie null si la sortie est finie ou si le joueur ne peut pas payer.
func resolve_choice(choice: EncounterChoice, rng: RandomNumberGenerator, taken_names: Array[String] = []) -> EncounterResolver.Outcome:
	if state == State.ENDED or not EncounterResolver.can_afford(choice, result, capacity, free_beds):
		return null
	var names: Array[String] = taken_names.duplicate()
	for member: CrewMember in result.recruits:
		names.append(member.display_name)
	var outcome := EncounterResolver.apply(choice, result, rng, names, plan_pool)
	loot_changed.emit(result)
	if outcome.recruit:
		recruited.emit(outcome.recruit)
	return outcome


## Un pilleur vole dans le sac : `amount` ressources prises au hasard.
## Renvoie ce qui a été volé (id -> quantité).
func steal(amount: int, rng: RandomNumberGenerator) -> Dictionary[StringName, int]:
	var stolen: Dictionary[StringName, int] = {}
	if state == State.ENDED:
		return stolen
	for i: int in amount:
		var ids: Array[StringName] = result.loot.keys()
		if ids.is_empty():
			break
		var id: StringName = ids[rng.randi_range(0, ids.size() - 1)]
		result.remove_loot(id, 1)
		stolen[id] = stolen.get(id, 0) + 1
	if not stolen.is_empty():
		loot_changed.emit(result)
	return stolen


## Un plan trouvé en fouillant (caisse) : il rejoint le butin de la sortie.
## Renvoie l'id du plan, ou vide s'il n'y en a plus à trouver.
func find_plan(rng: RandomNumberGenerator) -> StringName:
	if state == State.ENDED:
		return &""
	var pool: Array[StringName] = plan_pool.filter(func(id: StringName) -> bool: return not id in result.plans)
	if pool.is_empty():
		return &""
	var plan: StringName = pool[rng.randi_range(0, pool.size() - 1)]
	result.plans.append(plan)
	loot_changed.emit(result)
	return plan


## Un ennemi est éliminé (pour le mérite et les ordres « Élimine N... »).
func record_kill(enemy: EnemyData) -> void:
	if state == State.ENDED:
		return
	result.record_kill(enemy)
	loot_changed.emit(result)


## L'infection atteint 100 % : le joueur rejoint la ruche, la sortie se termine.
func turn() -> void:
	if state != State.ENDED:
		result.turned = true
		_finish(false)


## Le joueur tombe au combat : la sortie se termine, il ne remonte pas à bord.
func fall() -> void:
	if state != State.ENDED:
		result.fell = true
		_finish(false)


## Le joueur remonte à bord : la sortie se termine tout de suite (sauf train en panne).
func board() -> void:
	if state != State.ENDED and state != State.HELD:
		_finish(true)


func is_running() -> bool:
	return state != State.ENDED


func _finish(boarded: bool) -> void:
	state = State.ENDED
	result.boarded = boarded
	result.time_share = clampf(elapsed / duration, 0.0, 1.0) if duration > 0.0 else 1.0
	if exposure_source:
		result.exposure = exposure_source.value
	ended.emit(result)
