extends SceneTree
## godot --headless --path . -s res://tests/run_tests.gd
## Runs every test_* method in tests/test_*.gd; methods may await.
## Exit code is the number of failed tests.


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var files := Array(DirAccess.get_files_at("res://tests"))
	files.sort()
	var total := 0
	var failed := 0
	for f: String in files:
		if not (f.begins_with("test_") and f.ends_with(".gd")) or f == "test_case.gd":
			continue
		var script: GDScript = load("res://tests/" + f)
		for m in script.get_script_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			total += 1
			var t: Object = script.new()
			t.tree = self
			await t.call(name)
			var failures: PackedStringArray = t.failures
			if failures.is_empty():
				print("ok   %s %s" % [f, name])
			else:
				failed += 1
				print("FAIL %s %s" % [f, name])
				for msg in failures:
					print("     " + msg)
	print("%d tests, %d failed" % [total, failed])
	quit(mini(failed, 125) if total > 0 else 1)
