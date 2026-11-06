extends CanvasLayer
## Interface en jeu : temps d'arrêt restant, vie, infection, butin et consignes.
##
## Elle n'a aucune logique de jeu : elle affiche ce que les systèmes lui signalent.
## En haut à gauche, un seul encart qui grandit vers le bas (temps, heure, vie,
## infection, météo, état du train) ; en haut au centre, l'ordre du capitaine ; en
## bas au centre, les cases du sac façon Minecraft (BagHotbar), la consigne au-dessus.
## Le haut à droite reste libre pour les boutons tactiles « Sac » et « II ».
## Icônes 12 px (assets/ui/icons/), chiffres en gras plus gros, ombre sous les textes :
## lisible sur un petit écran. Style : plaques de fer du thème (HudPanel), ordre du
## capitaine sur un télégramme (PaperPanel), vie en segments, infection à paliers.

const NORMAL_TIME_COLOR: Color = Color(1.0, 1.0, 1.0)
const WHISTLE_TIME_COLOR: Color = Color(1.0, 0.45, 0.35)
const OUTLINE_COLOR: Color = Color(0.06, 0.05, 0.06)
const RECRUIT_ICON: Texture2D = preload("res://assets/ui/icons/recruit.png")
const PLAN_ICON: Texture2D = preload("res://assets/ui/icons/plan.png")
const SUN_ICON: Texture2D = preload("res://assets/ui/icons/sun.png")
const MOON_ICON: Texture2D = preload("res://assets/ui/icons/moon.png")
## Police des chiffres : Barlow Bold (OFL), plus grosse que le texte.
const NUMBERS_FONT: Font = preload("res://assets/fonts/barlow/Barlow-Bold.ttf")
const NUMBERS_SIZE: int = 11
## Encre du télégramme (ordre du capitaine) : en cours, puis rempli.
const INK: Color = Color(0.17, 0.12, 0.08)
const INK_DONE: Color = Color(0.16, 0.42, 0.14)
## État du train : bon, abîmé, critique.
const TRAIN_GOOD: Color = Color(0.8, 0.82, 0.86)
const TRAIN_DAMAGED: Color = Color(1.0, 0.7, 0.3)
const TRAIN_CRITICAL: Color = Color(1.0, 0.35, 0.3)

@onready var _timer_label: Label = %TimerLabel
@onready var _health_label: Label = %HealthLabel
@onready var _health_bar: SegmentBar = %HealthBar
@onready var _toast: Label = %Toast
@onready var _order: Control = %Order
@onready var _order_text: Label = %OrderText
@onready var _order_progress: Label = %OrderProgress
@onready var _stage_label: Label = %StageLabel
@onready var _mash: Control = %Mash
@onready var _mash_label: Label = %MashLabel
@onready var _mash_bar: ProgressBar = %MashBar
@onready var _exposure_label: Label = %ExposureLabel
@onready var _exposure_bar: StageBar = %ExposureBar
@onready var _zone_warning: Label = %ZoneWarning
@onready var _banner: Label = %Banner
@onready var _prompt: Label = %Prompt
@onready var _zone_title: Label = %ZoneTitle

var _loot_types: Array[LootData] = []
var _target: Interactable
var _interactor: Interactor
var _session: StopSession
## Météo (pluie infectée) : compte à rebours et abri, sous l'infection.
var _weather_label: Label
## Horloge : jour et heure, icône soleil ou lune (sous le temps d'arrêt).
var _clock_icon: TextureRect
var _clock_label: Label
## État du train (pendant une horde) : texte et jauge.
var _train_label: Label
var _train_bar: StageBar
## Cases du sac, en bas au centre.
var _hotbar: BagHotbar
## Recrues et plans trouvés pendant l'arrêt, à côté des cases.
var _extras: HBoxContainer
var _shown_plans: Array[StringName] = []
var _banner_tween: Tween
var _toast_tween: Tween
var _captain_order: CaptainOrders.Order
var _exposure_value: float = 0.0


