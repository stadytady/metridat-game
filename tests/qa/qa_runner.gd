extends Node
## Runs one QA scenario (tests/scenarios/<name>.gd) in the live game: puts the
## world into its fixture, runs it, and writes <out>/scenario_<name>.json with
## its steps, failures, the engine's errors and the frames it took. Main adds it
## for --qa=<name>; tests/ is not exported, so a shipped game has no such mode.

const QaLog := preload("res://tests/qa/qa_log.gd")
const DIRECTOR := preload("res://scripts/core/director.gd")

var bot: Node
var log: Object
var out := "user://qa"
var _name := ""
var _scenario: RefCounted
var _steps: Array[Dictionary] = []
var _shots: Array[String] = []
var _t0 := 0
var _done := false


func _ready() -> void:
	_name = QaLog.arg("qa")
	out = QaLog.arg("qa-out", out)
	log = QaLog.install()
	log.context = _name
	_run.call_deferred()


func _run() -> void:
	_t0 = Time.get_ticks_msec()
	var path := "res://tests/scenarios/%s.gd" % _name
	var script: GDScript = load(path) if ResourceLoader.exists(path) else null
	if script == null or not script.can_instantiate():
		begin_step("load")
		note_failure("no scenario %s (or it does not parse)" % path)
		_finish()
		return
	# the walkthrough's bot, idle: no mode flag, so it only lends its steps
	bot = DIRECTOR.new()
	bot.name = "Director"
	bot._out = out.path_join("shots")
	get_parent().add_child(bot)
	_scenario = script.new()
	_scenario.runner = self
	var fx: Dictionary = _scenario.fixture()
	var watchdog := get_tree().create_timer(float(fx.get("timeout", 120.0)), true, true)
	watchdog.timeout.connect(func() -> void:
		if not _done:
			note_failure("timed out after %.0f s" % float(fx.get("timeout", 120.0)))
			_finish())
	var p: CharacterBody3D = get_parent().player()
	p.bot_enabled = true
	await _frames(5)
	begin_step("fixture")
	apply_fixture(fx)
	await _frames(5)
	begin_step("run")
	await _scenario.run()
	_finish()


## Puts the game into the state a fixture names: through SaveGame.apply, the
## same quiet restore a resumed walk uses, then the hour, place and device.
func apply_fixture(fx: Dictionary) -> void:
	if fx.has("hour"):
		Game.time_override = float(fx.hour)
	if fx.has("lang"):
		Game.language = String(fx.lang)
		TranslationServer.set_locale(Game.language)
	var found: Array = []
	var f: Variant = fx.get("found", [])
	if f is int:
		for s: Variant in bot._route():
			if s is String and Game.registry.has(StringName(s)) and found.size() < int(f):
				found.append(StringName(s))
	else:
		for id: Variant in f:
			found.append(StringName(id))
	var lamps: Array = []
	var l: Variant = fx.get("lamps", "none")
	for i in Game.lamps.size():
		if l is String and l == "all" or l is int and i < int(l):
			lamps.append(SaveGame.lamp_key((Game.lamps[i] as Node3D).global_position))
	SaveGame.apply({"version": SaveGame.VERSION, "found": found, "talked": fx.get("talked", {}),
			"talks": fx.get("talks", {}), "quests": fx.get("quests", {}), "lamps": lamps})
	var p: CharacterBody3D = get_parent().player()
	if fx.has("at"):
		var at: Vector2 = fx.at
		p.global_position = Vector3(at.x, Topo.surface(at.x, at.y) + 0.05, at.y)
		p.velocity = Vector3.ZERO
	if fx.has("look"):
		p.look_at_point(fx.look)
	Game.set_pad(bool(fx.get("pad", false)))


func begin_step(label: String) -> void:
	var now := Time.get_ticks_msec()
	if not _steps.is_empty():
		_steps[-1].ms = now - int(_steps[-1].start)
	_steps.append({"label": label, "start": now, "ms": 0, "failures": []})
	print("qa %s: %s" % [_name, label])


func note_failure(msg: String) -> void:
	if _steps.is_empty():
		begin_step("run")
	(_steps[-1].failures as Array).append(msg)
	print("     FAIL ", msg)


## Saves a frame under the scenario's name, unless nothing is drawn (headless).
func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await _frames(4)
	var file := "%s_%s.png" % [_name, name]
	DirAccess.make_dir_recursive_absolute(out.path_join("shots"))
	get_viewport().get_texture().get_image().save_png(out.path_join("shots").path_join(file))
	_shots.append("shots/" + file)


func _finish() -> void:
	if _done:
		return
	_done = true
	begin_step("end")
	_steps.pop_back()
	var fails: Array = []
	for s in _steps:
		fails.append_array(s.failures)
	var errors: Array = log.records()
	for r: Dictionary in errors:
		if r.type == "script":
			fails.append("SCRIPT ERROR %s at %s" % [r.message, r.where])
	var ok := fails.is_empty()
	QaLog.write_json(out.path_join("scenario_%s.json" % _name), {
		"kind": "scenario", "name": _name, "status": "ok" if ok else "fail",
		"ms": Time.get_ticks_msec() - _t0, "steps": _steps, "failures": fails,
		"errors": errors, "shots": _shots, "found": Game.found_count(), "total": Game.total(),
	})
	print("SCENARIO %s %s" % [_name, "PASS" if ok else "FAIL"])
	get_tree().quit(0 if ok else 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
