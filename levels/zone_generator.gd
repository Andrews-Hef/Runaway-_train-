class_name ZoneGenerator
extends RefCounted
## Génère le plan d'une zone d'arrêt à partir d'un profil et d'une graine.
##
## Pur : aucun nœud, aucune scène. Même profil + même graine = même zone,
## ce qui rend la génération testable et les bugs reproductibles.
## La scène (stop_zone.gd) se contente d'appliquer le plan.

const TILE_SIZE: int = 16
## Ligne de tuiles occupée par la voie ferrée.
const RAILS_ROW: int = 4
## Lignes libres sous la voie : quai où le joueur apparaît, sans objet.
const PLATFORM_ROWS: int = 3
## Marge sans objet sur les bords de la carte, en tuiles.
const BORDER: int = 2
## Position du train (pivot de la voiture de queue), en pixels.
const TRAIN_POSITION: Vector2 = Vector2(3.0 * TILE_SIZE, (RAILS_ROW + 0.5) * TILE_SIZE)
## Rayon sans objet autour des points réservés (apparition du joueur...).
const RESERVED_RADIUS: float = 40.0

## Index des tuiles dans assets/tiles/ground_placeholder.png
enum Tile { GRASS_A, GRASS_B, DIRT, INFECTED, RAILS }
## Où un objet a le droit d'apparaître.
enum Placement { ANYWHERE, HEALTHY, INFECTED }

## Règles de placement par type d'objet : [placement, espacement minimal en px].
## L'ordre compte : les gros objets d'abord, pour qu'ils trouvent de la place.
const RULES: Dictionary[StringName, Array] = {
	&"wreck": [Placement.HEALTHY, 44.0],
	&"dead_tree": [Placement.HEALTHY, 26.0],
	&"rock": [Placement.ANYWHERE, 22.0],
	&"herb": [Placement.HEALTHY, 18.0],
	&"infected_herb": [Placement.INFECTED, 18.0],
}


## Un objet à faire apparaître.
class Spawn:
	var kind: StringName
	var position: Vector2

	func _init(spawn_kind: StringName, spawn_position: Vector2) -> void:
		kind = spawn_kind
		position = spawn_position


## Le plan complet d'une zone.
class Layout:
	var size_in_tiles: Vector2i
	## Tuile de chaque cellule, ligne par ligne (index = y * largeur + x).
	var tiles: PackedInt32Array
	var spawns: Array[Spawn] = []
	## Centre et rayon (en tuiles) de chaque zone infectée.
	var infected_patches: Array[Vector3] = []
	var stop_duration: float = 90.0
	## Position du train (pivot de la voiture de queue), en pixels.
	var train_position: Vector2 = TRAIN_POSITION

	func tile_at(cell: Vector2i) -> int:
		if cell.x < 0 or cell.y < 0 or cell.x >= size_in_tiles.x or cell.y >= size_in_tiles.y:
			return -1
		return tiles[cell.y * size_in_tiles.x + cell.x]

	func is_infected_at(world_position: Vector2) -> bool:
		return tile_at(Vector2i((world_position / TILE_SIZE).floor())) == Tile.INFECTED

	func count(kind: StringName) -> int:
		var total: int = 0
		for spawn: Spawn in spawns:
			if spawn.kind == kind:
				total += 1
		return total

	func size_in_pixels() -> Vector2i:
		return size_in_tiles * TILE_SIZE


## reserved : points à garder dégagés (ex. l'apparition du joueur), voir RESERVED_RADIUS.
static func generate(profile: ZoneProfile, zone_seed: int, reserved: Array[Vector2] = []) -> Layout:
	var rng := RandomNumberGenerator.new()
	rng.seed = zone_seed
	var layout := Layout.new()
	layout.size_in_tiles = profile.size_in_tiles
	layout.stop_duration = roundf(rng.randf_range(profile.stop_duration.x, profile.stop_duration.y))

	_place_infected_patches(layout, profile, rng)
	_paint_tiles(layout, profile, rng)

	var occupied: Array[Vector2] = []
	for kind: StringName in RULES:
		var range_: Vector2i = profile.count_range(kind)
		var wanted: int = rng.randi_range(range_.x, range_.y)
		_scatter(layout, kind, wanted, rng, occupied, reserved)
	return layout


