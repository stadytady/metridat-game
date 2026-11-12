extends Logger
## The engine's errors and warnings while tests, scenarios and the walkthrough
## run, each tagged with what was running then (`context`), so the report says
## which test a SCRIPT ERROR came from instead of a grep over the whole output.
## The engine may call a logger from any thread: records are taken under a lock.

const TYPES := ["error", "warning", "script", "shader"]

var context := ""
var _records: Array[Dictionary] = []
var _lock := Mutex.new()


func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	var where := "%s:%d" % [file, line]
	# a script error's own place is the script line, not the C++ that raised it
	for bt in script_backtraces:
		if bt.get_frame_count() > 0:
			where = "%s:%d" % [bt.get_frame_file(0), bt.get_frame_line(0)]
			break
	var rec := {
		"context": context,
		"type": TYPES[error_type] if error_type >= 0 and error_type < TYPES.size() else "error",
		"message": rationale if rationale != "" else code,
		"detail": code if rationale != "" else "",
		"where": where,
		"msec": Time.get_ticks_msec(),
	}
	_lock.lock()
	_records.append(rec)
	_lock.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass  # prints are the console's; only errors and warnings are evidence


## Every record so far, or those of one context.
func records(of := "") -> Array[Dictionary]:
	_lock.lock()
	var out: Array[Dictionary] = []
	for r in _records:
		if of == "" or r.context == of:
			out.append(r)
	_lock.unlock()
	return out


## Installs a logger for this process and returns it.
static func install() -> Logger:
	var l: Logger = load("res://tests/qa/qa_log.gd").new()
	OS.add_logger(l)
	return l


## Writes a result as indented JSON (Vector2/3 as arrays), making the folder.
static func write_json(path: String, data: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("qa: cannot write %s" % path)
		return
	f.store_string(JSON.stringify(_plain(data), "  "))


static func _plain(v: Variant) -> Variant:
	if v is Dictionary:
		var d := {}
		for k: Variant in v:
			d[str(k)] = _plain(v[k])
		return d
	if v is Array:
		var a := []
		for x: Variant in v:
			a.append(_plain(x))
		return a
	if v is Vector2 or v is Vector2i:
		return [v.x, v.y]
	if v is Vector3 or v is Vector3i:
		return [v.x, v.y, v.z]
	if v is StringName or v is NodePath:
		return str(v)
	if v is PackedStringArray:
		return Array(v)
	return v


## Command line value of --name=value (after the --), or `fallback`.
static func arg(name: String, fallback := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.substr(name.length() + 3)
	return fallback
