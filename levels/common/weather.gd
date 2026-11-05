class_name Weather
extends CanvasLayer
## Ambiance à l'écran : neige (toundra), brume pâle (marais). Des particules dessinées
## par-dessus le monde, sous l'interface. Rien ne change dans le jeu.

## Couleur de la brume du marais : pâle, jamais violette (le violet = l'infection).
const MIST_COLOR: Color = Color(0.85, 0.95, 0.72, 0.45)
const SNOW_COLOR: Color = Color(1.0, 1.0, 1.0, 0.85)


## L'ambiance d'un biome (&"snow", &"spores"), ou null s'il n'en a pas.
static func make(kind: StringName) -> Weather:
	if kind != &"snow" and kind != &"spores":
		return null
	var weather := Weather.new()
	weather.name = "Weather"
	weather.layer = 2
	weather.kind = kind
	return weather


var kind: StringName
var particles: CPUParticles2D


func _ready() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	particles = CPUParticles2D.new()
	particles.name = "Particles"
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.preprocess = 8.0
	if kind == &"snow":
		particles.position = Vector2(view.x / 2.0, -8.0)
		particles.emission_rect_extents = Vector2(view.x / 2.0 + 40.0, 4.0)
		particles.amount = 140
		particles.lifetime = 9.0
		particles.direction = Vector2(-0.25, 1.0)
		particles.spread = 12.0
		particles.gravity = Vector2(0.0, 4.0)
		particles.initial_velocity_min = 18.0
		particles.initial_velocity_max = 34.0
		particles.scale_amount_min = 1.0
		particles.scale_amount_max = 2.0
		particles.color = SNOW_COLOR
	else:
		particles.position = view / 2.0
		particles.emission_rect_extents = view / 2.0
		particles.amount = 40
		particles.lifetime = 7.0
		particles.direction = Vector2(0.3, -1.0)
		particles.spread = 40.0
		particles.gravity = Vector2.ZERO
		particles.initial_velocity_min = 2.0
		particles.initial_velocity_max = 6.0
		particles.scale_amount_min = 1.0
		particles.scale_amount_max = 2.0
		particles.color = MIST_COLOR
	add_child(particles)
