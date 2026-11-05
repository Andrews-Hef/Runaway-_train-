class_name CrewRequests
extends RefCounted
## Les demandes personnelles de l'équipage. Les remplir fait monter la confiance.
## Pur : GameState et CrewLife s'en servent.
##
## Trois sortes :
## - &"deliver" : donner des ressources du stock (bouton dans l'onglet Équipage) ;
## - &"eliminate" : éliminer des ennemis d'une faction pendant un arrêt ;
## - &"bring" : rapporter des ressources d'un arrêt (vérifié au retour, rien n'est pris).

## Confiance gagnée en remplissant une demande, perdue si elle est ignorée.
const TRUST_REWARD: int = 20
const TRUST_DISAPPOINTED: int = -5
## Trajets avant que l'équipier soit déçu.
const DURATION: int = 4
## Chance, à chaque trajet, qu'un équipier sans demande en ait une nouvelle.
const NEW_CHANCE: float = 0.35

## Demandes possibles par rôle : [sorte, cible, quantité min, quantité max].
const POOLS: Dictionary[StringName, Array] = {
	&"mechanic": [[&"deliver", &"parts", 1, 2], [&"deliver", &"scrap", 4, 6], [&"bring", &"scrap", 4, 6]],
	&"medic": [[&"deliver", &"antiseptic", 1, 1], [&"deliver", &"herb", 3, 4], [&"bring", &"infected_herb", 2, 4],
		[&"deliver", &"cloth", 2, 3]],
	&"scout": [[&"eliminate", &"raider", 1, 2], [&"eliminate", &"infected", 2, 3], [&"bring", &"wood", 3, 5]],
}
const DEFAULT_POOL: Array = [[&"deliver", &"cloth", 2, 3], [&"bring", &"herb", 2, 4]]
## Ce qu'ils disent, par sorte : {n} quantité, {what} ressource ou ennemis.
const LINES: Dictionary[StringName, String] = {
	&"deliver": "« J'ai besoin de {n} {what}. Tu peux m'en donner du stock ? »",
	&"eliminate": "« Élimine {n} {what} au prochain arrêt : ils ont pris les miens. »",
	&"bring": "« Rapporte {n} {what} d'un arrêt, s'il te plaît. »",
}
const ROLE_LINES: Dictionary[String, String] = {
	"mechanic:deliver": "« Mes outils lâchent : trouve-moi {n} {what}. »",
	"medic:deliver": "« Il me faut {n} {what} pour soigner les autres. »",
}
const FACTION_NAMES: Dictionary[StringName, String] = {&"raider": "pilleurs", &"infected": "infectés"}


## Donne une nouvelle demande à l'équipier, selon son rôle.
static func assign(member: CrewMember, rng: RandomNumberGenerator) -> void:
	var pool: Array = POOLS.get(member.role, DEFAULT_POOL)
	var entry: Array = pool[rng.randi_range(0, pool.size() - 1)]
	member.request_kind = entry[0]
	member.request_target = entry[1]
	member.request_amount = rng.randi_range(entry[2], entry[3])
	member.request_left = DURATION


## « Léa : « Mes outils lâchent : trouve-moi 2 pièces mécaniques. » »
static func text(member: CrewMember) -> String:
	if not member.has_request():
		return ""
	var line: String = ROLE_LINES.get("%s:%s" % [member.role, member.request_kind], LINES[member.request_kind])
	return line.replace("{n}", str(member.request_amount)).replace("{what}", target_name(member))


static func target_name(member: CrewMember) -> String:
	if member.request_kind == &"eliminate":
		return FACTION_NAMES.get(member.request_target, String(member.request_target))
	return MenuKit.loot_name(member.request_target).to_lower()


## Ce qu'il faut donner (demande &"deliver"), vide sinon.
static func cost(member: CrewMember) -> Dictionary[StringName, int]:
	var amounts: Dictionary[StringName, int] = {}
	if member.request_kind == &"deliver":
		amounts[member.request_target] = member.request_amount
	return amounts


## Une sortie remplit-elle sa demande (&"eliminate" ou &"bring") ?
static func met_by(member: CrewMember, result: ExpeditionResult) -> bool:
	match member.request_kind:
		&"eliminate":
			return result.kills_of_faction(member.request_target) >= member.request_amount
		&"bring":
			return result.get_amount(member.request_target) >= member.request_amount
	return false


## Demande remplie : confiance en plus, demande effacée. Renvoie la ligne du récit.
static func complete(member: CrewMember) -> String:
	member.trust = clampi(member.trust + TRUST_REWARD, 0, 100)
	member.clear_request()
	return "%s te remercie : confiance +%d." % [member.display_name, TRUST_REWARD]


## Un trajet passe : les demandes vieillissent ou expirent, de nouvelles arrivent.
static func tick(crew: Array[CrewMember], rng: RandomNumberGenerator, events: Array[String]) -> void:
	for member: CrewMember in crew:
		if member.has_request():
			member.request_left -= 1
			if member.request_left <= 0:
				member.clear_request()
				member.trust = clampi(member.trust + TRUST_DISAPPOINTED, 0, 100)
				events.append("La demande de %s est restée sans réponse : confiance %d." % [member.display_name, TRUST_DISAPPOINTED])
		elif rng.randf() < NEW_CHANCE:
			assign(member, rng)
			events.append("%s a une demande : %s" % [member.display_name, text(member)])
