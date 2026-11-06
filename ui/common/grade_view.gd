class_name GradeView
extends RefCounted
## Le grade du joueur : barre de progression vers le grade suivant, échelle des grades
## (ce que chacun débloque), ordre du capitaine, talents (et choix du talent après une
## promotion). Affiché dans l'onglet Grade de l'inventaire (I, ou le bouton Sac).

const PROGRESS_COLOR: Color = Color(0.47, 0.75, 0.29)


static func fill(list: VBoxContainer) -> void:
	MenuKit.clear(list)
	var grade: GradeData = GameState.grade()
	var next: GradeData = Career.next_grade(GameState.grade_index())
	list.add_child(MenuKit.label("%s — %s" % [grade.display_name, grade.description], MenuKit.GOLD))
	# Barre de progression vers le grade suivant.
	var bar := StageBar.new()
	bar.name = "GradeProgress"
	bar.custom_minimum_size = Vector2(240.0, 6.0)
	bar.fill_color = PROGRESS_COLOR
	bar.value = Career.progress(GameState.merit)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(bar)
	if next:
		list.add_child(MenuKit.label("Mérite : %d / %d avant %s (%s)" % [GameState.merit, next.merit_needed, next.display_name,
			Career.UNLOCKS[GameState.grade_index() + 1].to_lower()], PROGRESS_COLOR))
	else:
		list.add_child(MenuKit.label("Mérite : %d · grade le plus haut" % GameState.merit, PROGRESS_COLOR))
	# L'échelle des grades : atteints, suivant, à venir.
	for i: int in Career.GRADES.size():
		var step: GradeData = Career.GRADES[i]
		var reached: bool = i <= GameState.grade_index()
		var color: Color = MenuKit.GOOD if reached else (MenuKit.GOLD if i == GameState.grade_index() + 1 else MenuKit.MUTED)
		var line := MenuKit.label("%s (%d) : %s" % [step.display_name, step.merit_needed, Career.UNLOCKS[i]], color)
		line.add_theme_font_size_override(&"font_size", 7)
		list.add_child(line)
	var order: CaptainOrders.Order = GameState.current_order
	list.add_child(MenuKit.label("Ordre pour l'arrêt n°%d : %s (+%d mérite)" % [GameState.stop_number, order.text(), order.data.merit] if order \
		else "Pas d'ordre : le prochain arrêt est une gare refuge.", Color.WHITE))
	# Promotion en attente : on choisit son talent ici.
	if not GameState.pending_promotions.is_empty():
		var promotion: GradeData = GameState.pending_promotions[0]
		list.add_child(MenuKit.label("Promu %s : choisis un talent." % promotion.display_name, MenuKit.GOOD))
		for perk: PerkData in promotion.perks:
			list.add_child(MenuKit.row(perk.display_name, "%s — %s" % [perk.describe_effects(), perk.description], MenuKit.GOOD,
				"Choisir", false, func() -> void: GameState.choose_perk(perk)))
	if GameState.perks.is_empty():
		list.add_child(MenuKit.label("Pas encore de talent : remplis les ordres du capitaine et élimine des ennemis pour monter en grade.", MenuKit.MUTED))
	for perk: PerkData in GameState.perks:
		list.add_child(MenuKit.label("%s : %s" % [perk.display_name, perk.describe_effects()], Color.WHITE))
	var requests: Array[CrewMember] = []
	for member: CrewMember in GameState.crew:
		if member.has_request():
			requests.append(member)
	if not requests.is_empty():
		list.add_child(MenuKit.label("Demandes de l'équipage", MenuKit.GOLD))
		for member: CrewMember in requests:
			var line := MenuKit.label("%s : %s" % [member.display_name, CrewRequests.text(member)], Color(0.95, 0.88, 0.65))
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			list.add_child(line)
