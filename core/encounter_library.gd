class_name EncounterLibrary
## Catalogue des rencontres, rangées par type de point d'intérêt.
##
## Le générateur de zones ne manipule que des identifiants (il reste pur) ;
## la zone retrouve ici la rencontre complète à partir de l'identifiant.

const BY_ID: Dictionary[StringName, EncounterData] = {
	&"refugee_mechanic": preload("res://data/encounters/refugee_mechanic.tres"),
	&"wounded_scout": preload("res://data/encounters/wounded_scout.tres"),
	&"merchant_herbalist": preload("res://data/encounters/merchant_herbalist.tres"),
	&"merchant_scrapper": preload("res://data/encounters/merchant_scrapper.tres"),
	&"abandoned_backpack": preload("res://data/encounters/abandoned_backpack.tres"),
	&"locked_locker": preload("res://data/encounters/locked_locker.tres"),
}

## Rencontres possibles pour chaque type de point d'intérêt.
const POOLS: Dictionary[StringName, Array] = {
	&"refugee": [&"refugee_mechanic", &"wounded_scout"],
	&"merchant": [&"merchant_herbalist", &"merchant_scrapper"],
	&"backpack": [&"abandoned_backpack"],
	&"locker": [&"locked_locker"],
}


static func get_encounter(id: StringName) -> EncounterData:
	return BY_ID.get(id, null)
