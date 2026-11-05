extends Node
## Achievements. Five for the vertical slice, and every id is also the Steamworks
## API name, so shipping to Steam needs nothing but a backend object:
##
##     Achievements.backend = SteamBackend.new()   # has unlock_achievement(id)
##
## The same names must be created in the Steamworks dashboard; nothing here talks
## to Steam directly, so the desktop, web and test builds all work unchanged.
## Progress rules are pure (see satisfied()), which is what the tests drive.

const PATH := "user://achievements.cfg"

## id -> [name key, description key, hidden]
const LIST := {
	"ACH_FIRST_FIND": ["ACH_FIRST_FIND_NAME", "ACH_FIRST_FIND_DESC", false],
	"ACH_ALL_FINDS": ["ACH_ALL_FINDS_NAME", "ACH_ALL_FINDS_DESC", false],
	"ACH_ALL_LAMPS": ["ACH_ALL_LAMPS_NAME", "ACH_ALL_LAMPS_DESC", false],
	"ACH_HEARD_ALL": ["ACH_HEARD_ALL_NAME", "ACH_HEARD_ALL_DESC", false],
	"ACH_DREAM": ["ACH_DREAM_NAME", "ACH_DREAM_DESC", false],
	"ACH_SILENT": ["ACH_SILENT_NAME", "ACH_SILENT_DESC", false],
	"ACH_AGAIN": ["ACH_AGAIN_NAME", "ACH_AGAIN_DESC", false],
	"ACH_NIGHT": ["ACH_NIGHT_NAME", "ACH_NIGHT_DESC", false],
}

## How long the player has to stand in the city after dark for ACH_NIGHT.
const NIGHT_SECONDS := 60.0
## After this hour the night counts.
const NIGHT_FROM := 0.9

var backend: Object
var unlocked := {}
var _cfg := ConfigFile.new()
var _night_seconds := 0.0

signal unlocked_signal(id: String)


func _ready() -> void:
	_load()
	Game.discovered.connect(func(_d: Discovery, is_new: bool) -> void:
		if is_new:
			_check())
	Game.lamp_lit.connect(func(_lit: int, _total: int) -> void: _check())
	Game.dream_changed.connect(func(_on: bool) -> void: _check())
	_check()


## Which achievements this much progress earns. Pure: no tree, no signals, so a
## test can drive every combination.
static func satisfied(found: int, total: int, lamps_lit: int, lamps: int, heard: int,
		voices: int, dreamed: bool) -> PackedStringArray:
	var out := PackedStringArray()
	if found >= 1:
		out.append("ACH_FIRST_FIND")
	if total > 0 and found >= total:
		out.append("ACH_ALL_FINDS")
	if lamps > 0 and lamps_lit >= lamps:
		out.append("ACH_ALL_LAMPS")
	if voices > 0 and heard >= voices:
		out.append("ACH_HEARD_ALL")
	if dreamed:
		out.append("ACH_DREAM")
	return out


## The quiet ones, each with its own little rule.
static func silent_earned(heard: int, dreamed: bool) -> bool:
	return dreamed and heard == 0


## Fedr has a second, shorter line for anyone who comes back after the first talk.
static func again_earned(talks: Dictionary, npc := "actor") -> bool:
	return int(talks.get(npc, 0)) >= 2


static func night_earned(seconds: float) -> bool:
	return seconds >= NIGHT_SECONDS


func is_unlocked(id: String) -> bool:
	return unlocked.has(id)


func count() -> int:
	return unlocked.size()


## Unlocks once, saves, tells the HUD and, when a backend is set, Steam.
func unlock(id: String) -> bool:
	if not LIST.has(id) or unlocked.has(id):
		return false
	unlocked[id] = true
	_save()
	unlocked_signal.emit(id)
	if backend != null and backend.has_method("unlock_achievement"):
		backend.unlock_achievement(id)
	return true


## How many voices the player has heard out: every talkable Npc in the city.
func voices() -> int:
	var n := 0
	for node: Node in get_tree().get_nodes_in_group(&"npc"):
		if node.get("talkable"):
			n += 1
	return n


func heard() -> int:
	var n := 0
	for id: String in Game.talked:
		if Game.talked[id]:
			n += 1
	return n


func _check() -> void:
	for id in satisfied(Game.found_count(), Game.total(), Game.lamps_lit(), Game.lamps.size(),
			heard(), voices(), Game.dreaming):
		unlock(id)
	if silent_earned(heard(), Game.dreaming):
		unlock("ACH_SILENT")
	if again_earned(Game.talks):
		unlock("ACH_AGAIN")


## The night watch counts real time spent in the city after dark, not in a panel.
func _process(delta: float) -> void:
	if Game.ui_blocking or Game.time_target() < NIGHT_FROM:
		return
	if is_unlocked("ACH_NIGHT"):
		set_process(false)
		return
	_night_seconds += delta
	if night_earned(_night_seconds):
		unlock("ACH_NIGHT")
		set_process(false)


func _load() -> void:
	if _cfg.load(PATH) != OK:
		return
	for id: String in LIST:
		if _cfg.get_value("achievements", id, false):
			unlocked[id] = true


func _save() -> void:
	for id: String in unlocked:
		_cfg.set_value("achievements", id, true)
	_cfg.save(PATH)
