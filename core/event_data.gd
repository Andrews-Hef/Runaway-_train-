class_name EventData
extends Resource
## Un événement d'arrêt (pluie infectée, plus tard la horde...). Il est tiré pour
## chaque voie de l'aiguillage, annoncé sur sa carte, puis joué dans la zone.
## Un événement = un fichier .tres dans data/events/, listé dans GameState.EVENTS.

@export var id: StringName
@export var display_name: String
## Sur la carte de l'aiguillage et au trajet (« Pluie infectée annoncée »).
@export var forecast_text: String
@export_multiline var description: String
## Chance d'arriver selon le biome (id de BiomeData -> 0 à 1). Absent = jamais.
@export var chances: Dictionary[StringName, float] = {}
## Premier arrêt où il peut arriver.
@export var min_stop: int = 3

@export_group("Déroulé")
## Début, en part de la durée de l'arrêt (min, max).
@export var start_window: Vector2 = Vector2(0.2, 0.45)
## Alerte avant le début, en secondes.
@export var warning_time: float = 8.0
## Durée, en secondes (min, max).
@export var duration: Vector2 = Vector2(30.0, 45.0)

@export_group("Effets")
## Exposition par seconde à découvert (réduite par la protection).
@export var exposure_rate: float = 0.005
## Plantes infectées qui poussent pendant l'événement (min, max).
@export var sprouts: Vector2i = Vector2i(3, 5)
## Infectés qui sortent au début (min, max).
@export var extra_infected: Vector2i = Vector2i(1, 2)


## Chance d'arriver à cet arrêt, dans ce biome.
func chance_for(biome: BiomeData, stop_number: int) -> float:
	if biome == null or stop_number < min_stop:
		return 0.0
	return chances.get(biome.id, 0.0)
