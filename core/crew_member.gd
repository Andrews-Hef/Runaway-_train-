class_name CrewMember
extends Resource
## Un membre d'équipage : un nom, une apparence, un rôle, quatre stats (1 à 5) tirées
## à son arrivée, ce qu'il porte, et quatre jauges (0 à 100) qui vivent d'un trajet à
## l'autre (voir CrewLife) : vie, infection, fatigue, confiance.
##
## L'infection est cachée au joueur au début : une recrue peut porter la maladie
## sans que ça se voie. Elle se voit aux symptômes (CrewLife.SYMPTOMS) ou tout de
## suite si un soigneur travaille à bord.

## Prénom : c'est ainsi qu'on l'appelle partout.
@export var display_name: String
@export var surname: String
## Apparence : 1 à CrewLooks.COUNT (sprite et portrait).
@export var look: int = 1
## Rôle : &"mechanic" (répare le train), &"medic" (soigne, repère les infectés),
## &"scout" (repère les hordes).
@export var role: StringName
## Rôle affiché au joueur : « mécanique », « soins », « repérage »...
@export var role_label: String
## Porte la maladie (au départ, caché).
@export var infected: bool = false

@export_group("Stats (1 à 5)")
## Force : moins de blessures au combat.
@export_range(1, 5) var strength: int = 3
## Endurance : se fatigue moins, résiste mieux à l'infection.
@export_range(1, 5) var endurance: int = 3
## Adresse : rapporte plus en mission, répare mieux.
@export_range(1, 5) var skill: int = 3
## Sang-froid : décroche à temps quand un combat tourne mal.
@export_range(1, 5) var nerve: int = 3

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
## Les stats, dans l'ordre d'affichage : [propriété, nom, ce qu'elle fait].
const STATS: Array[Array] = [
	[&"strength", "Force", "Moins de blessures au combat"],
	[&"endurance", "Endurance", "Se fatigue moins, résiste mieux à l'infection"],
	[&"skill", "Adresse", "Rapporte plus en mission, répare mieux"],
	[&"nerve", "Sang-froid", "Décroche à temps quand un combat tourne mal"],
]

## Ce qu'il porte : mêmes emplacements que le joueur (tenue, masque, sac, outil, arme).
var loadout: Loadout = Loadout.new()


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


func full_name() -> String:
	return display_name if surname.is_empty() else "%s %s" % [display_name, surname]


func stat(id: StringName) -> int:
	return int(get(id))


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
		"request_left": request_left, "surname": surname, "look": look,
		"stats": [strength, endurance, skill, nerve],
		"equipped": loadout.equipped.values().map(func(item: ItemData) -> String: return String(item.id))}


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
	member.surname = str(entry.get("surname", ""))
	# Anciennes sauvegardes : une apparence tirée du prénom, des stats moyennes.
	member.look = CrewLooks.valid(int(entry.get("look", CrewLooks.from_name(member.display_name))))
	var stats: Array = entry.get("stats", [3, 3, 3, 3])
	if stats.size() == 4:
		member.strength = clampi(int(stats[0]), 1, 5)
		member.endurance = clampi(int(stats[1]), 1, 5)
		member.skill = clampi(int(stats[2]), 1, 5)
		member.nerve = clampi(int(stats[3]), 1, 5)
	for id: Variant in entry.get("equipped", []):
		var item: ItemData = ItemCatalog.get_item(StringName(str(id)))
		if item:
			member.loadout.equip(item)
	return member


func has_request() -> bool:
	return request_kind != &""


func clear_request() -> void:
	request_kind = &""
	request_target = &""
	request_amount = 0
	request_left = 0
