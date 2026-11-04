extends CanvasLayer
## Interface en jeu : temps d'arrêt restant, vie, exposition, butin et consignes.
##
## Elle n'a aucune logique de jeu : elle affiche ce que les systèmes lui signalent.

const NORMAL_TIME_COLOR: Color = Color(1.0, 1.0, 1.0)
const WHISTLE_TIME_COLOR: Color = Color(1.0, 0.45, 0.35)

@onready var _timer_label: Label = %TimerLabel
@onready var _health_label: Label = %HealthLabel
@onready var _health_bar: ProgressBar = %HealthBar
@onready var _toast: Label = %Toast
@onready var _order: Label = %Order
@onready var _mash: Control = %Mash
@onready var _mash_label: Label = %MashLabel
@onready var _mash_bar: ProgressBar = %MashBar
@onready var _exposure_label: Label = %ExposureLabel
@onready var _exposure_bar: ProgressBar = %ExposureBar
@onready var _zone_warning: Label = %ZoneWarning
@onready var _loot_list: VBoxContainer = %LootList
@onready var _banner: Label = %Banner
@onready var _prompt: Label = %Prompt
@onready var _zone_title: Label = %ZoneTitle

var _loot_labels: Dictionary[StringName, Label] = {}
var _loot_types: Array[LootData] = []
var _target: Interactable
var _interactor: Interactor
var _session: StopSession
var _bag_label: Label
var _banner_tween: Tween
var _toast_tween: Tween
var _captain_order: CaptainOrders.Order
var _exposure_value: float = 0.0


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


## Affiche « Arrêt n°X : nom de la zone » quelques secondes au début de l'arrêt.
func announce_zone(stop_number: int, zone_name: String) -> void:
	_zone_title.text = "Arrêt n°%d : %s" % [stop_number, zone_name]
	_zone_title.visible = true
	_zone_title.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(2.5)
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
		progress = "+%d %%" % roundi(gained * 100.0)
	else:
		done = _captain_order.is_completed(_session.result)
		progress = _captain_order.progress_text(_session.result)
	_order.text = "Ordre : %s · %s%s" % [_captain_order.text(), progress, " (fait)" if done else ""]
	_order.add_theme_color_override(&"font_color", Color(0.55, 0.85, 0.45) if done else Color(1.0, 0.82, 0.35))


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


func _build_loot_list() -> void:
	for child: Node in _loot_list.get_children():
		child.queue_free()
	_loot_labels.clear()
	_bag_label = Label.new()
	_loot_list.add_child(_bag_label)
	for loot: LootData in _loot_types:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 3)
		var swatch := ColorRect.new()
		swatch.color = loot.color
		swatch.custom_minimum_size = Vector2(5.0, 5.0)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var label := Label.new()
		row.add_child(swatch)
		row.add_child(label)
		_loot_list.add_child(row)
		_loot_labels[loot.id] = label


func _on_time_changed(remaining: float) -> void:
	_timer_label.text = "Départ " + format_time(remaining)


func _on_whistle_blown() -> void:
	_timer_label.add_theme_color_override(&"font_color", WHISTLE_TIME_COLOR)
	_banner.visible = true
	_banner_tween = create_tween().set_loops()
	_banner_tween.tween_property(_banner, "modulate:a", 0.3, 0.4)
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.4)


func _on_loot_changed(result: ExpeditionResult) -> void:
	for loot: LootData in _loot_types:
		var amount: int = result.get_amount(loot.id)
		_loot_labels[loot.id].text = "%s %d" % [loot.display_name, amount]
		# Les matériaux rares n'apparaissent qu'une fois trouvés, pour garder le HUD lisible.
		_loot_labels[loot.id].get_parent().visible = amount > 0 or not loot.rare
	_refresh_order()
	if _session and _session.capacity >= 0:
		_bag_label.text = "Sac %d/%d" % [result.total_items(), _session.capacity]
		_bag_label.add_theme_color_override(&"font_color", Color(1.0, 0.45, 0.35) if _session.is_bag_full() else Color(0.85, 0.85, 0.88))
	_refresh_prompt()


func _on_recruited(member: CrewMember) -> void:
	var label := Label.new()
	label.text = "Recrue : " + member.display_name
	label.add_theme_color_override(&"font_color", Color(1.0, 0.82, 0.35))
	_loot_list.add_child(label)


func _on_health_changed(health: int, max_health: int) -> void:
	_health_bar.max_value = max_health
	_health_bar.value = health
	_health_label.text = "Vie %d/%d" % [health, max_health]
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
	_exposure_label.text = "Infection %d %% · %s" % [roundi(value * 100.0), Infection.stage_name(Infection.stage_for(value))]
	_exposure_label.add_theme_color_override(&"font_color", Infection.color(value))


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
