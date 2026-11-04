class_name StopSession
extends Node
## Un arrêt du train : compte à rebours, sifflet, butin et fin de la sortie.
##
## Logique pure, sans affichage : le HUD, le train et l'écran de bilan
## écoutent ses signaux. Le temps avance via tick(), testable sans attendre.

enum State { RUNNING, WHISTLE, ENDED }

signal time_changed(remaining: float)
## Le train siffle : il reste whistle_time secondes pour remonter.
signal whistle_blown
signal ended(result: ExpeditionResult)
signal loot_changed(result: ExpeditionResult)
signal recruited(member: CrewMember)

## Durée de l'arrêt, en secondes.
@export var duration: float = 90.0
## Le sifflet retentit quand il reste ce nombre de secondes.
@export var whistle_time: float = 15.0

var state: State = State.RUNNING
var remaining: float = 0.0
var result: ExpeditionResult = ExpeditionResult.new()
## Source de l'exposition à recopier dans le résultat à la fin (injectée par la zone).
var exposure_source: ExposureComponent


func _ready() -> void:
	remaining = duration


## (Re)lance l'arrêt avec une durée donnée (tirée par le générateur de zone).
func start(stop_duration: float) -> void:
	duration = stop_duration
	remaining = stop_duration
	state = State.RUNNING
	result = ExpeditionResult.new()
	time_changed.emit(remaining)


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if state == State.ENDED:
		return
	remaining = maxf(remaining - delta, 0.0)
	time_changed.emit(remaining)
	if state == State.RUNNING and remaining <= whistle_time:
		state = State.WHISTLE
		whistle_blown.emit()
	if remaining <= 0.0:
		_finish(false)


func add_loot(loot: LootData, amount: int) -> void:
	if state == State.ENDED or loot == null:
		return
	result.add_loot(loot.id, amount)
	loot_changed.emit(result)


## Applique un choix de rencontre (échange, recrutement...) au butin de la sortie.
## Renvoie null si la sortie est finie ou si le joueur ne peut pas payer.
func resolve_choice(choice: EncounterChoice, rng: RandomNumberGenerator, taken_names: Array[String] = []) -> EncounterResolver.Outcome:
	if state == State.ENDED or not EncounterResolver.can_afford(choice, result):
		return null
	var names: Array[String] = taken_names.duplicate()
	for member: CrewMember in result.recruits:
		names.append(member.display_name)
	var outcome := EncounterResolver.apply(choice, result, rng, names)
	loot_changed.emit(result)
	if outcome.recruit:
		recruited.emit(outcome.recruit)
	return outcome


## Le joueur remonte à bord : la sortie se termine tout de suite.
func board() -> void:
	if state != State.ENDED:
		_finish(true)


func is_running() -> bool:
	return state != State.ENDED


func _finish(boarded: bool) -> void:
	state = State.ENDED
	result.boarded = boarded
	if exposure_source:
		result.exposure = exposure_source.value
	ended.emit(result)
