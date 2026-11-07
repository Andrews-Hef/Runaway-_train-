class_name CrewLooks
extends RefCounted
## Les 20 apparences des équipiers (sprites td2d dans assets/sprites/crew/, portraits
## 12 px dans assets/ui/portraits/). Chargées à la demande : on ne garde en mémoire que
## celles de l'équipage.

const COUNT: int = 20
## Pivot des sprites (pieds) : dans Godot, centered = false et offset = -PIVOT.
const PIVOT: Vector2 = Vector2(18.0, 35.0)
const FRAMES_PATH: String = "res://assets/sprites/crew/crew_%02d/crew-%02d.tres"
const PORTRAIT_PATH: String = "res://assets/ui/portraits/crew_%02d.png"


static func valid(look: int) -> int:
	return clampi(look, 1, COUNT)


static func frames(look: int) -> SpriteFrames:
	var index: int = valid(look)
	return load(FRAMES_PATH % [index, index]) as SpriteFrames


static func portrait(look: int) -> Texture2D:
	return load(PORTRAIT_PATH % valid(look)) as Texture2D


## Une apparence libre (pas déjà portée dans l'équipage), sinon n'importe laquelle.
static func pick(rng: RandomNumberGenerator, taken: Array[int]) -> int:
	var free: Array[int] = []
	for look: int in range(1, COUNT + 1):
		if not look in taken:
			free.append(look)
	if free.is_empty():
		return rng.randi_range(1, COUNT)
	return free[rng.randi_range(0, free.size() - 1)]


## Apparence d'un équipier d'une vieille sauvegarde : tirée de son nom (toujours la même).
static func from_name(member_name: String) -> int:
	return absi(hash(member_name)) % COUNT + 1
