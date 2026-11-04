extends CanvasLayer
## Écran de fin de sortie : bilan du butin, de l'exposition et du risque d'infection.
## Il reste actif quand le jeu est en pause.

## Sortie réussie : on continue vers le prochain arrêt.
signal continue_requested
## Train raté : on reprend à la dernière gare refuge.
signal retry_requested

const RISK_LOW: Color = Color(0.55, 0.85, 0.45)
const RISK_MEDIUM: Color = Color(1.0, 0.8, 0.35)
const RISK_HIGH: Color = Color(1.0, 0.45, 0.35)

@onready var _root: Control = $Root
@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _loot_list: VBoxContainer = %LootList
@onready var _exposure: Label = %Exposure
@onready var _risk: Label = %Risk
@onready var _storage: Label = %Storage
@onready var _button: Button = %Restart

var _boarded: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	_button.pressed.connect(_on_button_pressed)


func _on_button_pressed() -> void:
	if _boarded:
		continue_requested.emit()
	else:
		retry_requested.emit()


func show_result(result: ExpeditionResult, loot_types: Array[LootData]) -> void:
	for child: Node in _loot_list.get_children():
		child.queue_free()

	var exposure_percent: int = roundi(result.exposure * 100.0)
	_exposure.text = "Exposition : %d %%" % exposure_percent

	_boarded = result.boarded
	if result.boarded:
		_title.text = "De retour à bord"
		_subtitle.text = "Le capitaine attend ton rapport."
		if result.total_items() == 0 and result.recruits.is_empty() and result.items.is_empty():
			_add_line("Tu reviens les mains vides.", Color(0.7, 0.7, 0.7))
		for loot: LootData in loot_types:
			var amount: int = result.get_amount(loot.id)
			if amount > 0:
				_add_line("%s : %d" % [loot.display_name, amount], loot.color)
		for member: CrewMember in result.recruits:
			_add_line("Recrue : " + member.describe(), Color(1.0, 0.82, 0.35))
		for item: ItemData in result.items:
			_add_line("Trouvé : " + item.display_name, Color(0.55, 0.85, 0.45))
		var left: int = 0
		for amount: int in result.left_behind.values():
			left += amount
		if left > 0:
			_add_line("Stock du train plein : %d ressource(s) laissée(s) sur le quai" % left, RISK_HIGH)
		var risk: float = result.infection_risk()
		_risk.text = "Risque d'infection : %d %%" % roundi(risk * 100.0)
		_risk.add_theme_color_override(&"font_color", _risk_color(risk))
		_risk.visible = true
		_storage.text = "Stock du train : %d/%d · Équipage : %d/%d couchettes" % [
			GameState.storage_total(), GameState.storage_capacity(), GameState.crew.size(), GameState.beds()]
		_storage.visible = true
		_button.text = "Continuer le voyage"
	else:
		_title.text = "Tu es tombé" if result.fell else "Le train est parti sans toi"
		_subtitle.text = ("Laissé pour mort dans la zone..." if result.fell else "Seul dans la zone infectée...") \
			+ " Tout ce qui s'est passé depuis la dernière gare est perdu."
		_add_line("Butin perdu", RISK_HIGH)
		if not result.recruits.is_empty():
			_add_line("%d recrue(s) perdue(s) avec toi" % result.recruits.size(), RISK_HIGH)
		_risk.visible = false
		_storage.text = "Reprise : %s" % Campaign.retry_place()
		_storage.visible = true
		_button.text = "Reprendre"

	_root.visible = true
	_button.grab_focus()


func _add_line(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", color)
	_loot_list.add_child(label)


static func _risk_color(risk: float) -> Color:
	if risk < 0.2:
		return RISK_LOW
	if risk < 0.5:
		return RISK_MEDIUM
	return RISK_HIGH
