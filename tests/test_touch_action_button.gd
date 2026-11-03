extends TestCase
## Un bouton tactile doit déclencher l'action comme la touche clavier correspondante.

var _button: TouchActionButton


func before_each() -> void:
	_button = TouchActionButton.new()
	_button.action = &"attack"
	tree.root.add_child(_button)


func after_each() -> void:
	_button.free()
	Input.action_release(&"attack")


func _touch(index: int, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	_button._gui_input(event)
	Input.flush_buffered_events()


func test_appui_declenche_l_action() -> void:
	_touch(0, true)
	assert_true(Input.is_action_pressed(&"attack"), "attack doit être pressée")
	assert_true(_button.is_held(), "le bouton doit être maintenu")


func test_relacher_le_doigt_relache_l_action() -> void:
	_touch(0, true)
	_touch(0, false)
	assert_false(Input.is_action_pressed(&"attack"), "attack doit être relâchée")


func test_un_autre_doigt_ne_relache_pas_le_bouton() -> void:
	_touch(0, true)
	_touch(1, false)
	assert_true(Input.is_action_pressed(&"attack"), "attack doit rester pressée")
