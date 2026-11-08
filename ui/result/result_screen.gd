extends CanvasLayer
## Écran de fin de sortie : bilan du butin, de l'exposition et du risque d'infection.
## Il reste actif quand le jeu est en pause.
##
## Peu de texte : le butin en cases, les chiffres en pastilles (infection, stock,
## couchettes), le grade avec sa barre. Les explications sont en infobulle.

## Sortie réussie : on continue vers le prochain arrêt.
signal continue_requested
## Train raté : on reprend à la dernière gare refuge.
signal retry_requested

const RISK_LOW: Color = Color(0.55, 0.85, 0.45)
const RISK_MEDIUM: Color = Color(1.0, 0.8, 0.35)
const RISK_HIGH: Color = Color(1.0, 0.45, 0.35)

const SPORE: Texture2D = preload("res://assets/ui/icons/infection.png")
const CRATE: Texture2D = preload("res://assets/ui/icons/crate.png")
const BED: Texture2D = preload("res://assets/ui/icons/bed.png")
const HAMMER: Texture2D = preload("res://assets/ui/icons/hammer.png")
const STAR: Texture2D = preload("res://assets/ui/icons/order.png")
const PLAN: Texture2D = preload("res://assets/ui/icons/plan.png")
const WEAPON: Texture2D = preload("res://assets/ui/icons/items/weapon_pipe.png")

@onready var _root: Control = $Root
@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _loot_list: VBoxContainer = %LootList
@onready var _storage: Label = %Storage
@onready var _button: Button = %Restart
@onready var _career: VBoxContainer = %Career

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
	MenuKit.clear(_loot_list)
	_boarded = result.boarded
	if result.boarded:
		_title.text = "De retour à bord"
		_subtitle.text = "Le capitaine attend ton rapport."
		var haul: HFlowContainer = _haul(result, loot_types)
		if haul.get_child_count() == 0:
			_add_line("Tu reviens les mains vides.", MenuKit.MUTED)
		else:
			_loot_list.add_child(haul)
		if result.companion:
			_loot_list.add_child(_companion_row(result))
		_loot_list.add_child(_stats(result))
		_storage.visible = false
		_button.text = "Continuer le voyage"
		_fill_career(result)
	else:
		_clear_career()
		if result.turned:
			_title.text = "Tu as rejoint la ruche"
			_subtitle.text = "Les spores ont gagné..."
		elif result.fell:
			_title.text = "Tu es tombé"
			_subtitle.text = "Laissé pour mort dans la zone..."
		else:
			_title.text = "Le train est parti sans toi"
			_subtitle.text = "Seul dans la zone infectée..."
		_subtitle.text += " Tout ce qui s'est passé depuis la dernière gare est perdu."
		_add_line("Butin perdu", RISK_HIGH)
		if not result.recruits.is_empty():
			_add_line("%d recrue(s) perdue(s) avec toi" % result.recruits.size(), RISK_HIGH)
		_storage.text = "Reprise : %s" % Campaign.retry_place()
		_storage.visible = true
		_button.text = "Reprendre"

	_root.visible = true
	if not _button.disabled:
		_button.grab_focus()


## Ce que tu rapportes, en cases : ressources, recrues, équipements, plans.
func _haul(result: ExpeditionResult, loot_types: Array[LootData]) -> HFlowContainer:
	var haul := MenuKit.grid()
	for loot: LootData in loot_types:
		var amount: int = result.get_amount(loot.id)
		if amount > 0:
			haul.add_child(SlotCell.create(loot.icon, str(amount), "%s ×%d" % [loot.display_name, amount], false))
	for member: CrewMember in result.recruits:
		haul.add_child(SlotCell.create(CrewLooks.portrait(member.look), "", "Recrue : %s (%s)" % [member.full_name(), member.role_label], false))
	for item: ItemData in result.items:
		haul.add_child(SlotCell.create(item.icon, "", "Trouvé : %s (%s)" % [item.display_name, item.describe_effects()], false))
	for plan_id: StringName in result.plans:
		haul.add_child(SlotCell.create(BlueprintCatalog.icon(plan_id), "",
			"Plan trouvé : %s (à étudier à la table des plans)" % BlueprintCatalog.get_plan(plan_id).display_name, false).set_corner(PLAN))
	return haul


## L'équipier de sortie : son portrait, ce qu'il rapporte en cases, et comment il revient.
func _companion_row(result: ExpeditionResult) -> HBoxContainer:
	var member: CrewMember = result.companion
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	row.add_child(SlotCell.create(CrewLooks.portrait(member.look), "", member.full_name(), false))
	if result.companion_died:
		var lost := MenuKit.label(" ".join(result.companion_lines), RISK_HIGH)
		lost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lost)
		return row
	if result.companion_loot.is_empty():
		row.add_child(MenuKit.label("%s revient les mains vides." % member.display_name, MenuKit.MUTED))
	else:
		row.add_child(MenuKit.label("%s rapporte" % member.display_name))
		row.add_child(MenuKit.cost_row(result.companion_loot))
	var note: String = " ".join(result.companion_lines.slice(1)) if result.companion_lines.size() > 1 else ""
	var first: String = result.companion_lines[0] if not result.companion_lines.is_empty() else ""
	# Blessé, ou a décroché : ça se dit ; sinon pas de phrase en plus.
	if first.contains("blessé") or first.contains("décroché") or not note.is_empty():
		var extra := MenuKit.label((first + " " + note).strip_edges(), RISK_MEDIUM)
		extra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		extra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(extra)
	return row


