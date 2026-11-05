class_name CaptainOrders
extends RefCounted
## Les ordres du capitaine : un par arrêt (sauf en gare), adapté à la zone.
## Pur : on lui passe la zone, le numéro d'arrêt et le hasard.

const ORDERS: Array[OrderData] = [
	preload("res://data/orders/collect_scrap.tres"),
	preload("res://data/orders/collect_wood.tres"),
	preload("res://data/orders/collect_herb.tres"),
	preload("res://data/orders/collect_infected_herb.tres"),
	preload("res://data/orders/fill_bag.tres"),
	preload("res://data/orders/eliminate_infected.tres"),
	preload("res://data/orders/eliminate_raiders.tres"),
	preload("res://data/orders/low_exposure.tres"),
]
## Premier ordre de la campagne : simple, pour apprendre.
const FIRST_ORDER: OrderData = preload("res://data/orders/collect_scrap.tres")
const FIRST_AMOUNT: int = 4
## D'où vient chaque ressource dans une zone (type d'objet du générateur).
const LOOT_SOURCES: Dictionary[StringName, StringName] = {
	&"scrap": &"wreck",
	&"wood": &"dead_tree",
	&"herb": &"herb",
	&"infected_herb": &"infected_herb",
}


## Un ordre donné pour un arrêt : le type d'ordre et le nombre demandé.
## Mots des ordres à mettre au singulier quand on n'en demande qu'un.
const SINGULARS: Dictionary[String, String] = {
	" pilleurs": " pilleur",
	" infectés": " infecté",
	" ferrailles": " ferraille",
	" plantes saines": " plante saine",
	" plantes infectées": " plante infectée",
	" ressources": " ressource",
}


class Order:
	var data: OrderData
	var amount: int

	func _init(order_data: OrderData, order_amount: int) -> void:
		data = order_data
		amount = order_amount

	func text() -> String:
		var result: String = data.title.replace("{n}", str(amount))
		if amount == 1:
			# Au singulier : « Élimine 1 pilleur », pas « 1 pilleurs ».
			for plural: String in SINGULARS:
				result = result.replace(plural, SINGULARS[plural])
		return result

	## Où on en est (pour le HUD) : quantité atteinte.
	func progress(result: ExpeditionResult) -> int:
		match data.kind:
			OrderData.Kind.COLLECT:
				return result.get_amount(data.target)
			OrderData.Kind.COLLECT_ANY:
				return result.total_items()
			OrderData.Kind.ELIMINATE:
				return result.kills_of_faction(data.target)
			_:
				return roundi(result.exposure_gained() * 100.0)

	func is_completed(result: ExpeditionResult) -> bool:
		if data.kind == OrderData.Kind.LOW_EXPOSURE:
			return result.exposure_gained() * 100.0 < amount
		return progress(result) >= amount

	## « 3/6 », ou « 12 % / < 25 % » pour l'exposition.
	func progress_text(result: ExpeditionResult) -> String:
		if data.kind == OrderData.Kind.LOW_EXPOSURE:
			return "%d %% / moins de %d %%" % [progress(result), amount]
		return "%d/%d" % [mini(progress(result), amount), amount]


## Tire l'ordre d'un arrêt. `capacity` : taille du sac (un ordre ne demande jamais plus).
static func pick(zone: ZoneProfile, stop_number: int, rng: RandomNumberGenerator, capacity: int) -> Order:
	if stop_number <= 1:
		return Order.new(FIRST_ORDER, FIRST_AMOUNT)
	var candidates: Array[Order] = []
	for data: OrderData in ORDERS:
		if stop_number < data.min_stop:
			continue
		var amount: int = rng.randi_range(data.amount.x, data.amount.y)
		var possible: int = max_possible(data, zone, stop_number, capacity)
		if possible <= 0:
			continue
		candidates.append(Order.new(data, mini(amount, possible)))
	if candidates.is_empty():
		return Order.new(FIRST_ORDER, FIRST_AMOUNT)
	return candidates[rng.randi_range(0, candidates.size() - 1)]


## Le plus qu'on puisse raisonnablement demander dans cette zone (0 = impossible).
static func max_possible(data: OrderData, zone: ZoneProfile, stop_number: int, capacity: int) -> int:
	match data.kind:
		OrderData.Kind.COLLECT:
			var source: StringName = LOOT_SOURCES.get(data.target, &"")
			# Il faut au moins deux objets de ce type, et assez de place dans le sac.
			return capacity if zone.count_range(source).x >= 2 else 0
		OrderData.Kind.COLLECT_ANY:
			return capacity
		OrderData.Kind.ELIMINATE:
			# Seulement les ennemis sûrs d'être là (minimum de la fourchette).
			var total: int = 0
			for enemy: EnemyData in EnemyCatalog.ALL:
				if String(enemy.faction_name()) == String(data.target) and stop_number >= enemy.min_stop:
					total += zone.count_range(enemy.id).x
			return total
		_:
			return 100


## Retrouve un ordre sauvegardé.
static func find(id: StringName) -> OrderData:
	for data: OrderData in ORDERS:
		if data.id == id:
			return data
	return null
