extends SceneTree
## Lance tous les tests sans ouvrir l'éditeur :
##   godot --headless --path . --script res://tests/run_tests.gd
## Code de sortie 0 = tout est vert, 1 = au moins un échec.
##
## Une erreur de script pendant un test (appel invalide, null...) le fait
## échouer : elle est interceptée par un Logger (Godot 4.5+).

const SUITES: Array[String] = [
	"res://tests/test_touch_controls.gd",
	"res://tests/test_touch_action_button.gd",
	"res://tests/test_stop_session.gd",
	"res://tests/test_exposure.gd",
	"res://tests/test_harvest.gd",
	"res://tests/test_zone_generator.gd",
	"res://tests/test_game_state.gd",
	"res://tests/test_encounters.gd",
	"res://tests/test_equipment.gd",
	"res://tests/test_train_interior.gd",
	"res://tests/test_train_rules.gd",
	"res://tests/test_refuge.gd",
	"res://tests/test_save.gd",
	"res://tests/test_combat.gd",
	"res://tests/test_career.gd",
	"res://tests/test_progression.gd",
	"res://tests/test_wagon_upgrades.gd",
	"res://tests/test_menus.gd",
	"res://tests/test_biomes.gd",
	"res://tests/test_rain.gd",
	"res://tests/test_horde.gd",
	"res://tests/test_night.gd",
	"res://tests/test_crew.gd",
	"res://tests/test_ranks.gd",
	"res://tests/test_missions.gd",
	"res://tests/test_intro.gd",
	"res://tests/test_drop.gd",
	"res://tests/test_bag_slots.gd",
	"res://tests/test_inventory.gd",
]


class ErrorCatcher extends Logger:
	var errors: Array[String] = []

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var message: String = rationale if not rationale.is_empty() else code
		errors.append("%s (%s:%d)" % [message, file, line])

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _initialize() -> void:
	# On attend la première frame : la fenêtre racine doit être dans l'arbre
	# pour recevoir de vrais évènements tactiles (Viewport.push_input).
	process_frame.connect(_run_all, CONNECT_ONE_SHOT)


func _run_all() -> void:
	# Les tests n'écrivent jamais dans les vraies sauvegardes du joueur.
	SaveStore.directory = "user://test_saves"
	var catcher := ErrorCatcher.new()
	OS.add_logger(catcher)
	var passed: int = 0
	var failed: int = 0

	for path: String in SUITES:
		print(path)
		var script := load(path) as GDScript
		if script == null:
			failed += 1
			print("  ÉCHEC  impossible de charger la suite")
			continue
		for method: Dictionary in script.get_script_method_list():
			var test_name: String = method["name"]
			if not test_name.begins_with("test_"):
				continue
			catcher.errors.clear()
			var suite: TestCase = script.new()
			suite.tree = self
			suite.before_each()
			suite.call(test_name)
			suite.after_each()
			var problems: Array[String] = suite.failures + catcher.errors
			if problems.is_empty():
				passed += 1
				print("  OK     ", test_name)
			else:
				failed += 1
				print("  ÉCHEC  ", test_name)
				for problem: String in problems:
					print("         - ", problem)

	OS.remove_logger(catcher)
	print("\n%d réussi(s), %d échoué(s)" % [passed, failed])
	quit(1 if failed > 0 else 0)
