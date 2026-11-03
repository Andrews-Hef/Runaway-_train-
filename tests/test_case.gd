class_name TestCase
extends RefCounted
## Base minimale pour les tests headless, sans dépendance externe.
## Chaque méthode qui commence par `test_` est exécutée par tests/run_tests.gd,
## sur une instance neuve, entre before_each() et after_each().

## Arbre de scène du runner : pour ajouter des nœuds pendant un test.
var tree: SceneTree
var failures: Array[String] = []


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func assert_true(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func assert_false(condition: bool, message: String) -> void:
	if condition:
		failures.append(message)


func assert_almost(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s : attendu %.3f, obtenu %.3f" % [message, expected, actual])
