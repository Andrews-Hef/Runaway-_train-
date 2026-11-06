class_name BlueprintPaper
extends PanelContainer
## Feuille de plan d'atelier : fond bleu pétrole, quadrillage fin couleur crème, liseré.
## Le décor de l'onglet Plans du train (palette « plan d'atelier », couleurs du jeu).

const PAPER: Color = Color("#1c2a2d")
const INK: Color = Color("#e6dcc4")
const GOLD: Color = Color("#e8c25a")
const STAMP: Color = Color("#d0503c")
## Pas du quadrillage, en pixels de jeu.
const STEP: float = 8.0


func _init() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = Color(INK, 0.45)
	style.set_border_width_all(1)
	style.set_content_margin_all(5.0)
	add_theme_stylebox_override(&"panel", style)
	resized.connect(queue_redraw)


func _draw() -> void:
	var line := Color(INK, 0.07)
	var x: float = STEP
	while x < size.x - 1.0:
		draw_line(Vector2(x, 1.0), Vector2(x, size.y - 1.0), line)
		x += STEP
	var y: float = STEP
	while y < size.y - 1.0:
		draw_line(Vector2(1.0, y), Vector2(size.x - 1.0, y), line)
		y += STEP
