class_name Barter
extends RefCounted
## Le troc chez le marchand d'une gare refuge : pas de monnaie, chaque chose a une valeur.
##
## - Chaque ressource vaut LootData.value (10 = une ferraille). Le marchand vend un peu
##   plus cher qu'il ne reprend (SELL_MARKUP / BUY_RATE) ; une gare où une ressource
##   abonde la paie moins cher, une gare où elle manque la paie plus cher.
## - Son étal change à chaque passage (graine de la partie + numéro de l'arrêt) :
##   ressources en quantités, quelques pièces d'équipement que tu n'as pas encore
##   (meilleures plus loin sur la ligne) et parfois un plan.
## - Un échange : ce que tu donnes (pris dans le stock du train) contre ce que tu prends.
##   Il passe si ce que tu donnes vaut au moins ce que tu prends ; le marchand garde le
##   surplus. Ce que tu lui donnes rejoint son étal (tu peux le racheter, plus cher).
##
## Pur : on lui passe le stock, la place libre, l'étal ; il rend un problème ou applique.

enum Problem { NONE, NOTHING_TAKEN, NOT_ENOUGH, MISSING, MERCHANT_SHORT, NO_SPACE, OWNED }

const PROBLEM_TEXTS: Dictionary[Problem, String] = {
	Problem.NOTHING_TAKEN: "Choisis ce que tu veux sur l'étal.",
	Problem.NOT_ENOUGH: "Pas assez : donne-lui plus de ressources.",
	Problem.MISSING: "Tu n'as pas tout ça dans le stock.",
	Problem.MERCHANT_SHORT: "Le marchand n'en a pas autant.",
	Problem.NO_SPACE: "Pas assez de place dans le stock du train.",
	Problem.OWNED: "Tu as déjà cet équipement.",
}
## Le marchand vend 25 % plus cher qu'une chose ne vaut…
const SELL_MARKUP: float = 1.25
## …et reprend tes ressources 20 % moins cher.
const BUY_RATE: float = 0.8
## Ressource qui abonde dans cette gare (moins chère) ou qui y manque (plus chère).
## Écart choisi pour qu'acheter là où ça abonde et revendre là où ça manque ne rapporte
## presque rien (≈ +10 %) : le stock du train a mieux à faire que du négoce.
const ABUNDANT_FACTOR: float = 0.75
const SCARCE_FACTOR: float = 1.3
## Un équipement coûte ce que vaut sa recette, fois ça (le travail de l'artisan).
const ITEM_FACTOR: float = 1.5
## Équipements sur l'étal à chaque passage.
const ITEMS_FOR_SALE: int = 3
## Un plan coûte ça, plus la moitié de ce que vaut son étude.
const PLAN_BASE: int = 60
## Chance qu'un plan soit sur l'étal.
const PLAN_CHANCE: float = 0.6


## Un étal : ressources (id -> quantité) et équipements à vendre.
class Stall:
	var goods: Dictionary[StringName, int] = {}
	var items: Array[ItemData] = []
	var plans: Array[StringName] = []


## Un échange en préparation : ce que tu donnes, ce que tu prends.
class Deal:
	var give: Dictionary[StringName, int] = {}
	var take: Dictionary[StringName, int] = {}
	var items: Array[ItemData] = []
	var plans: Array[StringName] = []

	func is_empty() -> bool:
		return give.is_empty() and takes_nothing()

	func takes_nothing() -> bool:
		return take.is_empty() and items.is_empty() and plans.is_empty()

	func clear() -> void:
		give.clear()
		take.clear()
		items.clear()
		plans.clear()

	## Ajoute (ou retire, `amount` < 0) dans un côté de l'échange.
	static func change(side: Dictionary[StringName, int], id: StringName, amount: int) -> void:
		var total: int = side.get(id, 0) + amount
		if total > 0:
			side[id] = total
		else:
			side.erase(id)


# --- Prix ------------------------------------------------------------------------------

static func factor(refuge: RefugeData, id: StringName) -> float:
	if refuge == null:
		return 1.0
	if id in refuge.abundant:
		return ABUNDANT_FACTOR
	if id in refuge.scarce:
		return SCARCE_FACTOR
	return 1.0


## Ce que coûte une unité achetée au marchand.
static func sell_price(refuge: RefugeData, loot: LootData) -> int:
	return maxi(roundi(loot.value * factor(refuge, loot.id) * SELL_MARKUP), 1)


## Ce que le marchand t'accorde pour une unité de ton stock.
static func buy_price(refuge: RefugeData, loot: LootData) -> int:
	return maxi(roundi(loot.value * factor(refuge, loot.id) * BUY_RATE), 1)


## Prix d'un équipement : la valeur de sa recette, plus le travail ; arrondi à 5.
static func item_price(item: ItemData) -> int:
	var total: float = 0.0
	for id: StringName in item.recipe:
		var loot := MenuKit.loot(id)
		total += (loot.value if loot else 10) * item.recipe[id]
	if total <= 0.0:
		total = 40.0 * item.tier
	return maxi(roundi(total * ITEM_FACTOR / 5.0) * 5, 5)


## Prix d'un plan : une base, plus la moitié de ce que coûte son étude ; arrondi à 5.
static func plan_price(plan: BlueprintData) -> int:
	var total: float = PLAN_BASE
	if plan:
		for id: StringName in plan.research_cost:
			var loot := MenuKit.loot(id)
			total += (loot.value if loot else 10) * plan.research_cost[id] * 0.5
	return roundi(total / 5.0) * 5


## Meilleur rang d'équipement vendu à cet arrêt : 2 à la première gare, 3 ensuite.
static func max_tier(stop: int) -> int:
	return clampi(1 + stop / 5, 1, 3)


