class_name Career
extends RefCounted
## La carrière du joueur : grades, mérite, talents. Pur et testable.

const GRADES: Array[GradeData] = [
	preload("res://data/grades/recruit.tres"),
	preload("res://data/grades/soldier.tres"),
	preload("res://data/grades/corporal.tres"),
	preload("res://data/grades/sergeant.tres"),
	preload("res://data/grades/lieutenant.tres"),
	preload("res://data/grades/captain.tres"),
]


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