func _ready() -> void:
	_outline_labels($Root)
	# Repères des paliers d'infection (Fièvre, Contaminé, Critique) sur la jauge.
	_exposure_bar.marks = Infection.stage_marks()
	var clock_row := HBoxContainer.new()
	clock_row.name = "ClockRow"
	clock_row.add_theme_constant_override(&"separation", 3)
	clock_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock_icon = MenuKit.icon(SUN_ICON, 12.0)
	clock_row.add_child(_clock_icon)
	_clock_label = Label.new()
	_clock_label.name = "ClockLabel"
	_clock_label.add_theme_color_override(&"font_color", Color(0.85, 0.85, 0.88))
	clock_row.add_child(_clock_label)
	var status_box: Node = _timer_label.get_parent().get_parent()
	status_box.add_child(clock_row)
	status_box.move_child(clock_row, _timer_label.get_parent().get_index() + 1)
	_weather_label = Label.new()
	_weather_label.name = "WeatherLabel"
	_weather_label.visible = false
	_zone_warning.get_parent().add_child(_weather_label)
	_zone_warning.get_parent().move_child(_weather_label, _zone_warning.get_index() + 1)
	_train_label = Label.new()
	_train_label.name = "TrainLabel"
	_train_label.visible = false
	_zone_warning.get_parent().add_child(_train_label)
	_zone_warning.get_parent().move_child(_train_label, _weather_label.get_index() + 1)
	_train_bar = StageBar.new()
	_train_bar.name = "TrainBar"
	_train_bar.visible = false
	_train_bar.custom_minimum_size = Vector2(74.0, 5.0)
	_train_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_train_bar.marks = [GameState.TRAIN_CRITICAL, GameState.TRAIN_DAMAGED] as Array[float]
	_zone_warning.get_parent().add_child(_train_bar)
	_zone_warning.get_parent().move_child(_train_bar, _train_label.get_index() + 1)
	_outline_labels(_weather_label.get_parent())


## Une ombre portée noire sous tous les textes : lisibles sur n'importe quel décor,
## sans boucher l'intérieur des chiffres (un contour remplirait le creux des 8 et des 0).
## Pas d'ombre sur le papier du télégramme : l'encre y est sombre.
static func _outline_labels(node: Node) -> void:
	for child: Node in node.get_children():
		if child is PanelContainer and (child as PanelContainer).theme_type_variation == &"PaperPanel":
			continue
		if child is Label and not (child as Label).has_theme_constant_override(&"outline_size"):
			var label := child as Label
			var big: bool = label.get_theme_font_size(&"font_size") >= 16
			label.add_theme_color_override(&"font_shadow_color", OUTLINE_COLOR)
			label.add_theme_constant_override(&"shadow_offset_x", 2 if big else 1)
			label.add_theme_constant_override(&"shadow_offset_y", 2 if big else 1)
		_outline_labels(child)


func bind(session: StopSession, player: Player, loot_types: Array[LootData]) -> void:
	_loot_types = loot_types
	_session = session
	_interactor = player.interactor
	_build_loot_list()
	session.time_changed.connect(_on_time_changed)
	session.whistle_blown.connect(_on_whistle_blown)
	session.loot_changed.connect(_on_loot_changed)
	session.recruited.connect(_on_recruited)
	session.ended.connect(func(_result: ExpeditionResult) -> void: visible = false)
	player.health.changed.connect(_on_health_changed)
	player.pinned_changed.connect(_on_pinned_changed)
	player.mash_changed.connect(func(progress: float, needed: int) -> void:
		_mash_bar.max_value = needed
		_mash_bar.value = progress)
	player.exposure.changed.connect(_on_exposure_changed)
	player.exposure.zone_changed.connect(_on_zone_changed)
	player.interactor.target_changed.connect(_on_target_changed)
	InputMode.changed.connect(func(_device: int) -> void: _refresh_prompt())
	_on_time_changed(session.remaining)
	_on_health_changed(player.health.health, player.health.max_health)
	_on_exposure_changed(player.exposure.value)
	_on_loot_changed(session.result)


