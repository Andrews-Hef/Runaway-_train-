class_name CrewMember
extends Resource
## Un membre d'équipage recruté pendant une sortie.
##
## `infected` est caché au joueur : une recrue peut porter la maladie sans
## que ça se voie. Ce sera la base de la quarantaine (voir la note Infection).

@export var display_name: String
## Rôle stable, utilisé par le code plus tard (bonus, missions) : &"mechanic", &"scout"...
@export var role: StringName
## Rôle affiché au joueur : « mécano », « éclaireur »...
@export var role_label: String
@export var infected: bool = false


static func create(member_name: String, member_role: StringName, label: String, is_infected: bool) -> CrewMember:
	var member := CrewMember.new()
	member.display_name = member_name
	member.role = member_role
	member.role_label = label
	member.infected = is_infected
	return member


func describe() -> String:
	return "%s (%s)" % [display_name, role_label]
