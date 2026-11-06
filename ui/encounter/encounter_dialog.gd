extends CanvasLayer
## Fenêtre d'une rencontre : texte, choix, puis résultat.
##
## Utilisable au doigt, à la souris, à la manette et au clavier (boutons
## focalisables). Le temps d'arrêt continue de défiler : le train n'attend pas.
## La fenêtre ne décide de rien : elle émet le choix, la zone l'applique.
##
## Un échange se lit en cases (« [3 bois] → [2 ferrailles] ») plutôt qu'en phrase ; ce qui
## manque passe en rouge, la raison d'un refus (sac plein, couchette...) en deux mots.

signal choice_selected(choice: EncounterChoice)
signal closed

const PLAN: Texture2D = preload("res://assets/ui/icons/plan.png")

@onready var _root: Control = $Root
@onready var _title: Label = %Title
@onready var _text: Label = %Text
@onready var _choices: VBoxContainer = %Choices
@onready var _outcome: Label = %Outcome
@onready var _continue: Button = %Continue

var _encounter: EncounterData
var _carrying: ExpeditionResult
var _capacity: int = -1
var _free_beds: int = -1
var _can_recruit: bool = true
var _return_to_choices: bool = false
## Ce qu'un choix a rapporté, en cases, sous le texte du résultat.
var _gains: HFlowContainer


func _ready() -> void:
	_root.visible = false
	_continue.pressed.connect(_on_continue_pressed)
	_gains = MenuKit.grid()
	_gains.name = "Gains"
	_gains.visible = false
	_outcome.add_sibling(_gains)


func is_open() -> bool:
	return _root.visible


## Affiche une rencontre. `carrying` : ce que le joueur porte, pour griser ce qu'il ne peut
## pas payer ; `capacity` : taille du sac (-1 = illimité) ; `free_beds` : couchettes libres
## dans le train (-1 = illimité).
func open(encounter: EncounterData, carrying: ExpeditionResult, capacity: int = -1, free_beds: int = -1,
		can_recruit: bool = true) -> void:
	_can_recruit = can_recruit
	_encounter = encounter
	_carrying = carrying
	_capacity = capacity
	_free_beds = free_beds
	_title.text = encounter.title
	_text.text = encounter.text
	_outcome.visible = false
	_gains.visible = false
	_continue.visible = false
	_build_choices()
	_root.visible = true


## Affiche le résultat d'un choix. `return_to_choices` : revenir aux choix ensuite (marchand).
func show_outcome(text: String, gained: Dictionary[StringName, int], return_to_choices: bool, item: ItemData = null,
		plan: StringName = &"") -> void:
	var lines: PackedStringArray = [text]
	if item:
		lines.append("Obtenu : %s (%s)" % [item.display_name, item.describe_effects()])
	if plan != &"":
		lines.append("Plan trouvé : %s (à étudier à la table des plans)" % BlueprintCatalog.get_plan(plan).display_name)
	_outcome.text = "\n".join(lines)
	_outcome.visible = true
	# Ce qu'on a gagné, en cases : +2 ferrailles se voit d'un coup d'œil.
	MenuKit.clear(_gains)
	for id: StringName in gained:
		var data: LootData = MenuKit.loot(id)
		_gains.add_child(SlotCell.create(data.icon if data else null, "+%d" % gained[id], "+%d %s" % [gained[id], loot_name(id)], false))
	if item:
		_gains.add_child(SlotCell.create(item.icon, "", item.display_name, false))
	if plan != &"":
		_gains.add_child(SlotCell.create(BlueprintCatalog.icon(plan), "", BlueprintCatalog.get_plan(plan).display_name, false).set_corner(PLAN))
	_gains.visible = _gains.get_child_count() > 0
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
	MenuKit.clear(_choices)
	_choices.visible = true
	var first_enabled: Button = null
	for choice: EncounterChoice in _encounter.choices:
		var lacking := EncounterResolver.missing(choice, _carrying, _capacity, _free_beds, _can_recruit)
		var button := _choice_button(choice, lacking)
		button.pressed.connect(func() -> void: choice_selected.emit(choice))
		_choices.add_child(button)
		if first_enabled == null and not button.disabled:
			first_enabled = button
	if first_enabled:
		MenuKit.focus_later(first_enabled)