## Affiche « Arrêt n°X : nom de la zone » quelques secondes au début de l'arrêt,
## avec en dessous le biome et sa règle (« Toundra gelée · Le froid… »).
func announce_zone(stop_number: int, zone_name: String, subtitle: String = "") -> void:
	_zone_title.text = "Arrêt n°%d : %s" % [stop_number, zone_name]
	_zone_title.visible = true
	_zone_title.modulate.a = 1.0
	var rule_label: Label = null
	if not subtitle.is_empty():
		rule_label = Label.new()
		rule_label.name = "ZoneRule"
		rule_label.text = subtitle
		rule_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rule_label.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.55))
		_zone_title.add_child(rule_label)
		rule_label.position = Vector2(0.0, _zone_title.size.y + 2.0)
		rule_label.size = Vector2(_zone_title.size.x, 12.0)
		_outline_labels(_zone_title)
	var tween := create_tween()
	tween.tween_interval(3.5 if rule_label else 2.5)
	tween.tween_property(_zone_title, "modulate:a", 0.0, 0.8)
	tween.tween_callback(_zone_title.hide)


## L'ordre du capitaine pour cet arrêt, suivi en direct (null : pas d'ordre).
func show_order(order: CaptainOrders.Order) -> void:
	_captain_order = order
	_order.visible = order != null
	_refresh_order()


func _refresh_order() -> void:
	if _captain_order == null or _session == null:
		return
	var done: bool
	var progress: String
	if _captain_order.data.kind == OrderData.Kind.LOW_EXPOSURE:
		var gained: float = maxf(_exposure_value - _session.result.exposure_start, 0.0)
		done = gained * 100.0 < _captain_order.amount
		progress = "+%d%%" % roundi(gained * 100.0)
	else:
		done = _captain_order.is_completed(_session.result)
		progress = _captain_order.progress_text(_session.result)
	_order_text.text = _captain_order.text()
	_order_progress.text = progress
	var color: Color = INK_DONE if done else INK
	_order_text.add_theme_color_override(&"font_color", color)
	_order_progress.add_theme_color_override(&"font_color", color)


## Jour et heure (« Jour 2 · 21:40 »), lune la nuit.
func set_clock(text: String, night: bool) -> void:
	_clock_label.text = text
	_clock_icon.texture = MOON_ICON if night else SUN_ICON
	_clock_label.add_theme_color_override(&"font_color", Color(0.7, 0.76, 1.0) if night else Color(0.85, 0.85, 0.88))


## État du train pendant une horde : « Train 84 % » et sa jauge (repères abîmé, critique).
func set_train_condition(value: float) -> void:
	_train_label.visible = true
	_train_bar.visible = true
	_train_label.text = "Train %d %%" % roundi(value * 100.0)
	var color: Color = TRAIN_GOOD if value >= GameState.TRAIN_DAMAGED else (TRAIN_DAMAGED if value >= GameState.TRAIN_CRITICAL else TRAIN_CRITICAL)
	_train_label.add_theme_color_override(&"font_color", color)
	_train_bar.fill_color = color
	_train_bar.value = value


## Ligne météo (pluie infectée) : vide = cachée. `alarm` : en violet vif (à découvert).
func set_weather(text: String, alarm: bool) -> void:
	_weather_label.visible = not text.is_empty()
	_weather_label.text = text
	_weather_label.add_theme_color_override(&"font_color", Color(0.85, 0.55, 1.0) if alarm else Color(0.8, 0.8, 0.85))


## Message court au-dessus du jeu (vol, butin récupéré...). `bad` : en rouge.
func toast(text: String, bad: bool = false) -> void:
	_toast.text = text
	_toast.add_theme_color_override(&"font_color", Color(1.0, 0.45, 0.35) if bad else Color(0.55, 0.85, 0.45))
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(_toast.hide)


static func format_time(seconds: float) -> String:
	var total: int = ceili(seconds)
	return "%d:%02d" % [total / 60, total % 60]


## Le sac en bas au centre : ses cases, puis les recrues et les plans de l'arrêt.
func _build_loot_list() -> void:
	if _hotbar == null:
		var bottom := HBoxContainer.new()
		bottom.name = "Bottom"
		bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bottom.alignment = BoxContainer.ALIGNMENT_CENTER
		bottom.add_theme_constant_override(&"separation", 6)
		bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		bottom.offset_left = -200.0
		bottom.offset_right = 200.0
		bottom.offset_top = -26.0
		bottom.offset_bottom = -4.0
		bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
		$Root.add_child(bottom)
		_hotbar = BagHotbar.new()
		bottom.add_child(_hotbar)
		_extras = HBoxContainer.new()
		_extras.name = "Extras"
		_extras.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_extras.add_theme_constant_override(&"separation", 4)
		bottom.add_child(_extras)
	_hotbar.set_loot_types(_loot_types)
	_outline_labels(_hotbar)


