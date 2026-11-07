class_name CrewNames
extends RefCounted
## Prénoms et noms des recrues : assez pour qu'un équipage ne se ressemble jamais.
## Pur. Les prénoms ne se répètent pas dans un même équipage.

const FIRST_NAMES: Array[String] = [
	"Léa", "Malik", "Sofia", "Yanis", "Inès", "Hugo", "Nora", "Bastien",
	"Aya", "Théo", "Camille", "Jules", "Salomé", "Idris", "Maëlle", "Oscar",
	"Zoé", "Karim", "Elsa", "Noah", "Lina", "Raphaël", "Jade", "Mehdi",
	"Clara", "Adam", "Louise", "Sacha", "Rose", "Nathan", "Imane", "Victor",
	"Margot", "Elias", "Ambre", "Gaspard", "Yasmine", "Lucas", "Anouk", "Marius",
]
const SURNAMES: Array[String] = [
	"Morel", "Benali", "Lefèvre", "Diallo", "Garnier", "Rousseau", "Haddad", "Fontaine",
	"Mercier", "Nguyen", "Chevalier", "Bertin", "Moreau", "Traoré", "Lambert", "Ferrand",
	"Costa", "Leroux", "Marchand", "Okafor", "Perrin", "Aubert", "Kowalski", "Renaud",
	"Delcourt", "Mansour", "Vidal", "Barbier", "Lemoine", "Silva", "Carré", "Duval",
]


## Un prénom libre (pas déjà dans l'équipage), sinon n'importe lequel.
static func first_name(rng: RandomNumberGenerator, taken: Array[String]) -> String:
	var free: Array[String] = FIRST_NAMES.filter(func(name: String) -> bool: return not name in taken)
	var pool: Array[String] = free if not free.is_empty() else FIRST_NAMES
	return pool[rng.randi_range(0, pool.size() - 1)]


static func surname(rng: RandomNumberGenerator) -> String:
	return SURNAMES[rng.randi_range(0, SURNAMES.size() - 1)]
