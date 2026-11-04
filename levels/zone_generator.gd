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
## Aucun ennemi ne commence aussi près de l'apparition du joueur.
const ENEMY_SAFE_RADIUS: float = 150.0

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


## Ennemis : [placement, espacement minimal en px]. Placés après le décor.
const ENEMY_RULES: Dictionary[StringName, Array] = {
	&"infected": [Placement.INFECTED, 40.0],
	&"raider": [Placement.HEALTHY, 64.0],
}


## Taille au sol de chaque point d'intérêt, en pixels.
const POI_SIZES: Dictionary[StringName, Vector2] = {
	&"village": Vector2(208.0, 120.0),
	&"refuge": Vector2(72.0, 52.0),
	&"merchant": Vector2(72.0, 52.0),
	&"lone_event": Vector2(28.0, 28.0),
}
## Écart minimal entre deux points d'intérêt, en pixels.
const POI_GAP: float = 24.0
## Plan d'un village : maisons et caches, relatifs au coin haut-gauche du village.
const VILLAGE_HOUSES: Array[Vector2] = [Vector2(40.0, 40.0), Vector2(128.0, 30.0), Vector2(170.0, 100.0)]
const VILLAGE_CACHES: Array[Vector2] = [Vector2(86.0, 78.0), Vector2(30.0, 104.0), Vector2(118.0, 104.0)]
## Endroit d'une petite rencontre (sac abandonné) dans le village.
const VILLAGE_EVENT: Vector2 = Vector2(176.0, 56.0)
## Types de petites rencontres possibles (chacun a son pool dans EncounterLibrary).
const LONE_EVENT_KINDS: Array[StringName] = [&"backpack", &"locker"]


## Un objet à faire apparaître.
class Spawn:
	var kind: StringName
	var position: Vector2
	## Donnée en plus selon le type : identifiant de rencontre pour un PNJ ou un sac.
	var data: StringName

	func _init(spawn_kind: StringName, spawn_position: Vector2, spawn_data: StringName = &"") -> void:
		kind = spawn_kind
		position = spawn_position
		data = spawn_data


## Un point d'intérêt : village, refuge, marchand, rencontre isolée.
class Poi:
	var kind: StringName
	var rect: Rect2

	func _init(poi_kind: StringName, poi_rect: Rect2) -> void:
		kind = poi_kind
		rect = poi_rect


## Le plan complet d'une zone.
class Layout:
	var size_in_tiles: Vector2i
	## Tuile de chaque cellule, ligne par ligne (index = y * largeur + x).
	var tiles: PackedInt32Array
	var spawns: Array[Spawn] = []
	var pois: Array[Poi] = []
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

	func has_poi(kind: StringName) -> bool:
		for poi: Poi in pois:
			if poi.kind == kind:
				return true
		return false

	## Le point est-il dans (ou tout près de) un point d'intérêt ?
	func is_in_poi(world_position: Vector2, margin: float = 8.0) -> bool:
		for poi: Poi in pois:
			if poi.rect.grow(margin).has_point(world_position):
				return true
		return false


## reserved : points à garder dégagés (ex. l'apparition du joueur), voir RESERVED_RADIUS.
static func generate(profile: ZoneProfile, zone_seed: int, reserved: Array[Vector2] = []) -> Layout:
	var rng := RandomNumberGenerator.new()
	rng.seed = zone_seed
	var layout := Layout.new()
	layout.size_in_tiles = profile.size_in_tiles
	layout.stop_duration = roundf(rng.randf_range(profile.stop_duration.x, profile.stop_duration.y))

	_place_pois(layout, profile, rng)
	_place_infected_patches(layout, profile, rng, reserved)
	_paint_tiles(layout, profile, rng, reserved)
	_fill_pois(layout, rng)

	var occupied: Array[Vector2] = []
	for spawn: Spawn in layout.spawns:
		occupied.append(spawn.position)
	for kind: StringName in RULES:
		var range_: Vector2i = profile.count_range(kind)
		var wanted: int = rng.randi_range(range_.x, range_.y)
		_scatter(layout, kind, wanted, rng, occupied, reserved)
	# Les ennemis en dernier : le décor d'une graine ne change pas quand on règle les ennemis.
	for kind: StringName in ENEMY_RULES:
		var range_: Vector2i = profile.count_range(kind)
		var wanted: int = rng.randi_range(range_.x, range_.y)
		_scatter(layout, kind, wanted, rng, occupied, reserved, ENEMY_RULES[kind], ENEMY_SAFE_RADIUS)
	return layout


