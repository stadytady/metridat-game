extends "res://tests/test_case.gd"
## The QA harness itself: the logger files an engine error under what was
## running, results go out as plain JSON, and every scenario parses, extends the
## base and asks only for fixture keys the runner knows.

const QaLog := preload("res://tests/qa/qa_log.gd")
const KEYS := ["found", "quests", "talked", "talks", "lamps", "hour", "at", "look", "pad", "lang", "timeout"]


func test_an_engine_error_is_filed_under_its_context() -> void:
	# Called as the engine calls it, not through push_error: a real error here
	# would land in the run's own log and count against the report.
	var log: Object = QaLog.new()
	log.context = "qa_probe"
	log._log_error("f", "core/x.cpp", 7, "cond", "qa probe error", false, 2, [] as Array[ScriptBacktrace])
	log.context = ""
	log._log_error("f", "core/x.cpp", 9, "qa probe bare", "", false, 0, [] as Array[ScriptBacktrace])
	var mine: Array = log.records("qa_probe")
	check(mine.size() == 1 and mine[0].message == "qa probe error" and mine[0].type == "script" and mine[0].detail == "cond",
			"the probe error was not filed under its context: %s" % [mine])
	var all: Array = log.records()
	check(all.size() == 2 and all[1].message == "qa probe bare" and all[1].type == "error",
			"an error without a rationale lost its message: %s" % [all])
	check(String(mine[0].where) == "core/x.cpp:7", "the error points at %s" % mine[0].where)


func test_results_are_plain_json() -> void:
	var path := "user://qa_probe.json"
	QaLog.write_json(path, {"at": Vector3(1, 2, 3), "id": &"coin", "list": PackedStringArray(["a"]), "n": 2})
	var back: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(back is Dictionary, "the file is not JSON")
	if back is Dictionary:
		check(back.at == [1.0, 2.0, 3.0] and back.id == "coin" and back.list == ["a"], "values did not come back plain: %s" % [back])


func test_every_scenario_parses_and_asks_for_known_keys() -> void:
	var files := Array(DirAccess.get_files_at("res://tests/scenarios")).filter(func(f: String) -> bool: return f.ends_with(".gd"))
	check(files.size() >= 5, "only %d scenarios" % files.size())
	for f: String in files:
		var s: GDScript = load("res://tests/scenarios/" + f)
		check(s != null and s.can_instantiate(), "%s does not parse" % f)
		if s == null or not s.can_instantiate():
			continue
		check(s.get_base_script() != null and s.get_base_script().resource_path == "res://tests/qa/scenario.gd", "%s does not extend the scenario base" % f)
		var sc: Object = s.new()
		var fx: Dictionary = sc.fixture()
		for k: String in fx:
			check(k in KEYS, "%s asks for an unknown fixture key %s" % [f, k])
		check(s.get_script_method_list().any(func(m: Dictionary) -> bool: return m.name == "run"), "%s has no run()" % f)
