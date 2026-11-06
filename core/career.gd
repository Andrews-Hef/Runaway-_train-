class_name Career
extends RefCounted
## La carrière du joueur : grades, mérite, talents, et ce que chaque grade permet de
## décider (AUTHORITY). Avant le grade requis, c'est le capitaine qui décide. Pur et testable.

const GRADES: Array[GradeData] = [
	preload("res://data/grades/recruit.tres"),
	preload("res://data/grades/soldier.tres"),
	preload("res://data/grades/corporal.tres"),
	preload("res://data/grades/sergeant.tres"),
	preload("res://data/grades/lieutenant.tres"),
	preload("res://data/grades/captain.tres"),
]


## Ce que le joueur a le droit de décider -> index du grade qui le permet.
##   &"recruit" : recruter les survivants rencontrés (Soldat)
##   &"route" : choisir la voie à l'aiguillage (Caporal)
##   &"crew" : diriger l'équipage (repos, soins, quarantaine, renvoi) (Sergent)
##   &"build" : construire et agrandir les voitures, renforcer la locomotive (Lieutenant)
##   &"missions" : envoyer un équipier en mission à sa place (Capitaine)
const AUTHORITY: Dictionary[StringName, int] = {
	&"recruit": 1,
	&"route": 2,
	&"crew": 3,
	&"build": 4,
	&"missions": 5,
}


## Ce que chaque grade débloque, pour l'interface (même ordre que GRADES).
const UNLOCKS: Array[String] = [
	"Sorties, fabrication de ton équipement, étude des plans",
	"Recruter les survivants rencontrés",
	"Choisir la voie à l'aiguillage",
	"Diriger l'équipage : soins, repos, quarantaine, renvoi",
	"Construire et agrandir les voitures, dépôt de la gare",
	"Envoyer un équipier en mission à ta place",
]


## Avancement vers le grade suivant, de 0 à 1 (1 au dernier grade).
static func progress(merit: int) -> float:
	var index: int = grade_index_for(merit)
	var next: GradeData = next_grade(index)
	if next == null:
		return 1.0
	var from: int = GRADES[index].merit_needed
	return clampf(float(merit - from) / float(maxi(next.merit_needed - from, 1)), 0.0, 1.0)


## Ce grade permet-il cette décision ?
static func allows(grade_index: int, permission: StringName) -> bool:
	return grade_index >= AUTHORITY.get(permission, 0)


## Nom du grade qui permet cette décision (« Caporal »).
static func required_grade(permission: StringName) -> String:
	return GRADES[AUTHORITY.get(permission, 0)].display_name


## Index du grade atteint avec ce mérite.
static func grade_index_for(merit: int) -> int:
	var index: int = 0
	for i: int in GRADES.size():
		if merit >= GRADES[i].merit_needed:
			index = i
	return index


## Le grade suivant, ou null au dernier.
static func next_grade(index: int) -> GradeData:
	return GRADES[index + 1] if index + 1 < GRADES.size() else null


## Somme d'un bonus (nom de propriété de PerkData) sur tous les talents choisis.
static func bonus(perks: Array[PerkData], stat: StringName) -> float:
	var total: float = 0.0
	for perk: PerkData in perks:
		total += float(perk.get(stat))
	return total


static func find_perk(id: StringName) -> PerkData:
	for grade: GradeData in GRADES:
		for perk: PerkData in grade.perks:
			if perk.id == id:
				return perk
	return null
