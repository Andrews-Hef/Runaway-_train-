class_name InfectionGround
extends TileMapLayer
## Sol qui connaît son niveau d'infection.
##
## L'infection est une donnée de tuile (custom data « infection », de 0 à 1)
## définie dans le TileSet : peindre une tuile violette suffit à rendre la zone dangereuse.

const INFECTION_LAYER: String = "infection"


## Niveau d'infection (0 à 1) du sol sous une position du monde.
func get_infection_at(world_position: Vector2) -> float:
	var cell: Vector2i = local_to_map(to_local(world_position))
	var data: TileData = get_cell_tile_data(cell)
	if data == null or not tile_set.has_custom_data_layer_by_name(INFECTION_LAYER):
		return 0.0
	return data.get_custom_data(INFECTION_LAYER)
