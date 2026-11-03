extends RefCounted
## Assertion base: failures are collected, so one test reports every mismatch.

var failures := PackedStringArray()
## Set by the runner for tests that need physics.
var tree: SceneTree


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
