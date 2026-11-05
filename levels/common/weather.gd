class_name Weather
extends CanvasLayer
## Ambiance à l'écran : neige (toundra), brume pâle (marais), pluie infectée (événement).
## Des particules dessinées par-dessus le monde, sous l'interface. Rien ne change dans
## le jeu : les effets de la pluie sont dans InfectedRain.

## Couleur de la brume du marais : pâle, jamais violette (le violet = l'infection).
const MIST_COLOR: Color = Color(0.85, 0.95, 0.72, 0.45)
const SNOW_COLOR: Color = Color(1.0, 1.0, 1.0, 0.85)
## Pluie infectée : violette (le violet = l'infection), ciel assombri.
const RAIN_COLOR: Color = Color(0.78, 0.6, 1.0, 0.7)
const RAIN_SKY: Color = Color(0.2, 0.1, 0.3, 0.28)


## L'ambiance d'un biome (&"snow", &"spores"), ou null s'il n'en a pas.
static func make(kind: StringName) -> Weather:
	if not kind in [&"snow", &"spores", &"infected_rain"]:
		return null
	var weather := Weather.new()
	weather.name = "Weather"
	weather.layer = 2
	weather.kind = kind
	return weather


var kind: StringName
var particles: CPUParticles2D
## Voile sombre sur le monde (pluie infectée).
var sky: ColorRect
var _tween: Tween


func _ready() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	particles = CPUParticles2D.new()
	particles.name = "Particles"
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.preprocess = 8.0
	if kind == &"infected_rain":
		_setup_rain(view)
		return
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


## Pluie : traits violets en diagonale et ciel assombri. Arrêtée au départ : set_active().
func _setup_rain(view: Vector2) -> void:
	sky = ColorRect.new()
	sky.name = "Sky"
	sky.color = RAIN_SKY
	sky.modulate.a = 0.0
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sky)
	var streak := Image.create(1, 5, false, Image.FORMAT_RGBA8)
	streak.fill(Color.WHITE)
	particles.texture = ImageTexture.create_from_image(streak)
	particles.position = Vector2(view.x / 2.0 + 40.0, -10.0)
	particles.emission_rect_extents = Vector2(view.x / 2.0 + 80.0, 4.0)
	particles.amount = 260
	particles.lifetime = 1.6
	particles.preprocess = 0.0
	particles.direction = Vector2(-0.3, 1.0)
	particles.spread = 3.0
	particles.gravity = Vector2(0.0, 60.0)
	particles.initial_velocity_min = 170.0
	particles.initial_velocity_max = 220.0
	particles.particle_flag_align_y = true
	particles.color = RAIN_COLOR
	particles.emitting = false
	add_child(particles)


## Pluie : `level` 0 (rien), 0,4 (le ciel se couvre), 1 (il pleut), en fondu.
func set_rain(level: float, fade: float = 1.5) -> void:
	if sky == null:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(sky, "modulate:a", level, fade)
	particles.emitting = level >= 1.0
