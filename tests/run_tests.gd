extends SceneTree
## godot --headless --path . -s res://tests/run_tests.gd [-- --json=PATH]
## Runs every test_* method in tests/test_*.gd; methods may await.
## Exit code is the number of failed tests. With --json the results go to PATH
## as well (tools/qa_report.py reads them): time, objects left behind and the
## engine's errors per test. A test that raised a SCRIPT ERROR fails: the error
## stopped it half way, and its checks after that never ran.

const QaLog := preload("res://tests/qa/qa_log.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var log: Object = QaLog.install()
	var json := QaLog.arg("json")
	var files := Array(DirAccess.get_files_at("res://tests"))
	files.sort()
	var total := 0
	var failed := 0
	var results: Array[Dictionary] = []
	var started := Time.get_ticks_msec()
	for f: String in files:
		if not (f.begins_with("test_") and f.ends_with(".gd")) or f == "test_case.gd":
			continue
		log.context = f
		var script: GDScript = load("res://tests/" + f)
		# a file that does not parse has no methods: without this it would be
		# skipped in silence and the run would still say "0 failed"
		if script == null or not script.can_instantiate():
			total += 1
			failed += 1
			print("FAIL %s does not parse" % f)
			results.append({"file": f, "name": "(parse)", "status": "fail", "ms": 0, "failures": ["does not parse"],
					"errors": log.records(f), "objects": 0})
			continue
		for m in script.get_script_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			total += 1
			var ctx := "%s::%s" % [f, name]
			log.context = ctx
			var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
			var t0 := Time.get_ticks_usec()
			var t: Object = script.new()
			t.tree = self
			await t.call(name)
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			var failures: PackedStringArray = t.failures
			t = null
			var errors: Array = log.records(ctx)
			var script_errors := errors.filter(func(r: Dictionary) -> bool: return r.type == "script")
			for r: Dictionary in script_errors:
				failures.append("SCRIPT ERROR %s at %s" % [r.message, r.where])
			if failures.is_empty():
				print("ok   %s %s" % [f, name])
			else:
				failed += 1
				print("FAIL %s %s" % [f, name])
				for msg in failures:
					print("     " + msg)
			results.append({"file": f, "name": name, "status": "ok" if failures.is_empty() else "fail",
					"ms": snappedf(ms, 0.1), "failures": failures, "errors": errors,
					"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT) - objects)})
	log.context = ""
	print("%d tests, %d failed" % [total, failed])
	if json != "":
		QaLog.write_json(json, {"kind": "unit", "total": total, "failed": failed,
				"ms": Time.get_ticks_msec() - started, "tests": results})
	quit(mini(failed, 125) if total > 0 else 1)
