class_name SaveGame
extends RefCounted
## The walk saved between sessions: what was found, the errands, who was heard
## out, which lamps burn, and where the player stands. Settings and
## achievements keep their own files. Written by Main as things happen (a find,
## an errand, a lamp, every AUTOSAVE_SECONDS) and on quit; never in the
## prologue or the dream, which are left and entered behind their own fades.

const PATH := "user://save.cfg"
const VERSION := 1
const AUTOSAVE_SECONDS := 20.0


## A lamp is known by where it stands (a decimetre grid): its index in
## Game.lamps follows the order districts enter the tree, which a new district
## would shift.
static func lamp_key(pos: Vector3) -> String:
	return "%d,%d,%d" % [roundi(pos.x * 10.0), roundi(pos.y * 10.0), roundi(pos.z * 10.0)]


## The state as plain data.
static func snapshot(player_pos: Vector3, player_yaw: float) -> Dictionary:
	var lamps: Array[String] = []
	for l: Node in Game.lamps:
		if l.lit:
			lamps.append(lamp_key((l as Node3D).global_position))
	return {
		"version": VERSION,
		"found": Game.found.keys(),
		"talked": Game.talked.duplicate(),
		"talks": Game.talks.duplicate(),
		"quests": Game.quests.duplicate(),
		"lamps": lamps,
		"pos": player_pos,
		"yaw": player_yaw,
	}


static func write(data: Dictionary, path := PATH) -> Error:
	var cfg := ConfigFile.new()
	for k: String in data:
		cfg.set_value("save", k, data[k])
	return cfg.save(path)


## The saved state, or {} when there is none or it is from another version.
static func read(path := PATH) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or int(cfg.get_value("save", "version", 0)) != VERSION:
		return {}
	var out := {}
	for k: String in cfg.get_section_keys("save"):
		out[k] = cfg.get_value("save", k)
	return out


static func exists(path := PATH) -> bool:
	return not read(path).is_empty()


static func erase(path := PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Puts the saved state back without the fanfare of first times: no panels,
## no toasts, no catch of a flame; the world hears state_restored and redraws.
static func apply(data: Dictionary) -> void:
	Game.found.clear()
	for id: Variant in data.get("found", []):
		Game.found[StringName(id)] = true
	Game.talked = (data.get("talked", {}) as Dictionary).duplicate()
	Game.talks = (data.get("talks", {}) as Dictionary).duplicate()
	Game.quests.clear()
	var quests: Dictionary = data.get("quests", {})
	for id: Variant in quests:
		Game.quests[String(id)] = int(quests[id])
	var lit: Array = data.get("lamps", [])
	for l: Node in Game.lamps:
		if lamp_key((l as Node3D).global_position) in lit:
			l.light_quietly()
	Game.state_restored.emit()
