class_name CrewMember
extends Resource
## Un membre d'équipage : un nom, un rôle, et quatre jauges (0 à 100) qui vivent
## d'un trajet à l'autre (voir CrewLife) : vie, infection, fatigue, confiance.
##
## L'infection est cachée au joueur au début : une recrue peut porter la maladie
## sans que ça se voie. Elle se voit aux symptômes (CrewLife.SYMPTOMS) ou tout de
## suite si un soigneur travaille à bord.

@export var display_name: String
## Rôle : &"mechanic" (répare le train), &"medic" (soigne, repère les infectés),
## &"scout" (repère les hordes).
@export var role: StringName
## Rôle affiché au joueur : « mécanique », « soins », « repérage »...
@export var role_label: String
## Porte la maladie (au départ, caché).
@export var infected: bool = false

@export_group("Jauges")
@export_range(0, 100) var health: int = 100
@export_range(0, 100) var infection: int = 0
@export_range(0, 100) var fatigue: int = 0
@export_range(0, 100) var trust: int = 50

@export_group("Ordres du capitaine")
## Au repos pendant le prochain trajet : il ne travaille pas et récupère plus.
@export var resting: bool = false
## Isolé à l'infirmerie : il ne contamine personne et ne travaille pas.
@export var quarantined: bool = false
## Le joueur sait qu'il est infecté (symptômes, ou soigneur à bord).
@export var infection_known: bool = false

@export_group("Demande personnelle")
## Ce qu'il demande au joueur (voir CrewRequests) : &"" (rien), &"deliver" (donner du
## stock), &"eliminate" (éliminer des ennemis d'une faction), &"bring" (rapporter d'un arrêt).
@export var request_kind: StringName
## Ressource (id de LootData) ou faction (&"infected", &"raiders").
@export var request_target: StringName
@export var request_amount: int = 0
## Trajets restants avant qu'il soit déçu.
@export var request_left: int = 0

## Infection de départ d'une recrue qui porte la maladie sans le savoir.
const HIDDEN_START: int = 15


static func create(member_name: String, member_role: StringName, label: String, is_infected: bool,
		start_trust: int = 50) -> CrewMember:
	var member := CrewMember.new()
	member.display_name = member_name
	member.role = member_role
	member.role_label = label
	member.infected = is_infected
	member.infection = HIDDEN_START if is_infected else 0
	member.trust = start_trust
	return member


func describe() -> String:
	return "%s (%s)" % [display_name, role_label]


## Ce que le joueur voit de l'infection : « 35 % », ou « ? » tant qu'on ne sait pas
## (aucun soigneur à bord, pas encore de symptômes) : un équipier sain affiche « ? » aussi.
func infection_text() -> String:
	return "%d %%" % infection if infection_known else "?"


## Infection visible par le joueur (0 si cachée).
func visible_infection() -> int:
	return infection if infection_known else 0


func to_dict() -> Dictionary:
	return {"name": display_name, "role": role, "role_label": role_label, "infected": infected,
		"health": health, "infection": infection, "fatigue": fatigue, "trust": trust,
		"resting": resting, "quarantined": quarantined, "infection_known": infection_known,
		"request_kind": request_kind, "request_target": request_target, "request_amount": request_amount,
		"request_left": request_left}


## Recrée un équipier depuis une sauvegarde (les anciennes n'ont que nom, rôle, infecté).
static func from_dict(entry: Dictionary) -> CrewMember:
	var member := create(entry["name"], StringName(entry["role"]), entry["role_label"], bool(entry.get("infected", false)))
	member.health = clampi(int(entry.get("health", 100)), 0, 100)
	member.infection = clampi(int(entry.get("infection", member.infection)), 0, 100)
	member.fatigue = clampi(int(entry.get("fatigue", 0)), 0, 100)
	member.trust = clampi(int(entry.get("trust", 50)), 0, 100)
	member.resting = bool(entry.get("resting", false))
	member.quarantined = bool(entry.get("quarantined", false))
	member.infection_known = bool(entry.get("infection_known", false))
	member.request_kind = StringName(entry.get("request_kind", ""))
	member.request_target = StringName(entry.get("request_target", ""))
	member.request_amount = int(entry.get("request_amount", 0))
	member.request_left = int(entry.get("request_left", 0))
	return member


func has_request() -> bool:
	return request_kind != &""


func clear_request() -> void:
	request_kind = &""
	request_target = &""
	request_amount = 0
	request_left = 0
