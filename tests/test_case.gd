extends RefCounted
## Minimal assertion base. A failed check records a message instead of aborting,
## so one test reports every mismatch.

var failures := PackedStringArray()


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func check_eq(got: Variant, want: Variant, msg: String = "") -> void:
	if typeof(got) != typeof(want) or got != want:
		failures.append("%s: want %s, got %s" % [msg, var_to_str(want), var_to_str(got)])
