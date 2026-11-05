class_name BiomeRules
extends Node
## La règle du biome pendant un arrêt (voir BiomeData.Rule) :
## - marais : l'eau stagnante ralentit ;
## - toundra : le froid fait perdre 1 PV à intervalle régulier sans tenue chaude,
##   et la glace fait glisser ;
## - ville : fouiller une voiture peut déclencher une alarme ;
## - zone industrielle : les flaques toxiques brûlent sans tenue étanche.
##
## La zone d'arrêt la crée, l'appelle à chaque image avec tick() et branche ses signaux.
## Sans moteur physique ni scène : testable seule.

## Dégâts du biome (froid, brûlure). `message` : à afficher (vide = ne pas répéter).
signal hurt(amount: int, message: String)
## Une alarme hurle à cet endroit : les ennemis proches accourent.
signal alarm_raised(at: Vector2)
## Le sol sous le joueur change : vitesse (1 = normale) et glisse.
signal terrain_changed(speed: float, slippery: bool)

## Vitesse dans l'eau du marais.
const WATER_SPEED: float = 0.55
## Adhérence sur la glace (part de l'accélération et du freinage normaux).
const ICE_GRIP: float = 0.15
## Secondes entre deux PV perdus au froid.
const COLD_TICK: float = 15.0
## Secondes entre deux brûlures dans une flaque toxique, et délai avant la première.
const TOXIC_TICK: float = 1.5
const TOXIC_GRACE: float = 0.4
## Chance qu'une voiture fouillée déclenche son alarme, et portée de l'alarme (px).
const ALARM_CHANCE: float = 0.3
const ALARM_RADIUS: float = 260.0

const RESIST_COLD: StringName = &"cold"
const RESIST_TOXIC: StringName = &"toxic"

var rule: BiomeData.Rule = BiomeData.Rule.NONE
var resists_cold: bool = false
var resists_toxic: bool = false

var _on_hazard: bool = false
var _cold_timer: float = COLD_TICK
var _toxic_timer: float = TOXIC_GRACE
## Déjà brûlé depuis qu'on est entré dans la flaque (on ne répète pas le message).
var _burned: bool = false


func setup(biome: BiomeData, loadout: Loadout) -> void:
	rule = biome.rule if biome else BiomeData.Rule.NONE
	resists_cold = loadout.resists(RESIST_COLD)
	resists_toxic = loadout.resists(RESIST_TOXIC)
	_cold_timer = COLD_TICK
	_toxic_timer = TOXIC_GRACE


## Une image : `on_hazard` dit si le joueur est sur le sol piégeux du biome.
func tick(delta: float, on_hazard: bool) -> void:
	if on_hazard != _on_hazard:
		_on_hazard = on_hazard
		if not on_hazard:
			_toxic_timer = TOXIC_GRACE
			_burned = false
		terrain_changed.emit(speed_factor(), is_slippery())
	match rule:
		BiomeData.Rule.COLD:
			if resists_cold:
				return
			_cold_timer -= delta
			if _cold_timer <= 0.0:
				_cold_timer += COLD_TICK
				hurt.emit(1, "Le froid te mord : −1 PV. Une tenue chaude protège.")
		BiomeData.Rule.TOXIC:
			if not on_hazard or resists_toxic:
				return
			_toxic_timer -= delta
			if _toxic_timer <= 0.0:
				_toxic_timer += TOXIC_TICK
				hurt.emit(1, "" if _burned else "Flaque toxique : ça brûle ! La combinaison étanche protège.")
				_burned = true


## Vitesse du joueur sur le sol actuel.
func speed_factor() -> float:
	return WATER_SPEED if rule == BiomeData.Rule.MARSH and _on_hazard else 1.0


func is_slippery() -> bool:
	return rule == BiomeData.Rule.COLD and _on_hazard


## Une voiture vient d'être fouillée en ville : peut-être une alarme. Renvoie true si elle sonne.
func car_searched(at: Vector2, rng: RandomNumberGenerator) -> bool:
	if rule != BiomeData.Rule.CAR_ALARMS or rng.randf() >= ALARM_CHANCE:
		return false
	alarm_raised.emit(at)
	return true
