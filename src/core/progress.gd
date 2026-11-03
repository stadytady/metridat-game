class_name Progress
extends RefCounted
## Unlocked level and best move counts. On Web user:// is backed by IndexedDB.

const PATH := "user://progress.cfg"

var unlocked := 1
var best := {}


func load_from(path: String = PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	unlocked = maxi(1, int(cfg.get_value("progress", "unlocked", 1)))
	if cfg.has_section("best"):
		for key in cfg.get_section_keys("best"):
			best[int(key)] = int(cfg.get_value("best", key))


func save_to(path: String = PATH) -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked", unlocked)
	for level: int in best:
		cfg.set_value("best", str(level), best[level])
	return cfg.save(path)


## Returns true if this is a new best for the level.
func record(level: int, moves: int) -> bool:
	unlocked = maxi(unlocked, level + 1)
	if best.has(level) and best[level] <= moves:
		return false
	best[level] = moves
	return true
