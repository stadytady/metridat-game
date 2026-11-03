extends Node
## Autoload: input map, settings and discovery state. UI and world talk
## through its signals instead of holding references to each other.

signal discovered(discovery: Discovery, is_new: bool)
signal inspect_closed
signal location_entered(title: String)
signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"

var mouse_sensitivity := 1.0
var invert_y := false
var psx_effects := true
## "en" or "ru". Empty until settings load: then the system language decides.
var language := ""
const LANGUAGES := ["en", "ru"]

## id -> Discovery, filled by inspectables as they enter the tree.
var registry := {}
var found := {}
## Overrides the hour for automation (screenshots); negative = follow progress.
var time_override := -1.0
## Lamps along the route: registered as they enter the tree.
var lamps: Array[Node] = []
signal lamp_lit(lit: int, total: int)
signal dialogue_requested(npc: Node)
## npc_id -> true once the whole conversation was heard.
var talked := {}

## True while the info panel or pause menu owns the input.
var ui_blocking := false
## Frame a UI layer closed on: the same Esc must not reopen another layer.
var ui_closed_frame := -1


func _ready() -> void:
	_setup_input()
	load_settings()


func _exit_tree() -> void:
	# Static caches would otherwise outlive the resource system at shutdown.
	Mats.clear()
	Props.clear()


func _setup_input() -> void:
	var keys := {
		&"move_forward": [KEY_W, KEY_UP],
		&"move_back": [KEY_S, KEY_DOWN],
		&"move_left": [KEY_A, KEY_LEFT],
		&"move_right": [KEY_D, KEY_RIGHT],
		&"sprint": [KEY_SHIFT],
		&"jump": [KEY_SPACE],
		&"interact": [KEY_E],
		&"pause": [KEY_ESCAPE],
		&"journal": [KEY_J],
		&"perf_overlay": [KEY_F3],
	}
	for action: StringName in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k: Key in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


func time_target() -> float:
	if time_override >= 0.0:
		return time_override
	return DayCycle.target_for(found_count(), total())


func lamps_lit() -> int:
	return lamps.filter(func(l: Node) -> bool: return l.lit).size()


func register(d: Discovery) -> void:
	assert(not registry.has(d.id) or registry[d.id] == d, "duplicate discovery id " + d.id)
	registry[d.id] = d


func total() -> int:
	return registry.size()


func found_count() -> int:
	return found.size()


func mark_found(d: Discovery) -> void:
	var is_new := not found.has(d.id)
	found[d.id] = true
	discovered.emit(d, is_new)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		mouse_sensitivity = clampf(float(cfg.get_value("input", "mouse_sensitivity", 1.0)), 0.1, 4.0)
		invert_y = bool(cfg.get_value("input", "invert_y", false))
		psx_effects = bool(cfg.get_value("video", "psx_effects", true))
		language = String(cfg.get_value("ui", "language", ""))
	if language not in LANGUAGES:
		language = "ru" if OS.get_locale_language() == "ru" else "en"
	TranslationServer.set_locale(language)
	settings_changed.emit()


## Switches the UI and all texts; Labels holding translation keys update
## themselves, formatted ones listen for NOTIFICATION_TRANSLATION_CHANGED.
func set_language(lang: String) -> void:
	assert(lang in LANGUAGES)
	language = lang
	TranslationServer.set_locale(lang)
	save_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("input", "invert_y", invert_y)
	cfg.set_value("video", "psx_effects", psx_effects)
	cfg.set_value("ui", "language", language)
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("settings not saved: %s" % error_string(err))
	settings_changed.emit()
