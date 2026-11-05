class_name InfectedRain
extends Node
## La pluie infectée pendant un arrêt : ciel qui se couvre, alerte, pluie, fin.
##
## Elle ne connaît ni le joueur ni la carte : la zone d'arrêt l'appelle à chaque
## image avec tick(delta, à l'abri ?) et applique ce qu'elle signale (exposition,
## pousses, infectés). Testable seule.

enum Phase { WAITING, WARNING, RAINING, OVER }

## Le ciel se couvre : la pluie commence dans `seconds` secondes.
signal warned(seconds: float)
signal started(duration: float)
signal ended
## Exposition à ajouter au joueur (déjà multipliée par le temps ; la protection
## de l'équipement s'applique ensuite, dans ExposureComponent.add).
signal exposed(amount: float)
## Le joueur passe à l'abri (true) ou à découvert (false) pendant la pluie.
signal shelter_changed(sheltered: bool)

var event: EventData
var phase: Phase = Phase.WAITING
## Secondes avant la prochaine étape (alerte, début, fin).
var time_left: float = 0.0
## Durée de la pluie tirée pour cet arrêt.
var rain_duration: float = 0.0
var _sheltered: bool = false


## Prépare la pluie d'un arrêt de `stop_duration` secondes, avec son propre hasard.
func setup(rain_event: EventData, stop_duration: float, rng: RandomNumberGenerator) -> void:
	event = rain_event
	var start: float = stop_duration * rng.randf_range(event.start_window.x, event.start_window.y)
	rain_duration = rng.randf_range(event.duration.x, event.duration.y)
	phase = Phase.WAITING
	time_left = maxf(start - event.warning_time, 0.0)
	_sheltered = false


func is_raining() -> bool:
	return phase == Phase.RAINING


func tick(delta: float, sheltered: bool) -> void:
	if event == null or phase == Phase.OVER:
		return
	time_left -= delta
	match phase:
		Phase.WAITING:
			if time_left <= 0.0:
				phase = Phase.WARNING
				time_left += event.warning_time
				warned.emit(event.warning_time)
		Phase.WARNING:
			if time_left <= 0.0:
				phase = Phase.RAINING
				time_left += rain_duration
				_sheltered = sheltered
				started.emit(rain_duration)
				shelter_changed.emit(sheltered)
		Phase.RAINING:
			if sheltered != _sheltered:
				_sheltered = sheltered
				shelter_changed.emit(sheltered)
			if not sheltered:
				exposed.emit(event.exposure_rate * delta)
			if time_left <= 0.0:
				phase = Phase.OVER
				ended.emit()