static func given_value(refuge: RefugeData, deal: Deal) -> int:
	var total: int = 0
	for id: StringName in deal.give:
		var loot := MenuKit.loot(id)
		if loot:
			total += buy_price(refuge, loot) * deal.give[id]
	return total


static func taken_value(refuge: RefugeData, deal: Deal) -> int:
	var total: int = 0
	for id: StringName in deal.take:
		var loot := MenuKit.loot(id)
		if loot:
			total += sell_price(refuge, loot) * deal.take[id]
	for item: ItemData in deal.items:
		total += item_price(item)
	for plan_id: StringName in deal.plans:
		total += plan_price(BlueprintCatalog.get_plan(plan_id))
	return total


# --- L'étal ----------------------------------------------------------------------------

## L'étal du passage : même gare et même arrêt = même étal (on peut revenir au menu).
## `plans` : ceux qu'on peut encore trouver ; `tier` : rang maximal des équipements.
static func stall(refuge: RefugeData, rng_seed: int, owned: Array[ItemData], loot_types: Array[LootData],
		plans: Array[StringName] = [], tier: int = 3) -> Stall:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var result := Stall.new()
	for loot: LootData in loot_types:
		var amount: int = 0
		if loot.value <= 20:
			amount = rng.randi_range(5, 14)
		elif loot.value <= 60:
			amount = rng.randi_range(2, 6) if rng.randf() < 0.8 else 0
		elif loot.value <= 120:
			amount = rng.randi_range(1, 2) if rng.randf() < 0.55 else 0
		else:
			amount = 1 if rng.randf() < 0.2 else 0
		if refuge and loot.id in refuge.abundant:
			amount = maxi(amount, 1) * 2
		elif refuge and loot.id in refuge.scarce:
			amount = amount / 2 if rng.randf() < 0.5 else 0
		if amount > 0:
			result.goods[loot.id] = amount
	var candidates: Array[ItemData] = []
	for item: ItemData in ItemCatalog.ALL:
		if not item.starter and not item in owned and item.tier <= tier:
			candidates.append(item)
	for i: int in mini(ITEMS_FOR_SALE, candidates.size()):
		result.items.append(candidates.pop_at(rng.randi_range(0, candidates.size() - 1)))
	if not plans.is_empty() and rng.randf() < PLAN_CHANCE:
		result.plans.append(plans[rng.randi_range(0, plans.size() - 1)])
	return result


# --- L'échange -------------------------------------------------------------------------

static func problem(refuge: RefugeData, deal: Deal, stall_now: Stall, storage: Dictionary[StringName, int],
		free_space: int, owned: Array[ItemData], known_plans: Array[StringName] = []) -> Problem:
	if deal.takes_nothing():
		return Problem.NOTHING_TAKEN
	for id: StringName in deal.give:
		if storage.get(id, 0) < deal.give[id]:
			return Problem.MISSING
	for id: StringName in deal.take:
		if stall_now.goods.get(id, 0) < deal.take[id]:
			return Problem.MERCHANT_SHORT
	for item: ItemData in deal.items:
		if item in owned:
			return Problem.OWNED
		if not item in stall_now.items:
			return Problem.MERCHANT_SHORT
	for plan_id: StringName in deal.plans:
		if plan_id in known_plans:
			return Problem.OWNED
		if not plan_id in stall_now.plans:
			return Problem.MERCHANT_SHORT
	if given_value(refuge, deal) < taken_value(refuge, deal):
		return Problem.NOT_ENOUGH
	if _count(deal.take) - _count(deal.give) > free_space:
		return Problem.NO_SPACE
	return Problem.NONE


## Fait l'échange : le stock, l'étal et tes équipements changent. Renvoie le surplus que
## le marchand garde (ce que tu as donné en trop). Les plans achetés sont retirés de
## l'étal : c'est à l'appelant de les ajouter à ceux du joueur (GameState.add_plan).
static func apply(refuge: RefugeData, deal: Deal, stall_now: Stall, storage: Dictionary[StringName, int],
		owned: Array[ItemData]) -> int:
	var surplus: int = given_value(refuge, deal) - taken_value(refuge, deal)
	for id: StringName in deal.give:
		Deal.change(storage, id, -deal.give[id])
		Deal.change(stall_now.goods, id, deal.give[id])
	for id: StringName in deal.take:
		Deal.change(stall_now.goods, id, -deal.take[id])
		Deal.change(storage, id, deal.take[id])
	for item: ItemData in deal.items:
		stall_now.items.erase(item)
		if not item in owned:
			owned.append(item)
	for plan_id: StringName in deal.plans:
		stall_now.plans.erase(plan_id)
	deal.clear()
	return surplus


## Complète ce que tu donnes avec ton surplus (ce que tu as le plus, hors remèdes et
## hors ce que tu prends) jusqu'à couvrir ce que tu prends. Renvoie false s'il n'y a
## pas assez dans le stock (l'échange reste alors tel quel).
static func balance(refuge: RefugeData, deal: Deal, storage: Dictionary[StringName, int]) -> bool:
	var added: Dictionary[StringName, int] = {}
	while given_value(refuge, deal) < taken_value(refuge, deal):
		var best: StringName = &""
		var best_left: int = 0
		for id: StringName in storage:
			var loot := MenuKit.loot(id)
			if loot == null or loot.is_medicine() or deal.take.has(id):
				continue
			var left: int = storage[id] - deal.give.get(id, 0)
			if left > best_left:
				best = id
				best_left = left
		if best == &"":
			for id: StringName in added:
				Deal.change(deal.give, id, -added[id])
			return false
		Deal.change(deal.give, best, 1)
		added[best] = added.get(best, 0) + 1
	return true


static func _count(side: Dictionary[StringName, int]) -> int:
	var total: int = 0
	for amount: int in side.values():
		total += amount
	return total
