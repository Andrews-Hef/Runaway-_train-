class_name Campaign
extends RefCounted
## Le fil de la campagne entre les scènes : nouvelle partie, continuer, sauvegardes,
## reprise à la dernière gare quand on rate le train.
##
## GameState garde l'état de la partie et sait se mettre en dictionnaire ;
## SaveStore écrit sur le disque ; ici on décide quand sauvegarder et où reprendre.

const JOURNEY_SCENE: String = "res://levels/journey/journey.tscn"
const REFUGE_SCENE: String = "res://levels/refuge/refuge.tscn"
## Où reprendre une sauvegarde.
const SCENES: Dictionary[String, String] = {
	"journey": JOURNEY_SCENE,
	"refuge": REFUGE_SCENE,
}


## Nouvelle campagne : le départ du train sert de premier point de reprise.
static func start_new(tree: SceneTree) -> void:
	GameState.new_run()
	GameState.pending_intro = true
	_save(SaveStore.CHECKPOINT, "journey")
	_save(SaveStore.RESUME, "journey")
	tree.change_scene_to_file(JOURNEY_SCENE)


## Reprend la session enregistrée (écran titre). Renvoie false s'il n'y en a pas.
static func continue_game(tree: SceneTree) -> bool:
	return _load_and_go(tree, SaveStore.RESUME)


## Train raté : on reprend au dernier point de reprise (dernière gare, ou départ).
static func retry(tree: SceneTree) -> void:
	if not _load_and_go(tree, SaveStore.CHECKPOINT):
		start_new(tree)


## Chaque trajet : sauvegarde de session (le téléphone peut fermer l'appli).
static func autosave_journey() -> void:
	_save(SaveStore.RESUME, "journey")


## Train raté : la session reprendra elle aussi au point de reprise (pas de retour
## en arrière en fermant l'appli).
static func train_missed() -> void:
	var data: Dictionary = SaveStore.read(SaveStore.CHECKPOINT)
	if not data.is_empty():
		SaveStore.write(SaveStore.RESUME, data)


## Arrivée à une gare refuge : nouveau point de reprise.
static func reach_refuge() -> void:
	_save(SaveStore.CHECKPOINT, "refuge")
	_save(SaveStore.RESUME, "refuge")


static func has_resume() -> bool:
	return not SaveStore.read(SaveStore.RESUME).is_empty()


## Texte court de la sauvegarde (« Arrêt n°6 : Forêt morte »), vide s'il n'y en a pas.
static func describe(slot: String) -> String:
	return SaveStore.read(slot).get("label", "")


## Où reprendra-t-on après un train raté ? Le texte de la dernière gare, ou le départ.
static func retry_place() -> String:
	var data: Dictionary = SaveStore.read(SaveStore.CHECKPOINT)
	if data.get("location", "") == "refuge":
		return String(data.get("label", "la dernière gare refuge"))
	return "le départ du train"


static func _save(slot: String, location: String) -> void:
	var data: Dictionary = GameState.to_save()
	data["location"] = location
	SaveStore.write(slot, data)


static func _load_and_go(tree: SceneTree, slot: String) -> bool:
	var data: Dictionary = SaveStore.read(slot)
	if data.is_empty() or not GameState.load_save(data):
		return false
	var scene: String = SCENES.get(data.get("location", "journey"), JOURNEY_SCENE)
	tree.paused = false
	tree.change_scene_to_file(scene)
	return true
