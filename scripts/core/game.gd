extends Node
## Autoload: input map, settings and discovery state. UI and world talk
## through its signals instead of holding references to each other.

signal discovered(discovery: Discovery, is_new: bool)
signal inspect_closed
signal location_entered(title: String)
signal settings_changed
## A saved walk was put back (SaveGame.apply): redraw from Game's state, quietly.
signal state_restored
## Save now (the pause menu's Quit asks before the tree goes away).
signal save_requested
## The player put down the mouse for the pad or back: legends and texts redraw.
signal device_changed

## Where the settings live (tests point it elsewhere, not to overwrite the player's).
var settings_path := "user://settings.cfg"

var mouse_sensitivity := 1.0
## Field of view in degrees (running widens it by RUN_FOV more).
var fov := 72.0
const FOV_MIN := 60.0
const FOV_MAX := 100.0
## action -> physical key, only for keys the player moved (Keys.DEFAULT_KEYS otherwise).
var key_binds := {}
## True while the last thing touched was the gamepad.
var pad := false
var invert_y := false
## Master volume, 0 (mute) .. 1; set_volume() applies it to the Master bus.
var master_volume := 1.0
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
## How many times each Npc has been talked to: the second visit has its own line.
var talks := {}
## Errands (Quests): id -> Quests.NONE / TAKEN / FOUND / DONE.
var quests := {}
signal quest_changed(id: String, state: int)
## True from lying down in the abaton until waking: the hour is DayCycle.DREAM.
var dreaming := false
## The arrival at the pier the evening before, until the morning on the hill.
var prologue := false
## The prologue's own hour: dusk on the pier, then the night aboard and the
## dawn before the hill (Prologue.morning sets it, behind a fade).
var prologue_hour := DayCycle.PROLOGUE
signal prologue_changed(on: bool)
signal dream_requested
signal dream_changed(on: bool)

## True while the info panel or pause menu owns the input.
var ui_blocking := false
## Frame a UI layer closed on: the same Esc must not reopen another layer.
var ui_closed_frame := -1
## Time a UI layer closed: E is ignored for REARM_MS after it, or the press
## that closed a panel (or the next one right after) opens the find again
## and the player gets stuck on it.
var ui_closed_msec := -100000
const REARM_MS := 400


func _ready() -> void:
	# the pad is noticed in the pause menu too
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	load_settings()


func _exit_tree() -> void:
	# Static caches would otherwise outlive the resource system at shutdown.
	Mats.clear()
	Props.clear()


func _setup_input() -> void:
	Keys.setup(key_binds)


## The pad was touched (a button, a stick past the dead zone) or the keyboard
## and mouse were: the texts follow whichever is in the hands.
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		set_pad(true)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		set_pad(true)
	elif (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
		set_pad(false)
	elif event is InputEventMouseMotion and event.relative.length() > 6.0:
		set_pad(false)


func set_pad(on: bool) -> void:
	if on != pad:
		pad = on
		device_changed.emit()


## Moves an action to key k (swapping with whoever had it) and keeps it.
func bind_key(action: StringName, k: Key) -> void:
	key_binds = Keys.rebind(key_binds, action, k)
	Keys.setup(key_binds)
	save_settings()


func reset_keys() -> void:
	key_binds = {}
	Keys.setup(key_binds)
	save_settings()


func key_for(action: StringName) -> Key:
	return key_binds.get(action, Keys.DEFAULT_KEYS[action])


func set_fov(v: float) -> void:
	fov = clampf(v, FOV_MIN, FOV_MAX)
	save_settings()


func time_target() -> float:
	if time_override >= 0.0:
		return time_override
	if dreaming:
		return DayCycle.DREAM
	if prologue:
		return prologue_hour
	return DayCycle.target_for(found_count(), total())


func quest_state(id: String) -> int:
	return int(quests.get(id, Quests.NONE))


## For the dialogues: may the giver ask, has the player found it.
func quest_offered(id: String) -> bool:
	return quest_state(id) == Quests.NONE


func quest_ready(id: String) -> bool:
	return quest_state(id) == Quests.FOUND


func take_quest(id: String) -> void:
	_quest_step(id, "take")


func pick_quest_item(id: String) -> void:
	_quest_step(id, "pick")


func complete_quest(id: String) -> void:
	_quest_step(id, "give")


func _quest_step(id: String, step: String) -> void:
	var was := quest_state(id)
	var now: int = Quests.next_state(was, step)
	if now != was:
		quests[id] = now
		quest_changed.emit(id, now)


func lamps_lit() -> int:
	return lamps.filter(func(l: Node) -> bool: return l.lit).size()


func register(d: Discovery) -> void:
	assert(not registry.has(d.id) or registry[d.id] == d, "duplicate discovery id " + d.id)
	registry[d.id] = d


## The city's finds; the epilogue's do not count.
func total() -> int:
	return registry.values().filter(func(d: Discovery) -> bool: return not d.epilogue).size()


## Only finds the world still has: a saved walk can name one a later version
## took out, and it must not count (or crash the count).
func found_count() -> int:
	return found.keys().filter(func(id: StringName) -> bool: return registry.has(id) and not registry[id].epilogue).size()


func mark_found(d: Discovery) -> void:
	var is_new := not found.has(d.id)
	found[d.id] = true
	discovered.emit(d, is_new)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		mouse_sensitivity = clampf(float(cfg.get_value("input", "mouse_sensitivity", 1.0)), 0.1, 4.0)
		invert_y = bool(cfg.get_value("input", "invert_y", false))
		master_volume = clampf(float(cfg.get_value("audio", "master_volume", 1.0)), 0.0, 1.0)
		psx_effects = bool(cfg.get_value("video", "psx_effects", true))
		language = String(cfg.get_value("ui", "language", ""))
		fov = clampf(float(cfg.get_value("video", "fov", 72.0)), FOV_MIN, FOV_MAX)
		key_binds = {}
		for a: StringName in Keys.DEFAULT_KEYS:
			var k := int(cfg.get_value("keys", String(a), -1))
			if k > 0 and not Keys.reserved(k as Key):
				key_binds = Keys.rebind(key_binds, a, k as Key)
		Keys.setup(key_binds)
	if language not in LANGUAGES:
		language = "ru" if OS.get_locale_language() == "ru" else "en"
	TranslationServer.set_locale(language)
	apply_volume()
	settings_changed.emit()


## The Master bus level for a volume of 0..1: silence at 0, else decibels.
static func volume_db(v: float) -> float:
	return linear_to_db(clampf(v, 0.0001, 1.0))


func apply_volume() -> void:
	var bus := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_mute(bus, master_volume <= 0.0)
	AudioServer.set_bus_volume_db(bus, volume_db(master_volume))


func set_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	apply_volume()
	save_settings()


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
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("video", "psx_effects", psx_effects)
	cfg.set_value("ui", "language", language)
	cfg.set_value("video", "fov", fov)
	for a: StringName in key_binds:
		cfg.set_value("keys", String(a), int(key_binds[a]))
	var err := cfg.save(settings_path)
	if err != OK:
		push_warning("settings not saved: %s" % error_string(err))
	settings_changed.emit()


## Every panel calls this when it closes.
func mark_ui_closed() -> void:
	ui_closed_frame = Engine.get_process_frames()
	ui_closed_msec = Time.get_ticks_msec()


## E may act on the world again: no panel open and none closed just now.
func can_interact_now() -> bool:
	return not ui_blocking and Time.get_ticks_msec() - ui_closed_msec >= REARM_MS
