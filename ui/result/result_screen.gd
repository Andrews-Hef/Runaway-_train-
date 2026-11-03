extends CanvasLayer
## Écran de fin de sortie : bilan du butin, de l'exposition et du risque d'infection.
## Il reste actif quand le jeu est en pause.

signal restart_requested

const RISK_LOW: Color = Color(0.55, 0.85, 0.45)
const RISK_MEDIUM: Color = Color(1.0, 0.8, 0.35)
const RISK_HIGH: Color = Color(1.0, 0.45, 0.35)

@onready var _root: Control = $Root
@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _loot_list: VBoxContainer = %LootList
@onready var _exposure: Label = %Exposure
@onready var _risk: Label = %Risk
@onready var _restart: Button = %Restart


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	_restart.pressed.connect(func() -> void: restart_requested.emit())


func show_result(result: ExpeditionResult, loot_types: Array[LootData]) -> void:
	for child: Node in _loot_list.get_children():
		child.queue_free()

	var exposure_percent: int = roundi(result.exposure * 100.0)
	_exposure.text = "Exposition : %d %%" % exposure_percent

	if result.boarded:
		_title.text = "De retour à bord"
		_subtitle.text = "Le capitaine attend ton rapport."
		if result.total_items() == 0:
			_add_line("Tu reviens les mains vides.", Color(0.7, 0.7, 0.7))
		for loot: LootData in loot_types:
			var amount: int = result.get_amount(loot.id)
			if amount > 0:
				_add_line("%s : %d" % [loot.display_name, amount], loot.color)
		var risk: float = result.infection_risk()
		_risk.text = "Risque d'infection : %d %%" % roundi(risk * 100.0)
		_risk.add_theme_color_override(&"font_color", _risk_color(risk))
		_risk.visible = true
	else:
		_title.text = "Le train est parti sans toi"
		_subtitle.text = "Seul dans la zone infectée... La sortie est perdue."
		_add_line("Butin perdu", RISK_HIGH)
		_risk.visible = false

	_root.visible = true
	_restart.grab_focus()


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