static func _icon_row(icon: Texture2D) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var picture := TextureRect.new()
	picture.texture = icon
	picture.custom_minimum_size = Vector2(12.0, 12.0)
	picture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(picture)
	var label := Label.new()
	label.add_theme_font_override(&"font", NUMBERS_FONT)
	label.add_theme_font_size_override(&"font_size", NUMBERS_SIZE)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	return row


func _on_time_changed(remaining: float) -> void:
	_timer_label.text = format_time(remaining)


func _on_whistle_blown() -> void:
	_timer_label.add_theme_color_override(&"font_color", WHISTLE_TIME_COLOR)
	_banner.visible = true
	_banner_tween = create_tween().set_loops()
	_banner_tween.tween_property(_banner, "modulate:a", 0.3, 0.4)
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.4)


func _on_loot_changed(result: ExpeditionResult) -> void:
	_hotbar.show_bag(result.loot, _session.capacity if _session else -1)
	# Plans trouvés pendant la sortie.
	for plan_id: StringName in result.plans:
		if plan_id in _shown_plans:
			continue
		_shown_plans.append(plan_id)
		var row := _icon_row(PLAN_ICON)
		var label := row.get_child(1) as Label
		label.text = BlueprintCatalog.get_plan(plan_id).display_name
		label.remove_theme_font_override(&"font")
		label.add_theme_color_override(&"font_color", Color(0.6, 0.8, 1.0))
		_extras.add_child(row)
		_outline_labels(row)
	_refresh_order()
	_refresh_prompt()


func _on_recruited(member: CrewMember) -> void:
	var row := _icon_row(RECRUIT_ICON)
	var label := row.get_child(1) as Label
	label.text = member.display_name
	label.remove_theme_font_override(&"font")
	label.add_theme_color_override(&"font_color", Color(1.0, 0.82, 0.35))
	_extras.add_child(row)
	_outline_labels(row)


func _on_health_changed(health: int, max_health: int) -> void:
	_health_bar.max_value = max_health
	_health_bar.value = health
	_health_label.text = "%d/%d" % [health, max_health]
	_health_label.add_theme_color_override(&"font_color", Color(1.0, 0.45, 0.35) if health * 3 <= max_health else Color.WHITE)


## Plaqué au sol : « Martèle Coup pour te dégager ! » et la jauge.
func _on_pinned_changed(pinned: bool) -> void:
	_mash.visible = pinned
	_mash_label.text = "Martèle %s pour te dégager !" % InputMode.label_for(&"attack")
	if pinned:
		_prompt.visible = false
	else:
		_refresh_prompt()


func _on_exposure_changed(value: float) -> void:
	_exposure_value = value
	_refresh_order()
	_exposure_bar.value = value
	_exposure_label.text = "%d%%" % roundi(value * 100.0)
	_stage_label.text = Infection.stage_name(Infection.stage_for(value))
	_exposure_label.add_theme_color_override(&"font_color", Infection.color(value))
	_stage_label.add_theme_color_override(&"font_color", Infection.color(value))


func _on_zone_changed(inside: bool) -> void:
	_zone_warning.visible = inside


func _on_target_changed(target: Interactable) -> void:
	_target = target
	_refresh_prompt()


func _refresh_prompt() -> void:
	_prompt.visible = is_instance_valid(_target)
	if not _prompt.visible:
		return
	var blocked: String = _interactor.block_reason() if _interactor else ""
	if blocked.is_empty():
		_prompt.text = "Maintenir %s : %s" % [InputMode.label_for(&"interact"), _target.prompt]
		_prompt.remove_theme_color_override(&"font_color")
	else:
		_prompt.text = blocked
		_prompt.add_theme_color_override(&"font_color", Color(1.0, 0.45, 0.35))