# --- Points d'intérêt ------------------------------------------------------------

static func _place_pois(layout: Layout, profile: ZoneProfile, rng: RandomNumberGenerator) -> void:
	var wanted: Array[StringName] = []
	if rng.randf() < profile.village_chance:
		wanted.append(&"village")
	if rng.randf() < profile.refuge_chance:
		wanted.append(&"refuge")
	if rng.randf() < profile.merchant_chance:
		wanted.append(&"merchant")
	for i: int in rng.randi_range(profile.lone_events.x, profile.lone_events.y):
		wanted.append(&"lone_event")

	var size_px := Vector2(layout.size_in_pixels())
	var min_y: float = (RAILS_ROW + PLATFORM_ROWS + 2) * TILE_SIZE
	for kind: StringName in wanted:
		var poi_size: Vector2 = POI_SIZES[kind]
		for attempt: int in 40:
			var origin := Vector2(
				rng.randf_range(BORDER * TILE_SIZE, size_px.x - BORDER * TILE_SIZE - poi_size.x),
				rng.randf_range(min_y, size_px.y - BORDER * TILE_SIZE - poi_size.y)
			).round()
			var rect := Rect2(origin, poi_size)
			if _overlaps_poi(layout, rect.grow(POI_GAP)):
				continue
			layout.pois.append(Poi.new(kind, rect))
			break


static func _overlaps_poi(layout: Layout, rect: Rect2) -> bool:
	for poi: Poi in layout.pois:
		if poi.rect.intersects(rect):
			return true
	return false


## Remplit chaque point d'intérêt avec ses objets et ses rencontres.
static func _fill_pois(layout: Layout, rng: RandomNumberGenerator) -> void:
	for poi: Poi in layout.pois:
		var center: Vector2 = poi.rect.get_center()
		match poi.kind:
			&"village":
				var mirrored: bool = rng.randf() < 0.5
				for point: Vector2 in VILLAGE_HOUSES:
					layout.spawns.append(Spawn.new(&"house", _village_point(poi.rect, point, mirrored, rng)))
				for point: Vector2 in VILLAGE_CACHES:
					layout.spawns.append(Spawn.new(&"cache", _village_point(poi.rect, point, mirrored, rng)))
				if rng.randf() < 0.6:
					var event_kind: StringName = LONE_EVENT_KINDS[rng.randi_range(0, LONE_EVENT_KINDS.size() - 1)]
					layout.spawns.append(Spawn.new(event_kind, _village_point(poi.rect, VILLAGE_EVENT, mirrored, rng), _pick_encounter(event_kind, rng)))
			&"refuge":
				layout.spawns.append(Spawn.new(&"shelter", center + Vector2(0.0, -8.0)))
				layout.spawns.append(Spawn.new(&"refugee", center + Vector2(10.0, 16.0), _pick_encounter(&"refugee", rng)))
			&"merchant":
				layout.spawns.append(Spawn.new(&"cart", center + Vector2(0.0, -8.0)))
				layout.spawns.append(Spawn.new(&"merchant", center + Vector2(-14.0, 16.0), _pick_encounter(&"merchant", rng)))
			&"lone_event":
				var event_kind: StringName = LONE_EVENT_KINDS[rng.randi_range(0, LONE_EVENT_KINDS.size() - 1)]
				layout.spawns.append(Spawn.new(event_kind, center, _pick_encounter(event_kind, rng)))
			_:
				push_warning("Point d'intérêt inconnu : %s" % poi.kind)


