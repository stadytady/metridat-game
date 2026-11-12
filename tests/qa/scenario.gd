extends RefCounted
## A QA scenario: the state the game is put in (fixture()) and what the bot does
## there and checks (run()). One scenario runs per process, on the real world
## and real physics, so it starts clean and a crash takes only itself down.
##   godot --headless --path . --fixed-fps 60 -- --qa=<name> [--qa-out=DIR]
## The bot moves through the walkthrough's own steps (Director), so a scenario
## walks, looks and presses E exactly as the full pass does.
##
## fixture() keys, all optional:
##   found: Array of find ids, or an int (the first n along the route)
##   quests: {id: Quests state}   talked: {npc_id: true}   talks: {npc_id: n}
##   lamps: "all", "none" or an int (the first n lamps)
##   hour: the time of day (0..1, DayCycle), else it follows the finds
##   at: Vector2 (x, z) where the player stands, on Topo.surface
##   look: Vector3 the player looks at        pad: true to hold the gamepad
##   lang: "en" / "ru" (not saved)            timeout: seconds (default 120)

## The runner (tests/qa/qa_runner.gd): it owns the world, the log and the clock.
var runner: Node
var failures := PackedStringArray()


func fixture() -> Dictionary:
	return {}


func run() -> void:
	pass


func main() -> Node:
	return runner.get_parent()


func player() -> CharacterBody3D:
	return main().player()


func tree() -> SceneTree:
	return runner.get_tree()


## Starts a named step: the report times each step and files failures under it.
func step(label: String) -> void:
	runner.begin_step(label)


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
		runner.note_failure(msg)


func frames(n: int) -> void:
	for i in n:
		await tree().process_frame


func seconds(t: float) -> void:
	var left := t
	while left > 0.0:
		await tree().physics_frame
		left -= 1.0 / Engine.physics_ticks_per_second


## Walks to (x, z) like the walkthrough bot; false if stuck.
func walk_to(p: Vector2) -> bool:
	var ok: bool = await runner.bot._walk_to(player(), p)
	player().bot_move = Vector2.ZERO
	_drain()
	return ok


func inspect(id: String) -> void:
	await runner.bot._inspect(player(), runner.bot._inspectables(), id)
	_drain()


func talk(npc_id: String, choice := "", min_lines := 1) -> void:
	await runner.bot._talk(player(), npc_id, choice, min_lines)
	_drain()


func take(quest: String) -> void:
	await runner.bot._errand_talk(player(), "take", quest)
	_drain()


func give(quest: String) -> void:
	await runner.bot._errand_talk(player(), "give", quest)
	_drain()


func pick(quest: String) -> void:
	await runner.bot._pick(player(), quest)
	_drain()


func npc(id: String) -> Npc:
	for n in tree().get_nodes_in_group(&"npc"):
		if n.npc_id == id:
			return n
	return null


## Presses an action for a few physics frames, as a key held and let go.
func press(action: StringName, hold := 2) -> void:
	Input.action_press(action)
	for i in hold:
		await tree().physics_frame
	Input.action_release(action)
	await tree().process_frame


## A real gamepad button event, down and up, through the input pipeline: what
## Game hears to switch the texts to the pad, and what the actions see.
func pad_button(b: JoyButton, hold := 2) -> void:
	for down: bool in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = b
		ev.pressed = down
		Input.parse_input_event(ev)
		for i in (hold if down else 1):
			await tree().process_frame


## A frame of the game into the report (skipped on the headless renderer).
func shot(name: String) -> void:
	await runner.shot(name)


## The walkthrough's failures since the last call become this scenario's.
func _drain() -> void:
	for f in runner.bot._fail:
		check(false, f)
	runner.bot._fail.clear()
