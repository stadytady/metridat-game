class_name Keys
extends RefCounted
## What does what: the keys (a player may move them), the gamepad's buttons and
## sticks (fixed), and the names the texts show for them. Texts write {use},
## {back}, {journal}, {goals} where a key goes, and fill() puts in the key of the
## device the player is holding, so "[E]" never stands in a text a pad plays or
## where E is no longer the key.

## The actions a player may move to another key, in the order the controls page
## lists them, with their names.
const REBIND := [
	[&"move_forward", "UI_BIND_FORWARD"],
	[&"move_back", "UI_BIND_BACK"],
	[&"move_left", "UI_BIND_LEFT"],
	[&"move_right", "UI_BIND_RIGHT"],
	[&"sprint", "UI_ACTION_RUN"],
	[&"jump", "UI_ACTION_JUMP"],
	[&"interact", "UI_ACTION_USE"],
	[&"journal", "UI_ACTION_JOURNAL"],
	[&"goals", "UI_ACTION_GOALS"],
]
const DEFAULT_KEYS := {
	&"move_forward": KEY_W,
	&"move_back": KEY_S,
	&"move_left": KEY_A,
	&"move_right": KEY_D,
	&"sprint": KEY_SHIFT,
	&"jump": KEY_SPACE,
	&"interact": KEY_E,
	&"journal": KEY_J,
	&"goals": KEY_TAB,
}
## Keys that stay where they are whatever the player moves: the arrows walk too,
## Esc pauses and leaves a panel, the tilde and F3 are the developer's.
const FIXED_KEYS := {
	&"move_forward": [KEY_UP],
	&"move_back": [KEY_DOWN],
	&"move_left": [KEY_LEFT],
	&"move_right": [KEY_RIGHT],
	&"pause": [KEY_ESCAPE],
	&"back": [KEY_ESCAPE],
	&"admin": [KEY_QUOTELEFT],
	&"perf_overlay": [KEY_F3],
}
## The gamepad (Xbox layout; Godot names the buttons by position, so a
## PlayStation pad's cross is A).
const PAD_BUTTONS := {
	&"move_forward": [JOY_BUTTON_DPAD_UP],
	&"move_back": [JOY_BUTTON_DPAD_DOWN],
	&"move_left": [JOY_BUTTON_DPAD_LEFT],
	&"move_right": [JOY_BUTTON_DPAD_RIGHT],
	&"sprint": [JOY_BUTTON_LEFT_STICK, JOY_BUTTON_LEFT_SHOULDER],
	&"jump": [JOY_BUTTON_X],
	&"interact": [JOY_BUTTON_A],
	&"journal": [JOY_BUTTON_Y],
	&"goals": [JOY_BUTTON_BACK],
	&"pause": [JOY_BUTTON_START],
	&"back": [JOY_BUTTON_B],
}
## [axis, direction]: the left stick walks, the right one looks.
const PAD_AXES := {
	&"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	&"move_back": [JOY_AXIS_LEFT_Y, 1.0],
	&"move_left": [JOY_AXIS_LEFT_X, -1.0],
	&"move_right": [JOY_AXIS_LEFT_X, 1.0],
	&"look_left": [JOY_AXIS_RIGHT_X, -1.0],
	&"look_right": [JOY_AXIS_RIGHT_X, 1.0],
	&"look_up": [JOY_AXIS_RIGHT_Y, -1.0],
	&"look_down": [JOY_AXIS_RIGHT_Y, 1.0],
}
## A stick moved less than this is resting: worn pads drift.
const DEADZONE := 0.2
## What the legend and the texts call the pad's buttons.
const PAD_NAMES := {
	&"move": "LS",
	&"look": "RS",
	&"sprint": "LB",
	&"jump": "X",
	&"interact": "A",
	&"journal": "Y",
	&"goals": "SELECT",
	&"pause": "START",
	&"back": "B",
}
## Names for the keys whose own are long or unclear.
const KEY_NAMES := {
	KEY_ESCAPE: "ESC",
	KEY_UP: "↑",
	KEY_DOWN: "↓",
	KEY_LEFT: "←",
	KEY_RIGHT: "→",
}
## Placeholder in a text -> the action whose key it shows.
const TOKENS := {
	"{use}": &"interact",
	"{back}": &"back",
	"{journal}": &"journal",
	"{goals}": &"goals",
}


## Keys no action may take: they belong to the fixed ones.
static func reserved(k: Key) -> bool:
	for a: StringName in FIXED_KEYS:
		if k in FIXED_KEYS[a]:
			return true
	return false