static func _village_point(rect: Rect2, point: Vector2, mirrored: bool, rng: RandomNumberGenerator) -> Vector2:
	var local: Vector2 = point
	if mirrored:
		local.x = rect.size.x - point.x
	var jitter := Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-3.0, 3.0))
	return (rect.position + local + jitter).round()


static func _pick_encounter(pool_kind: StringName, rng: RandomNumberGenerator) -> StringName:
	var pool: Array = EncounterLibrary.POOLS.get(pool_kind, [])
	if pool.is_empty():
		return &""
	return pool[rng.randi_range(0, pool.size() - 1)]


# --- Sol --------------------------------------------------------------------------

static func _place_infected_patches(layout: Layout, profile: ZoneProfile, rng: RandomNumberGenerator, reserved: Array[Vector2]) -> void:
	var count: int = rng.randi_range(profile.infected_patches.x, profile.infected_patches.y)
	var min_y: float = RAILS_ROW + PLATFORM_ROWS + 2.0
	for i: int in count:
		var radius: float = rng.randf_range(profile.infected_radius.x, profile.infected_radius.y)
		# On évite de recouvrir un point d'intérêt (le village reste praticable).
		for attempt: int in 30:
			var center := Vector2(
				rng.randf_range(BORDER + 2.0, layout.size_in_tiles.x - BORDER - 2.0),
				rng.randf_range(min_y, layout.size_in_tiles.y - BORDER - 1.0)
			)
			if not _patch_touches_poi(layout, center, radius) and not _patch_touches_points(center, radius, reserved):
				layout.infected_patches.append(Vector3(center.x, center.y, radius))
				break


## Le joueur ne doit pas apparaître dans (ni au bord de) une zone infectée.
static func _patch_touches_points(center_tiles: Vector2, radius_tiles: float, points: Array[Vector2]) -> bool:
	var reach: float = (radius_tiles + 1.0) * TILE_SIZE + RESERVED_RADIUS
	for point: Vector2 in points:
		if (center_tiles * TILE_SIZE).distance_to(point) < reach:
			return true
	return false


static func _patch_touches_poi(layout: Layout, center_tiles: Vector2, radius_tiles: float) -> bool:
	var center: Vector2 = center_tiles * TILE_SIZE
	var reach: float = (radius_tiles + 1.5) * TILE_SIZE
	for poi: Poi in layout.pois:
		var closest := Vector2(
			clampf(center.x, poi.rect.position.x, poi.rect.end.x),
			clampf(center.y, poi.rect.position.y, poi.rect.end.y)
		)
		if center.distance_to(closest) < reach:
			return true
	return false


static func _paint_tiles(layout: Layout, profile: ZoneProfile, rng: RandomNumberGenerator, reserved: Array[Vector2]) -> void:
	var size: Vector2i = layout.size_in_tiles
	layout.tiles.resize(size.x * size.y)
	for y: int in size.y:
		for x: int in size.x:
			var tile: int = _pick_tile(Vector2i(x, y), layout, profile, rng)
			# Filet de sécurité : jamais de sol infecté autour d'un point réservé.
			if tile == Tile.INFECTED:
				var cell_center := (Vector2(x, y) + Vector2(0.5, 0.5)) * TILE_SIZE
				for point: Vector2 in reserved:
					if cell_center.distance_to(point) < RESERVED_RADIUS:
						tile = Tile.GRASS_A
			layout.tiles[y * size.x + x] = tile


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
		occupied: Array[Vector2], reserved: Array[Vector2], rule: Array = [], reserved_radius: float = RESERVED_RADIUS) -> void:
	if rule.is_empty():
		rule = RULES[kind]
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
		if not _is_free(pos, reserved_radius, reserved):
			continue
		if layout.is_in_poi(pos):
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
