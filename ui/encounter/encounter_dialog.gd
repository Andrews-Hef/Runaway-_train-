extends CanvasLayer
## Fenêtre d'une rencontre : texte, choix, puis résultat.
##
## Utilisable au doigt, à la souris, à la manette et au clavier (boutons
## focalisables). Le temps d'arrêt continue de défiler : le train n'attend pas.
## La fenêtre ne décide de rien : elle émet le choix, la zone l'applique.

signal choice_selected(choice: EncounterChoice)
signal closed

@onready var _root: Control = $Root
@onready var _title: Label = %Title
@onready var _text: Label = %Text
@onready var _choices: VBoxContainer = %Choices
@onready var _outcome: Label = %Outcome
@onready var _continue: Button = %Continue

var _encounter: EncounterData
var _carrying: ExpeditionResult
var _capacity: int = -1
var _return_to_choices: bool = false


func _ready() -> void:
	_root.visible = false
	_continue.pressed.connect(_on_continue_pressed)


func is_open() -> bool:
	return _root.visible


## Affiche une rencontre. `carrying` : ce que le joueur porte, pour griser ce qu'il ne peut
## pas payer ; `capacity` : taille du sac (-1 = illimité).
func open(encounter: EncounterData, carrying: ExpeditionResult, capacity: int = -1) -> void:
	_encounter = encounter
	_carrying = carrying
	_capacity = capacity
	_title.text = encounter.title
	_text.text = encounter.text
	_outcome.visible = false
	_continue.visible = false
	_build_choices()
	_root.visible = true


## Affiche le résultat d'un choix. `return_to_choices` : revenir aux choix ensuite (marchand).
func show_outcome(text: String, gained: Dictionary[StringName, int], return_to_choices: bool, item: ItemData = null) -> void:
	var lines: PackedStringArray = [text]
	for id: StringName in gained:
		lines.append("+%d %s" % [gained[id], loot_name(id)])
	if item:
		lines.append("Obtenu : %s (%s)" % [item.display_name, item.describe_effects()])
	_outcome.text = "\n".join(lines)
	_outcome.visible = true
	_choices.visible = false
	_continue.text = "Continuer" if return_to_choices else "Fermer"
	_continue.visible = true
	_return_to_choices = return_to_choices
	_continue.grab_focus()


func close() -> void:
	if not _root.visible:
		return
	_root.visible = false
	closed.emit()


func _build_choices() -> void:
	for child: Node in _choices.get_children():
		child.queue_free()
	_choices.visible = true
	var first_enabled: Button = null
	for choice: EncounterChoice in _encounter.choices:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, 18.0)
		button.text = choice.label
		var lacking := EncounterResolver.missing(choice, _carrying, _capacity)
		if not lacking.is_empty():
			button.disabled = true
			button.text += "  (il te manque %s)" % _describe(lacking)
		button.pressed.connect(func() -> void: choice_selected.emit(choice))
		_choices.add_child(button)
		if first_enabled == null and not button.disabled:
			first_enabled = button
	if first_enabled:
		first_enabled.grab_focus.call_deferred()


func _on_continue_pressed() -> void:
	if _return_to_choices:
		open(_encounter, _carrying, _capacity)
	else:
		close()


static func _describe(amounts: Dictionary[StringName, int]) -> String:
	if amounts.has(EncounterResolver.NO_SPACE):
		return "de la place dans ton sac"
	var parts: PackedStringArray = []
	for id: StringName in amounts:
		parts.append("%d %s" % [amounts[id], loot_name(id).to_lower()])
	return ", ".join(parts)


static func loot_name(id: StringName) -> String:
	for loot: LootData in GameState.LOOT_TYPES:
		if loot.id == id:
			return loot.display_name
	return String(id)
