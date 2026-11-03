extends TestCase
## Les contrôles tactiles doivent produire les mêmes actions que le clavier ou la manette.
## On simule de vrais doigts via Viewport.push_input, comme sur un téléphone.

const TOUCH_CONTROLS: PackedScene = preload("res://ui/touch/touch_controls.tscn")
const MOVE_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]

var _controls: CanvasLayer
var _joystick: VirtualJoystick


func before_each() -> void:
	_controls = TOUCH_CONTROLS.instantiate()
	tree.root.add_child(_controls)
	(_controls.get_node("Root") as Control).visible = true # pas d'écran tactile en headless
	_joystick = _controls.get_node("Root/Joystick")


func after_each() -> void:
	_touch(0, _zone_center(), false)
	_controls.free()
	for action: StringName in MOVE_ACTIONS:
		Input.action_release(action)


func _zone_center() -> Vector2:
	return _joystick.get_global_rect().get_center()


func _touch(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	tree.root.push_input(event)
	Input.flush_buffered_events()


func _drag(index: int, position: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	event.relative = relative
	tree.root.push_input(event)
	Input.flush_buffered_events()


func test_joystick_branche_sur_les_actions_du_jeu() -> void:
	assert_true(_joystick.action_left == &"move_left", "action_left")
	assert_true(_joystick.action_right == &"move_right", "action_right")
	assert_true(_joystick.action_up == &"move_up", "action_up")
	assert_true(_joystick.action_down == &"move_down", "action_down")


func test_glisser_a_droite_fait_avancer_a_droite() -> void:
	var start: Vector2 = _zone_center()
	var offset := Vector2(_joystick.joystick_size, 0.0)
	_touch(0, start, true)
	_drag(0, start + offset, offset)
	var direction: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	assert_true(direction.x > 0.9, "direction.x devrait être ~1, obtenu %.3f" % direction.x)
	assert_almost(direction.y, 0.0, "direction.y", 0.05)


func test_lever_le_doigt_arrete_le_mouvement() -> void:
	var start: Vector2 = _zone_center()
	var offset := Vector2(0.0, -_joystick.joystick_size)
	_touch(0, start, true)
	_drag(0, start + offset, offset)
	_touch(0, start + offset, false)
	for action: StringName in MOVE_ACTIONS:
		assert_almost(Input.get_action_raw_strength(action), 0.0, action)


func test_bouton_coup_pendant_que_le_joystick_est_tenu() -> void:
	var start: Vector2 = _zone_center()
	var offset := Vector2(_joystick.joystick_size, 0.0)
	_touch(0, start, true)
	_drag(0, start + offset, offset)
	var attack := _controls.get_node("Root/AttackButton") as Control
	_touch(1, attack.get_global_rect().get_center(), true)
	assert_true(Input.is_action_pressed(&"attack"), "attack pressée avec un 2e doigt")
	assert_true(Input.get_action_raw_strength(&"move_right") > 0.9, "move_right toujours tenu")
	_touch(1, attack.get_global_rect().get_center(), false)