static func _place_infected_patches(layout: Layout, profile: ZoneProfile, rng: RandomNumberGenerator) -> void:
	var count: int = rng.randi_range(profile.infected_patches.x, profile.infected_patches.y)
	var min_y: float = RAILS_ROW + PLATFORM_ROWS + 2.0
	for i: int in count:
		var radius: float = rng.randf_range(profile.infected_radius.x, profile.infected_radius.y)
		var center := Vector2(
			rng.randf_range(BORDER + 2.0, layout.size_in_tiles.x - BORDER - 2.0),
			rng.randf_range(min_y, layout.size_in_tiles.y - BORDER - 1.0)
		)
		layout.infected_patches.append(Vector3(center.x, center.y, radius))


static func _paint_tiles(layout: Layout, profile: ZoneProfile, rng: RandomNumberGenerator) -> void:
	var size: Vector2i = layout.size_in_tiles
	layout.tiles.resize(size.x * size.y)
	for y: int in size.y:
		for x: int in size.x:
			layout.tiles[y * size.x + x] = _pick_tile(Vector2i(x, y), layout, profile, rng)


static func _pick_tile(cell: Vector2i, layout: Layout, profile: ZoneProfile, rng: RandomNumberGenerator) -> int:
	if cell.y == RAILS_ROW:
		return Tile.RAILS
	# Pas d'infection sur le quai, juste sous le train.
	var on_platform: bool = cell.y > RAILS_ROW and cell.y <= RAILS_ROW + PLATFORM_ROWS
	if not on_platform:
		for patch: Vector3 in layout.infected_patches:
			var distance: float = Vector2(cell).distance_to(Vector2(patch.x, patch.y))
			# Lisière irrégulière : on mélange infecté et sain sur le bord.
			if distance < patch.z - 1.0 or (distance < patch.z + 1.0 and rng.randf() < 0.5):
				return Tile.INFECTED
	var roll: float = rng.randf()
	if roll < profile.dirt_ratio:
		return Tile.DIRT
	if roll < profile.dirt_ratio + profile.grass_variant_ratio:
		return Tile.GRASS_B
	return Tile.GRASS_A


static func _scatter(layout: Layout, kind: StringName, wanted: int, rng: RandomNumberGenerator,
		occupied: Array[Vector2], reserved: Array[Vector2]) -> void:
	var rule: Array = RULES[kind]
	var placement: Placement = rule[0]
	var spacing: float = rule[1]
	var size_px := Vector2(layout.size_in_pixels())
	var min_y: float = (RAILS_ROW + PLATFORM_ROWS + 1) * TILE_SIZE
	var placed: int = 0
	var attempts: int = 0
	while placed < wanted and attempts < wanted * 60:
		attempts += 1
		var pos := Vector2(
			rng.randf_range(BORDER * TILE_SIZE, size_px.x - BORDER * TILE_SIZE),
			rng.randf_range(min_y, size_px.y - BORDER * TILE_SIZE)
		).round()
		if not _placement_allows(layout, placement, pos) or not _is_free(pos, spacing, occupied):
			continue
		if not _is_free(pos, RESERVED_RADIUS, reserved):
			continue
		layout.spawns.append(Spawn.new(kind, pos))
		occupied.append(pos)
		placed += 1


static func _placement_allows(layout: Layout, placement: Placement, pos: Vector2) -> bool:
	match placement:
		Placement.HEALTHY:
			return not layout.is_infected_at(pos)
		Placement.INFECTED:
			return layout.is_infected_at(pos)
		_:
			return true


static func _is_free(pos: Vector2, spacing: float, occupied: Array[Vector2]) -> bool:
	for other: Vector2 in occupied:
		if pos.distance_to(other) < spacing:
			return false
	return true
