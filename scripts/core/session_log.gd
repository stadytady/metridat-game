class_name SessionLog
extends Node
## A plain-text log of one played walk, for playtests: what the player found,
## where they went, who they talked to, and where they stood still for long -
## what they did, not what they remember doing. Started by Main only in a live
## game (never in automation), one file per session in user://sessions/, the
## oldest pruned past KEEP. Nothing personal: the game's version, the system
## and GPU names, the language, and times and places in the world.
## Not on the web: a browser's user:// cannot be handed to anyone.
## Line format: "<seconds since start, 1 decimal>\t<event>\t<details>".

const DIR := "user://sessions"
## How many logs to keep: a tester plays a few walks, not a hundred.
const KEEP := 20
## A position sample this often (s), and "still" after this long within STILL_R m.
const SAMPLE_EVERY := 10.0
const STILL_AFTER := 30.0
const STILL_R := 1.5

var path := ""
var _file: FileAccess
var _t0 := 0
var _player: Node3D
var _sample_t := 0.0
var _still_at := Vector3.INF
var _still_t := 0.0
var _still_told := false


## The game's version, as the title screen shows it.
static func version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", "?"))


## Whether a log is kept on this platform.
static func supported() -> bool:
	return not OS.has_feature("web")


## Begins a log in `dir` (DIR unless a test gives another). `how` is "new" or
## "continued"; `player` is sampled for positions.
func begin(how: String, player: Node3D, dir := DIR) -> void:
	_player = player
	DirAccess.make_dir_recursive_absolute(dir)
	_prune(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	path = "%s/%s.txt" % [dir, stamp]
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_warning("session log: cannot write " + path)
		return
	_t0 = Time.get_ticks_msec()
	write("session", "%s walk, version %s" % [how, version()])
	write("system", "%s, %s, %s" % [OS.get_name(), RenderingServer.get_video_adapter_name(), Engine.get_version_info().string])
	write("settings", "language %s, pad %s, PS1 effects %s, weather seed %d" % [Game.language, Game.pad, Game.psx_effects, Game.weather_seed])
	Game.discovered.connect(func(d: Discovery, is_new: bool) -> void:
		if is_new:
			write("find", "%s (%d/%d)" % [d.id, Game.found_count(), Game.total()]))
	Game.location_entered.connect(func(title: String) -> void: write("place", title))
	Game.dialogue_requested.connect(func(npc: Node) -> void: write("talk", String(npc.get("npc_id"))))
	Game.quest_changed.connect(func(id: String, state: int) -> void: write("errand", "%s -> %d" % [id, state]))
	Game.lamp_lit.connect(func(lit: int, total: int) -> void: write("lamp", "%d/%d" % [lit, total]))
	Game.prologue_changed.connect(func(on: bool) -> void: write("prologue", "start" if on else "end"))
	Game.dream_changed.connect(func(on: bool) -> void: write("dream", "start" if on else "end"))
	Game.coin_struck.connect(func(quality: String) -> void: write("coin", quality))
	Achievements.unlocked_signal.connect(func(id: String) -> void: write("achievement", id))


## One line, flushed at once: a crash or a closed window loses nothing.
func write(event: String, details := "") -> void:
	if _file == null:
		return
	var p := ""
	if _player != null and is_instance_valid(_player) and _player.is_inside_tree():
		var at := _player.global_position
		p = "\t@ %.1f, %.1f, %.1f" % [at.x, at.y, at.z]
	_file.store_line("%.1f\t%s\t%s%s" % [elapsed(), event, details, p])
	_file.flush()


func elapsed() -> float:
	return (Time.get_ticks_msec() - _t0) / 1000.0


## The end of the walk: how long, how much found.
func finish() -> void:
	if _file == null:
		return
	write("end", "%.0f s, %d/%d finds" % [elapsed(), Game.found_count(), Game.total()])
	_file.close()
	_file = null


func _process(delta: float) -> void:
	if _file == null or _player == null or not is_instance_valid(_player) or get_tree().paused:
		return
	_sample_t += delta
	if _sample_t >= SAMPLE_EVERY:
		_sample_t = 0.0
		write("pos")
	# standing still for long: lost, reading, or bored - all worth knowing
	var at := _player.global_position
	if _still_at == Vector3.INF or at.distance_to(_still_at) > STILL_R:
		if _still_told:
			write("moved", "after %.0f s" % _still_t)
		_still_at = at
		_still_t = 0.0
		_still_told = false
	else:
		_still_t += delta
		if _still_t >= STILL_AFTER and not _still_told:
			_still_told = true
			write("still", "%.0f s" % STILL_AFTER)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		finish()


## Keeps the newest KEEP - 1 logs, so the new one makes KEEP.
static func _prune(dir: String) -> void:
	var files := Array(DirAccess.get_files_at(dir)).filter(func(f: String) -> bool: return f.ends_with(".txt"))
	files.sort()
	while files.size() >= KEEP:
		DirAccess.remove_absolute("%s/%s" % [dir, files.pop_front()])