## Un choix. Un échange s'affiche en cases (donne → reçois) ; les autres gardent leur
## phrase, suivie de leur coût en cases. Le bouton s'élargit à son contenu.
func _choice_button(choice: EncounterChoice, lacking: Dictionary[StringName, int]) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0.0, 22.0)
	button.disabled = not lacking.is_empty()
	button.tooltip_text = choice.label
	var content := HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 6.0
	content.offset_right = -6.0
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override(&"separation", 3)
	if _is_trade(choice):
		content.add_child(MenuKit.cost_row(choice.cost, _have(choice.cost)))
		content.add_child(MenuKit.icon(MenuKit.ARROW, 12.0))
		if not choice.reward.is_empty():
			content.add_child(MenuKit.cost_row(choice.reward))
		if choice.reward_item:
			content.add_child(MenuKit.icon(choice.reward_item.icon, 12.0))
			content.add_child(MenuKit.label(choice.reward_item.display_name))
		if choice.reward_plan != &"":
			content.add_child(MenuKit.icon(PLAN, 12.0))
			content.add_child(MenuKit.label("Plan « %s »" % BlueprintCatalog.get_plan(choice.reward_plan).display_name))
	else:
		content.add_child(MenuKit.label(choice.label))
		if not choice.cost.is_empty():
			content.add_child(MenuKit.cost_row(choice.cost, _have(choice.cost)))
	var reason: String = _reason(lacking)
	if not reason.is_empty():
		content.add_child(MenuKit.label(reason, MenuKit.BAD))
	if button.disabled:
		content.modulate = Color(1.0, 1.0, 1.0, 0.5)
	_ignore_mouse(content)
	button.add_child(content)
	# Un bouton ne mesure pas ses enfants : on lui donne la largeur du contenu.
	var fit := func() -> void: button.custom_minimum_size.x = content.get_combined_minimum_size().x + 12.0
	content.minimum_size_changed.connect(fit)
	fit.call()
	return button


## Un échange pur : on donne des ressources, on reçoit des ressources, un objet ou un plan.
static func _is_trade(choice: EncounterChoice) -> bool:
	return not choice.cost.is_empty() and not choice.leave and not choice.recruits() \
		and choice.random_reward_pool.is_empty() and choice.exposure <= 0.0 \
		and (not choice.reward.is_empty() or choice.reward_item != null or choice.reward_plan != &"")


## Ce que le joueur porte, pour les ressources d'un coût (nombre en rouge s'il en manque).
func _have(cost: Dictionary[StringName, int]) -> Variant:
	if _carrying == null:
		return null
	var have: Dictionary[StringName, int] = {}
	for id: StringName in cost:
		have[id] = _carrying.get_amount(id)
	return have


## La raison d'un refus qui ne se voit pas dans les cases (il manque : nombre en rouge).
static func _reason(lacking: Dictionary[StringName, int]) -> String:
	if lacking.has(EncounterResolver.NO_RANK):
		return "grade " + Career.required_grade(&"recruit")
	if lacking.has(EncounterResolver.NO_BED):
		return "pas de couchette"
	if lacking.has(EncounterResolver.NO_SPACE):
		return "sac plein"
	return ""


static func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_ignore_mouse(child)


func _on_continue_pressed() -> void:
	if _return_to_choices:
		open(_encounter, _carrying, _capacity, _free_beds, _can_recruit)
	else:
		close()


static func loot_name(id: StringName) -> String:
	for loot: LootData in GameState.LOOT_TYPES:
		if loot.id == id:
			return loot.display_name
	return String(id)
