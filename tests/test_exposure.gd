extends TestCase
## L'exposition monte sur le sol infecté et quand on récolte du violet, jamais au-delà de 100 %.

const TILE_SET: TileSet = preload("res://assets/tiles/ground_tileset.tres")
const INFECTED_TILE := Vector2i(3, 0)
const GRASS_TILE := Vector2i(0, 0)

var _ground: InfectionGround
var _body: Node2D
var _exposure: ExposureComponent


func before_each() -> void:
	_ground = InfectionGround.new()
	_ground.tile_set = TILE_SET
	_ground.set_cell(Vector2i(0, 0), 0, GRASS_TILE)
	_ground.set_cell(Vector2i(1, 0), 0, INFECTED_TILE)
	tree.root.add_child(_ground)

	_body = Node2D.new()
	_exposure = ExposureComponent.new()
	_exposure.ground = _ground
	_exposure.ground_rate = 0.1
	_body.add_child(_exposure)
	tree.root.add_child(_body)


func after_each() -> void:
	_body.free()
	_ground.free()


func test_le_sol_connait_son_infection() -> void:
	assert_almost(_ground.get_infection_at(Vector2(8.0, 8.0)), 0.0, "herbe")
	assert_almost(_ground.get_infection_at(Vector2(24.0, 8.0)), 1.0, "sol violet")
	assert_almost(_ground.get_infection_at(Vector2(-50.0, -50.0)), 0.0, "hors de la carte")


func test_rien_ne_monte_sur_l_herbe() -> void:
	_body.position = Vector2(8.0, 8.0)
	_exposure._physics_process(1.0)
	assert_almost(_exposure.value, 0.0, "exposition")
	assert_false(_exposure.in_infected_zone, "pas en zone infectée")


func test_l_exposition_monte_sur_le_sol_infecte() -> void:
	_body.position = Vector2(24.0, 8.0)
	_exposure._physics_process(2.0)
	assert_almost(_exposure.value, 0.2, "2 s à 0,1/s")
	assert_true(_exposure.in_infected_zone, "en zone infectée")


func test_l_exposition_plafonne_a_100_pourcent() -> void:
	_exposure.add(0.7)
	_exposure.add(0.7)
	assert_almost(_exposure.value, 1.0, "plafond")
