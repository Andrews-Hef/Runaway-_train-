class_name Infection
extends RefCounted
## L'infection du joueur (0 à 1). Elle ne redescend jamais toute seule : ni dans le
## train, ni en gare. Seuls les médicaments la font baisser.
##
## Elle affaiblit par paliers, et à 100 % le joueur rejoint la ruche (fin de la
## sortie, reprise à la dernière gare refuge).

enum Stage { HEALTHY, FEVER, CONTAMINATED, CRITICAL, TURNED }

## Paliers : à partir de quelle infection, nom, PV en moins, vitesse.
const STAGES: Array[Dictionary] = [
	{"from": 0.0, "name": "Sain", "health": 0, "speed": 1.0},
	{"from": 0.30, "name": "Fièvre", "health": 2, "speed": 1.0},
	{"from": 0.60, "name": "Contaminé", "health": 4, "speed": 0.85},
	{"from": 0.90, "name": "Critique", "health": 6, "speed": 0.75},
]
const STAGE_COLORS: Array[Color] = [
	Color(0.55, 0.85, 0.45), Color(1.0, 0.8, 0.35), Color(1.0, 0.55, 0.3), Color(1.0, 0.35, 0.35), Color(0.75, 0.42, 1.0),
]


static func stage_for(value: float) -> Stage:
	if value >= 1.0:
		return Stage.TURNED
	var stage: int = 0
	for i: int in STAGES.size():
		if value >= STAGES[i]["from"]:
			stage = i
	return stage as Stage


static func stage_name(stage: Stage) -> String:
	return "Ruche" if stage == Stage.TURNED else STAGES[stage]["name"]


## PV max en moins à ce stade.
static func health_malus(value: float) -> int:
	var stage: Stage = stage_for(value)
	return STAGES[mini(stage, STAGES.size() - 1)]["health"]


## Multiplicateur de vitesse de marche à ce stade.
static func speed_factor(value: float) -> float:
	var stage: Stage = stage_for(value)
	return STAGES[mini(stage, STAGES.size() - 1)]["speed"]


## « 42 % · Fièvre (−2 PV) ».
static func describe(value: float) -> String:
	var stage: Stage = stage_for(value)
	var text: String = "%d %% · %s" % [roundi(value * 100.0), stage_name(stage)]
	if stage == Stage.TURNED:
		return text
	var effects: PackedStringArray = []
	if health_malus(value) > 0:
		effects.append("−%d PV" % health_malus(value))
	if speed_factor(value) < 1.0:
		effects.append("−%d %% vitesse" % roundi((1.0 - speed_factor(value)) * 100.0))
	if not effects.is_empty():
		text += " (%s)" % ", ".join(effects)
	return text


static func color(value: float) -> Color:
	return STAGE_COLORS[stage_for(value)]
