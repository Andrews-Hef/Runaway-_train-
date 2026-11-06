class_name BagSlots
extends RefCounted
## Le sac en cases, façon Minecraft : chaque case contient une pile d'une seule
## ressource, STACK_SIZE au plus. Mélanger les ressources remplit vite les cases.
##
## Pur : on ne garde pas de position par case, les piles se rangent toujours dans le
## même ordre (piles pleines d'abord). Petit sac 4 cases, sac de randonnée 6, sac
## militaire 8 ; les talents Glaneur et Intendant en ajoutent.

const STACK_SIZE: int = 5


## Cases occupées par ce contenu.
static func used(loot: Dictionary[StringName, int]) -> int:
	var slots: int = 0
	for id: StringName in loot:
		slots += ceili(float(maxi(loot[id], 0)) / STACK_SIZE)
	return slots


## Combien de `id` peut encore entrer dans un sac de `slots` cases : la fin de sa pile
## entamée, plus les cases libres.
static func room_for(loot: Dictionary[StringName, int], id: StringName, slots: int) -> int:
	var amount: int = loot.get(id, 0)
	var partial: int = (STACK_SIZE - amount % STACK_SIZE) % STACK_SIZE
	return maxi(slots - used(loot), 0) * STACK_SIZE + partial


## Le plus d'objets d'une même ressource que tiennent `slots` cases.
static func max_items(slots: int) -> int:
	return maxi(slots, 0) * STACK_SIZE


## Les cases à afficher, dans l'ordre de `order` (ids) : [{id, amount}], une entrée par
## pile. Les ressources absentes de `order` viennent ensuite.
static func layout(loot: Dictionary[StringName, int], order: Array[StringName]) -> Array[Dictionary]:
	var ids: Array[StringName] = []
	for id: StringName in order:
		if loot.get(id, 0) > 0:
			ids.append(id)
	for id: StringName in loot:
		if loot[id] > 0 and not id in ids:
			ids.append(id)
	var stacks: Array[Dictionary] = []
	for id: StringName in ids:
		var left: int = loot[id]
		while left > 0:
			var pile: int = mini(left, STACK_SIZE)
			stacks.append({"id": id, "amount": pile})
			left -= pile
	return stacks