## Les chiffres du retour : infection (et ce que la sortie a coûté), stock, couchettes.
func _stats(result: ExpeditionResult) -> HBoxContainer:
	var stats := MenuKit.header()
	# L'infection ne redescend pas toute seule : seuls les médicaments la soignent.
	stats.add_child(MenuKit.chip(SPORE, "%d %% · %s" % [roundi(result.exposure * 100.0), Infection.stage_name(Infection.stage_for(result.exposure))],
		Infection.color(result.exposure), Infection.describe(result.exposure)))
	var gained: float = result.exposure_gained()
	stats.add_child(MenuKit.chip(null, "+%d %% pendant la sortie" % roundi(gained * 100.0), _risk_color(gained * 3.0),
		"Seuls les médicaments font baisser l'infection."))
	var left: int = 0
	for amount: int in result.left_behind.values():
		left += amount
	stats.add_child(MenuKit.chip(CRATE, "%d/%d" % [GameState.storage_total(), GameState.storage_capacity()],
		RISK_HIGH if left > 0 else Color.WHITE,
		"Stock du train" + (" plein : %d ressource(s) laissée(s) sur le quai" % left if left > 0 else "")))
	if left > 0:
		stats.add_child(MenuKit.chip(null, "−%d laissée(s)" % left, RISK_HIGH, "Stock plein : laissées sur le quai"))
	stats.add_child(MenuKit.chip(BED, "%d/%d" % [GameState.crew.size(), GameState.beds()], Color.WHITE, "Couchettes"))
	return stats


# --- Rapport au capitaine -----------------------------------------------------------

## L'ordre du capitaine, le mérite gagné, et le choix d'un talent en cas de promotion.
func _fill_career(result: ExpeditionResult) -> void:
	_clear_career()
	var order: CaptainOrders.Order = GameState.current_order
	if order:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 4)
		row.add_child(MenuKit.icon(STAR, 12.0))
		var text := MenuKit.label(order.text(), Color(0.9, 0.9, 0.92))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		row.add_child(MenuKit.chip(null, "réussi · +%d" % order.data.merit, RISK_LOW, "Ordre du capitaine rempli : mérite gagné")
			if result.order_completed else MenuKit.chip(null, "raté", RISK_HIGH, "Ordre du capitaine pas rempli"))
		_career.add_child(row)
	var facts := MenuKit.header()
	var kills: int = 0
	for amount: int in result.kills.values():
		kills += amount
	if kills > 0:
		facts.add_child(MenuKit.chip(WEAPON, "%d · +%d" % [kills, result.kill_merit()], Color(0.85, 0.85, 0.88), "Ennemis éliminés : mérite gagné"))
	if result.horde_repelled:
		facts.add_child(MenuKit.chip(STAR, "Horde repoussée · +%d" % GameState.HORDE_MERIT, RISK_LOW))
	if GameState.train_condition < 1.0:
		facts.add_child(MenuKit.chip(HAMMER, "%d %%" % roundi(GameState.train_condition * 100.0),
			RISK_HIGH if GameState.condition() != GameState.Condition.GOOD else Color(0.85, 0.85, 0.88),
			"Train : %s · à réparer à la cabine" % GameState.describe_condition()))
	if facts.get_child_count() > 0:
		_career.add_child(facts)
	for thanks: String in result.crew_thanks:
		_career_line(thanks, RISK_LOW)
	_fill_promotion()


func _fill_promotion() -> void:
	for child: Node in _career.get_children():
		if child.has_meta(&"promotion"):
			_career.remove_child(child)
			child.queue_free()
	# Le grade : son nom, la barre vers le suivant, le mérite.
	var next: GradeData = Career.next_grade(GameState.grade_index())
	var standing := HBoxContainer.new()
	standing.set_meta(&"promotion", true)
	standing.add_theme_constant_override(&"separation", 6)
	standing.add_child(MenuKit.label(GameState.grade().display_name, MenuKit.GOLD))
	var bar := StageBar.new()
	bar.custom_minimum_size = Vector2(100.0, 5.0)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.fill_color = MenuKit.GOOD
	bar.value = Career.progress(GameState.merit)
	standing.add_child(bar)
	standing.add_child(MenuKit.chip(null, "%d/%d" % [GameState.merit, next.merit_needed] if next else str(GameState.merit), Color.WHITE, "Mérite"))
	if next:
		standing.add_child(MenuKit.label("avant " + next.display_name, MenuKit.MUTED))
	_career.add_child(standing)
	_button.disabled = not GameState.pending_promotions.is_empty()
	if GameState.pending_promotions.is_empty():
		return
	# Promotion : on choisit un talent avant de repartir.
	var promotion: GradeData = GameState.pending_promotions[0]
	_career_line("Promu %s ! Choisis un talent :" % promotion.display_name, RISK_LOW).set_meta(&"promotion", true)
	var row := HBoxContainer.new()
	row.set_meta(&"promotion", true)
	row.add_theme_constant_override(&"separation", 4)
	var first: Button = null
	for perk: PerkData in promotion.perks:
		var button := Button.new()
		button.text = "%s (%s)" % [perk.display_name, perk.describe_effects()]
		button.tooltip_text = perk.description
		button.custom_minimum_size = Vector2(0.0, 20.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			GameState.choose_perk(perk)
			_fill_promotion.call_deferred()
			MenuKit.focus_later(_button))
		row.add_child(button)
		if first == null:
			first = button
	_career.add_child(row)
	MenuKit.focus_later(first)


func _career_line(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_career.add_child(label)
	return label


func _clear_career() -> void:
	_button.disabled = false
	for child: Node in _career.get_children():
		_career.remove_child(child)
		child.queue_free()


func _add_line(text: String, color: Color) -> void:
	_loot_list.add_child(MenuKit.label(text, color))


static func _risk_color(risk: float) -> Color:
	if risk < 0.2:
		return RISK_LOW
	if risk < 0.5:
		return RISK_MEDIUM
	return RISK_HIGH
