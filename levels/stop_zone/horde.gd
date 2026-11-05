class_name Horde
extends Node
## La horde : un groupe d'infectés qui surgit peu après l'arrivée et fonce sur le train.
## Jamais annoncée. Elle décide quand elle arrive et qui en fait partie ; la zone
## d'arrêt la fait apparaître, branche les coups sur le train et suit les pertes.
## Testable seule (pas de scène).

## La horde surgit : la liste des ennemis qui la composent.
signal arrived(members: Array[EnemyData])
## Tous ses membres sont tombés.
signal repelled

var event: EventData
## Secondes avant l'arrivée.
var time_left: float = 0.0
var members: Array[EnemyData] = []
var has_arrived: bool = false
var _alive: int = 0


## Tire le délai et la composition (les ennemis pas encore apparus à cet arrêt sont écartés).
func setup(horde_event: EventData, stop_number: int, rng: RandomNumberGenerator) -> void:
	event = horde_event
	time_left = rng.randf_range(event.horde_delay.x, event.horde_delay.y)
	var size: int = rng.randi_range(event.horde_size.x, event.horde_size.y) + stop_number / maxi(event.horde_growth, 1)
	size = mini(size, event.horde_max)
	var pool: Dictionary[EnemyData, float] = {}
	var total: float = 0.0
	for id: StringName in event.horde_mix:
		var enemy: EnemyData = EnemyCatalog.get_enemy(id)
		if enemy and stop_number >= enemy.min_stop:
			pool[enemy] = event.horde_mix[id]
			total += event.horde_mix[id]
	members.clear()
	for i: int in size:
		var roll: float = rng.randf() * total
		for enemy: EnemyData in pool:
			roll -= pool[enemy]
			if roll <= 0.0:
				members.append(enemy)
				break
	has_arrived = false


func tick(delta: float) -> void:
	if has_arrived or event == null:
		return
	time_left -= delta
	if time_left <= 0.0:
		has_arrived = true
		_alive = members.size()
		arrived.emit(members)


## Un membre de la horde est tombé.
func member_died() -> void:
	if _alive <= 0:
		return
	_alive -= 1
	if _alive == 0:
		repelled.emit()


func alive() -> int:
	return _alive
