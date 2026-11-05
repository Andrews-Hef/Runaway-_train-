class_name DayClock
extends RefCounted
## L'heure du jeu : jour, heure, lumière du jour, nuit. Pur (aucune scène).
##
## Le temps est compté en minutes depuis le début de la partie (jour 1, 0h00).
## La partie commence le jour 1 à 6h. En zone, 1 seconde = 1 minute ; un trajet
## dure 3 h ; on passe 1 h en gare refuge. Environ 5 arrêts par jour.

const MINUTES_PER_DAY: int = 1440
## Début de la partie : jour 1, 6h00.
const START_MINUTES: int = 6 * 60
## En zone : minutes de jeu par seconde réelle.
const MINUTES_PER_SECOND: float = 1.0
## Durée d'un trajet, et temps passé en gare refuge.
const TRAVEL_MINUTES: int = 180
const REFUGE_MINUTES: int = 60
## Aube (5h → 7h) et crépuscule (19h → 21h) : la lumière monte et descend.
const DAWN_START: int = 5 * 60
const DAWN_END: int = 7 * 60
const DUSK_START: int = 19 * 60
const DUSK_END: int = 21 * 60
## Teinte de la nuit (CanvasModulate) : sombre et bleutée.
const NIGHT_COLOR: Color = Color(0.25, 0.29, 0.5)


static func day(total: int) -> int:
	return total / MINUTES_PER_DAY + 1


static func minute_of_day(total: int) -> int:
	return posmod(total, MINUTES_PER_DAY)


## La nuit : de la fin du crépuscule (21h) au début de l'aube (5h).
static func is_night(total: int) -> bool:
	var minute: int = minute_of_day(total)
	return minute >= DUSK_END or minute < DAWN_START


## Lumière du jour : 0 la nuit, 1 en plein jour, entre les deux à l'aube et au crépuscule.
static func daylight(total: int) -> float:
	var minute: int = minute_of_day(total)
	if minute < DAWN_START or minute >= DUSK_END:
		return 0.0
	if minute < DAWN_END:
		return float(minute - DAWN_START) / (DAWN_END - DAWN_START)
	if minute < DUSK_START:
		return 1.0
	return 1.0 - float(minute - DUSK_START) / (DUSK_END - DUSK_START)


## Couleur de la lumière sur le monde : celle du biome le jour, bleu nuit la nuit.
static func sky_color(total: int, ambient: Color = Color.WHITE) -> Color:
	return NIGHT_COLOR.lerp(ambient, daylight(total))


## « 21:40 ».
static func time_text(total: int) -> String:
	var minute: int = minute_of_day(total)
	return "%02d:%02d" % [minute / 60, minute % 60]


## « Jour 2 · 21:40 ».
static func describe(total: int) -> String:
	return "Jour %d · %s" % [day(total), time_text(total)]


## « nuit », « aube », « jour », « crépuscule ».
static func period_name(total: int) -> String:
	var minute: int = minute_of_day(total)
	if is_night(total):
		return "nuit"
	if minute < DAWN_END:
		return "aube"
	return "jour" if minute < DUSK_START else "crépuscule"