## Every action, its keys and buttons, into the InputMap. Keys already there are
## replaced (a moved key), buttons and axes are added once.
static func setup(binds: Dictionary) -> void:
	var actions: Array[StringName] = []
	for d: Dictionary in [DEFAULT_KEYS, FIXED_KEYS, PAD_BUTTONS, PAD_AXES]:
		for a: StringName in d:
			if a not in actions:
				actions.append(a)
	for a in actions:
		if not InputMap.has_action(a):
			InputMap.add_action(a, DEADZONE)
			for b: JoyButton in PAD_BUTTONS.get(a, []):
				var jb := InputEventJoypadButton.new()
				jb.button_index = b
				InputMap.action_add_event(a, jb)
			if PAD_AXES.has(a):
				var jm := InputEventJoypadMotion.new()
				jm.axis = PAD_AXES[a][0]
				jm.axis_value = PAD_AXES[a][1]
				InputMap.action_add_event(a, jm)
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey:
				InputMap.action_erase_event(a, ev)
		var keys: Array = []
		if DEFAULT_KEYS.has(a):
			keys.append(binds.get(a, DEFAULT_KEYS[a]))
		keys.append_array(FIXED_KEYS.get(a, []))
		for k: Key in keys:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)
	# Menus (the pause menu's buttons and sliders) are walked with the pad.
	for pair: Array in [[&"ui_accept", JOY_BUTTON_A], [&"ui_cancel", JOY_BUTTON_B],
			[&"ui_up", JOY_BUTTON_DPAD_UP], [&"ui_down", JOY_BUTTON_DPAD_DOWN],
			[&"ui_left", JOY_BUTTON_DPAD_LEFT], [&"ui_right", JOY_BUTTON_DPAD_RIGHT]]:
		var has_button := InputMap.action_get_events(pair[0]).any(func(e: InputEvent) -> bool:
			return e is InputEventJoypadButton and e.button_index == pair[1])
		if not has_button:
			var jb := InputEventJoypadButton.new()
			jb.button_index = pair[1]
			InputMap.action_add_event(pair[0], jb)
	for pair: Array in [[&"ui_up", JOY_AXIS_LEFT_Y, -1.0], [&"ui_down", JOY_AXIS_LEFT_Y, 1.0],
			[&"ui_left", JOY_AXIS_LEFT_X, -1.0], [&"ui_right", JOY_AXIS_LEFT_X, 1.0]]:
		var has := InputMap.action_get_events(pair[0]).any(func(e: InputEvent) -> bool:
			return e is InputEventJoypadMotion and e.axis == pair[1] and signf(e.axis_value) == pair[2])
		if not has:
			var jm := InputEventJoypadMotion.new()
			jm.axis = pair[1]
			jm.axis_value = pair[2]
			InputMap.action_add_event(pair[0], jm)


## binds with `action` on key k. A key another action holds is swapped with it
## (the other gets this one's old key), so no key ever does two things and none
## is lost. A fixed key is refused: binds comes back unchanged.
static func rebind(binds: Dictionary, action: StringName, k: Key) -> Dictionary:
	if not DEFAULT_KEYS.has(action) or reserved(k):
		return binds
	var out := binds.duplicate()
	var old: Key = out.get(action, DEFAULT_KEYS[action])
	for a: StringName in DEFAULT_KEYS:
		if a != action and int(out.get(a, DEFAULT_KEYS[a])) == k:
			out[a] = old
	out[action] = k
	return out


## The key cap as this keyboard prints it: Z on AZERTY where QWERTY has W. A
## layout that does not print Latin there (ЙЦУКЕН) keeps the Latin name, which
## is what the cap shows beside the Cyrillic.
static func key_name(k: Key) -> String:
	if KEY_NAMES.has(k):
		return KEY_NAMES[k]
	var shown := k
	if DisplayServer.get_name() != "headless":
		var local := DisplayServer.keyboard_get_keycode_from_physical(k)
		if local >= KEY_A and local <= KEY_Z:
			shown = local
	return OS.get_keycode_string(shown).to_upper()


## The name of what to press for an action: its key, or its pad button.
static func label(action: StringName, binds: Dictionary, pad: bool) -> String:
	if pad:
		return PAD_NAMES.get(action, "?")
	if DEFAULT_KEYS.has(action):
		return key_name(binds.get(action, DEFAULT_KEYS[action]))
	return key_name(FIXED_KEYS[action][0])


## The four walking keys as one cap: "WASD" when each is a letter, else spaced.
static func move_label(binds: Dictionary, pad: bool) -> String:
	if pad:
		return PAD_NAMES[&"move"]
	var parts: Array[String] = []
	var one := true
	for a: StringName in [&"move_forward", &"move_left", &"move_back", &"move_right"]:
		var n := label(a, binds, false)
		parts.append(n)
		one = one and n.length() == 1
	return "".join(parts) if one else " ".join(parts)


## A text with its {placeholders} filled for this device and these keys.
static func fill(text: String, binds: Dictionary = Game.key_binds, pad: bool = Game.pad) -> String:
	for token: String in TOKENS:
		if token in text:
			text = text.replace(token, label(TOKENS[token], binds, pad))
	return text


## Shows translation key `key` on the label, filled, and keeps it filled when
## the language, the keys or the device change. Calling it again only swaps
## the key.
static func bind(l: Label, key: String) -> void:
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.set_meta(&"keys_text", key)
	l.text = fill(TranslationServer.translate(key))
	if l.has_meta(&"keys_bound"):
		return
	l.set_meta(&"keys_bound", true)
	# a weak hold: the label may be freed long before Game, and a lambda holding
	# a freed object errors on every call
	var w: WeakRef = weakref(l)
	var refresh := func() -> void:
		var lab: Label = w.get_ref()
		if lab != null:
			lab.text = fill(TranslationServer.translate(String(lab.get_meta(&"keys_text"))))
	Game.settings_changed.connect(refresh)
	Game.device_changed.connect(refresh)
