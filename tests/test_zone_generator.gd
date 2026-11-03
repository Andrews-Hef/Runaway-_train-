extends TestCase
## Le générateur de zones : reproductible, et toujours dans les règles du profil.

const ZONES: Array[ZoneProfile] = [
	preload("res://data/zones/plains.tres"),
	preload("res://data/zones/dead_forest.tres"),
	preload("res://data/zones/scrapyard.tres"),
	preload("res://data/zones/blight.tres"),
]
const KINDS: Array[StringName] = [&"wreck", &"dead_tree", &"rock", &"herb", &"infected_herb"]
## Plusieurs graines par profil, pour ne pas valider un cas chanceux.
const SEEDS: Array[int] = [1, 42, 1337, 98765, 2026]


func _signature(layout: ZoneGenerator.Layout) -> String:
	var parts: PackedStringArray = [str(layout.stop_duration), str(hash(layout.tiles))]
	for spawn: ZoneGenerator.Spawn in layout.spawns:
		parts.append("%s@%s" % [spawn.kind, spawn.position])
	return "|".join(parts)


func test_meme_graine_meme_zone() -> void:
	var a := ZoneGenerator.generate(ZONES[0], 42)
	var b := ZoneGenerator.generate(ZONES[0], 42)
	assert_true(_signature(a) == _signature(b), "deux générations identiques")


func test_graines_differentes_zones_differentes() -> void:
	var a := ZoneGenerator.generate(ZONES[0], 1)
	var b := ZoneGenerator.generate(ZONES[0], 2)
	assert_true(_signature(a) != _signature(b), "les zones doivent différer")


func test_le_nombre_d_objets_ne_depasse_jamais_le_profil() -> void:
	for zone: ZoneProfile in ZONES:
		for zone_seed: int in SEEDS:
			var layout := ZoneGenerator.generate(zone, zone_seed)
			for kind: StringName in KINDS:
				var range_: Vector2i = zone.count_range(kind)
				var count: int = layout.count(kind)
				assert_true(count <= range_.y, "%s/%s : %d > max %d" % [zone.id, kind, count, range_.y])


func test_la_zone_est_bien_remplie() -> void:
	# Le placement peut manquer de place, mais pas au point de vider la zone.
	for zone: ZoneProfile in ZONES:
		for zone_seed: int in SEEDS:
			var layout := ZoneGenerator.generate(zone, zone_seed)
			for kind: StringName in [&"wreck", &"dead_tree", &"rock", &"herb"]:
				var minimum: int = zone.count_range(kind).x
				assert_true(layout.count(kind) >= minimum, "%s/%s (graine %d) : %d < min %d" % [zone.id, kind, zone_seed, layout.count(kind), minimum])
			assert_true(layout.count(&"infected_herb") > 0, "%s (graine %d) : aucune plante infectée" % [zone.id, zone_seed])


func test_chaque_objet_respecte_son_sol() -> void:
	for zone: ZoneProfile in ZONES:
		for zone_seed: int in SEEDS:
			var layout := ZoneGenerator.generate(zone, zone_seed)
			for spawn: ZoneGenerator.Spawn in layout.spawns:
				var infected: bool = layout.is_infected_at(spawn.position)
				if spawn.kind == &"infected_herb":
					assert_true(infected, "%s : plante infectée hors du violet en %s" % [zone.id, spawn.position])
				elif spawn.kind != &"rock":
					assert_false(infected, "%s : %s sur le violet en %s" % [zone.id, spawn.kind, spawn.position])


func test_la_voie_et_le_quai_sont_degages() -> void:
	var min_y: float = (ZoneGenerator.RAILS_ROW + ZoneGenerator.PLATFORM_ROWS + 1) * ZoneGenerator.TILE_SIZE
	for zone: ZoneProfile in ZONES:
		var layout := ZoneGenerator.generate(zone, 7)
		for x: int in layout.size_in_tiles.x:
			assert_true(layout.tile_at(Vector2i(x, ZoneGenerator.RAILS_ROW)) == ZoneGenerator.Tile.RAILS, "rails en x=%d" % x)
			for y: int in range(ZoneGenerator.RAILS_ROW + 1, ZoneGenerator.RAILS_ROW + ZoneGenerator.PLATFORM_ROWS + 1):
				assert_true(layout.tile_at(Vector2i(x, y)) != ZoneGenerator.Tile.INFECTED, "quai infecté en (%d, %d)" % [x, y])
		for spawn: ZoneGenerator.Spawn in layout.spawns:
			assert_true(spawn.position.y >= min_y, "%s sur le quai en %s" % [spawn.kind, spawn.position])


func test_les_objets_sont_espaces() -> void:
	var layout := ZoneGenerator.generate(ZONES[2], 1337) # la casse : beaucoup de grosses épaves
	for i: int in layout.spawns.size():
		for j: int in range(i + 1, layout.spawns.size()):
			var a: ZoneGenerator.Spawn = layout.spawns[i]
			var b: ZoneGenerator.Spawn = layout.spawns[j]
			var spacing: float = ZoneGenerator.RULES[b.kind][1]
			assert_true(a.position.distance_to(b.position) >= spacing - 0.01, "%s et %s trop proches" % [a.kind, b.kind])


func test_la_duree_d_arret_suit_le_profil() -> void:
	for zone: ZoneProfile in ZONES:
		for zone_seed: int in SEEDS:
			var duration: float = ZoneGenerator.generate(zone, zone_seed).stop_duration
			assert_true(duration >= zone.stop_duration.x and duration <= zone.stop_duration.y, "%s : %.0f s" % [zone.id, duration])


func test_les_points_reserves_restent_degages() -> void:
	var spawn := Vector2(204.0, 128.0)
	for zone: ZoneProfile in ZONES:
		for zone_seed: int in SEEDS:
			var layout := ZoneGenerator.generate(zone, zone_seed, [spawn])
			for s: ZoneGenerator.Spawn in layout.spawns:
				assert_true(s.position.distance_to(spawn) >= ZoneGenerator.RESERVED_RADIUS, "%s trop près du joueur" % s.kind)
