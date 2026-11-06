class_name PerkData
extends Resource
## Un talent, choisi à une promotion. Ses bonus s'ajoutent à ceux de l'équipement
## et durent toute la campagne.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String

@export_group("Bonus")
@export var max_health: int = 0
@export var armor: int = 0
@export var damage: int = 0
## Places de sac en plus.
@export var capacity: int = 0
## Récolte plus rapide sur tout (0.25 = +25 %).
@export var harvest_speed: float = 0.0
## Protection contre l'infection en plus (0.1 = +10 %, plafond général 80 %).
@export_range(0.0, 1.0) var protection: float = 0.0
## Force de chaque appui pour se dégager d'un rampant (1 = normal, 2 = deux fois moins d'appuis).
@export var mash_power: float = 0.0


## Bonus lisibles : « +2 PV », « Armure +1 »...
func describe_effects() -> String:
	var parts: PackedStringArray = []
	if max_health > 0:
		parts.append("+%d PV" % max_health)
	if armor > 0:
		parts.append("Armure +%d" % armor)
	if damage > 0:
		parts.append("Dégâts +%d" % damage)
	if capacity > 0:
		parts.append("Sac +%d %s" % [capacity, "case" if capacity == 1 else "cases"])
	if harvest_speed > 0.0:
		parts.append("Récolte +%d %%" % roundi(harvest_speed * 100.0))
	if protection > 0.0:
		parts.append("Protection +%d %%" % roundi(protection * 100.0))
	if mash_power > 0.0:
		parts.append("Se dégage %d %% plus vite" % roundi(mash_power * 100.0))
	return " · ".join(parts)
