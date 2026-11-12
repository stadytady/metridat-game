extends Node
## Automation, started by user args after "--":
##   --shots [--out=DIR] [--only=a,b] [--lang=ru] [--time=0..1] [--lamps]   save a PNG per viewpoint of World.viewpoints()
##                                      (the final composited frame: world + post + UI)
##   --clip=VIEW [--seconds=N]          hold a viewpoint for N s (record with --write-movie)
##   --walkthrough                       a bot walks the whole route with real physics,
##                                      inspects every discovery, exercises pause; exit 1 on failure
## Run the walkthrough with --fixed-fps 60 so it is not bound to wall-clock time.

var _out := "user://shots"
var _only: PackedStringArray = []
## A single shot from anywhere: "--at=x,z" and "--yaw=degrees".
var _at := ""
var _at_yaw := 0.0
var _at_name := ""
var _at_pitch := 0.0
## Where the wall's relay stands in the watch shots: the fourth and fifth posts
## have their torches up (WallWatch.calls), the tower in "watch_roof" among them.
const WATCH_SHOT_CLOCK := 10.9


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--only="):
			_only = a.substr(7).split(",")
		elif a.begins_with("--time="):
			Game.time_override = a.substr(7).to_float()
		elif a.begins_with("--lang="):
			# Not Game.set_language(): automation must not overwrite saved settings.
			Game.language = a.substr(7)
			TranslationServer.set_locale(Game.language)
		elif a.begins_with("--at="):
			# A shot from anywhere: --at=x,z looks along --yaw (degrees, 0 = -z).
			_at = a.substr(5)
		elif a.begins_with("--yaw="):
			_at_yaw = a.substr(6).to_float()
		elif a.begins_with("--name="):
			_at_name = a.substr(7)
		elif a.begins_with("--pitch="):
			# degrees below the horizon, for things on the ground close by
			_at_pitch = a.substr(8).to_float()
	if "--shots" in OS.get_cmdline_user_args():
		_shots.call_deferred()
	elif "--walkthrough" in OS.get_cmdline_user_args():
		_walkthrough.call_deferred()
	else:
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--clip="):
				_clip.call_deferred(a.substr(7))


func _main() -> Node:
	return get_parent()


func _shots() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	var player: CharacterBody3D = _main().player()
	player.set_physics_process(false)
	if "--lamps" in OS.get_cmdline_user_args():
		for lamp: Lamp in Game.lamps:
			lamp.interact()
	await _frames(10)
	# A one-off look from anywhere, so a new prop can be checked without editing
	# World.viewpoints() first: --at=x,z --yaw=deg [--name=look].
	if _at != "":
		await _shot_at(player)
		get_tree().quit()  # otherwise shots.sh waits on a window nobody closes
		return
	var vps: Dictionary = _main().world.viewpoints()
	for name: String in vps:
		if not _only.is_empty() and name not in _only:
			continue
		var eye: Vector3 = vps[name][0]
		# the last place's name is still fading in the corner: put it out
		_main().get_node("HUD").clear_toast()
		player.global_position = eye - Vector3(0, 1.6, 0)
		player.look_at_point(vps[name][1])
		player.camera.position.y = 0.0
		if name.begins_with("watch"):
			# mid-relay, so the night shots show torches going up along the wall
			var watch: WallWatch = _main().world.find_child("WallWatch", true, false)
			if watch != null and watch.lit:
				watch.clock = WATCH_SHOT_CLOCK
		await _frames(8)
		var img := get_viewport().get_texture().get_image()
		var path := _out.path_join("%s.png" % name)
		img.save_png(path)
		print("shot ", path)
	if _only.is_empty() or "ui" in _only:
		await _ui_shots(player)
	if _only.is_empty() or "finds" in _only:
		await _find_shots()
	if _only.is_empty() or "end" in _only:
		await _end_shot()
	# the prologue's voyage in; only on request, it changes the hour and the game state
	if "voyage" in _only:
		await _voyage_shots()
	# the knucklebones table: bones in the air, then lying with the sums in
	if "astragal" in _only:
		await _astragal_shots()
	# the people of the back streets, one frame each from in front of them
	if "smoke" in _only:
		await _smoke_shots(player)
	if "lanefolk" in _only:
		await _lanefolk_shots(player)
	_report_perf()
	get_tree().quit()


const BACKDROP := preload("res://scripts/world/backdrop.gd")


## Each person in the back streets (Backdrop) from a few steps in front, a
## little above, so a pose that sinks into a wall or floats over a step shows.
func _lanefolk_shots(player: CharacterBody3D) -> void:
	var bd: Node = _main().world.find_child("Backdrop", true, false)
	if bd == null:
		return
	for n: Npc in bd.find_children("*", "Npc", true, false):
		if not n.visible:
			continue
		var front := Vector3(-sin(n.rotation.y), 0, -cos(n.rotation.y))
		var houses: Array = BACKDROP.plan()
		var shot := 0
		for side: float in [0.0, 0.7, -0.7, 1.4, -1.4]:
			if shot >= 2:
				break
			var dir := front.rotated(Vector3.UP, side)
			var eye := n.global_position + dir * 2.4 + Vector3(0, 1.3, 0)
			# not from inside a house: the walls are culled from within
			if BACKDROP.on_house(houses, eye.x, eye.z, 0.4):
				continue
			shot += 1
			player.global_position = eye - Vector3(0, 1.6, 0)
			player.look_at_point(n.global_position + Vector3(0, 0.6 * n.figure_scale, 0))
			player.camera.position.y = 0.0
			await _frames(6)
			_save("lane_%s_%d" % [n.name, shot])


## One plume of each smoke kind over the roofs, from the air beside it, so the
## three can be told apart (--only=smoke).
func _smoke_shots(player: CharacterBody3D) -> void:
	var bd: Node = _main().world.find_child("Backdrop", true, false)
	if bd == null:
		return
	var done := {}
	for s: GPUParticles3D in bd._smoke:
		var kind := String(s.get_meta(&"kind", ""))
		if done.has(kind):
			continue
		done[kind] = true
		var at := s.global_position + Vector3(0, 1.4, 0)
		var eye := at + Vector3(6.5, 1.0, 6.5)
		player.global_position = eye - Vector3(0, 1.6, 0)
		player.look_at_point(at)
		player.camera.position.y = 0.0
		await _frames(150)  # let the plume fill out
		_save("smoke_%s" % kind)


## The knucklebones table mid-throw and after the bones have come to rest.
func _astragal_shots() -> void:
	var p: CanvasLayer = load("res://scripts/ui/astragal_panel.gd").new()
	_main().add_child(p)
	p.open()
	p._armed = true
	await _frames(5)
	p._key(true, true)
	# drive the table's clock by hand: the shots run at whatever speed lavapipe manages
	p._table._t = 0.0
	for pair: Array in [[0.32, "astragal_fly"], [1.45, "astragal_children"]]:
		p._table._t = float(pair[0]) - 1.0 / 60.0
		p._table._process(1.0 / 60.0)
		p._table.set_process(false)
		await _frames(4)
		_save(pair[1])
		p._table.set_process(true)
	while p.throwing():
		p._table._process(0.05)
		await get_tree().process_frame
	await _frames(4)
	_save("astragal_done")
	p.close()


## The voyage in at a few moments of it, and the cut to the pier.
func _voyage_shots() -> void:
	var p := Prologue.new()
	p.name = "Prologue"
	_main().add_child(p)
	p.begin()
	await _frames(30)
	for t: float in [2.5, 8.0, 13.5, 16.0, 20.0, 23.0]:
		p._voyage_t = t
		p._follow()
		await _frames(8)
		_save("voyage_%02d" % int(t))
	p.skip()
	await p.landed
	await _frames(8)
	_save("voyage_pier")
	# the night after the talk: the stern at night and at dawn, then the climb
	var panel: Node = _main().get_node("DialoguePanel")
	await _frames(30)
	panel.close()
	while p.stage != "night":
		await get_tree().process_frame
	await get_tree().create_timer(Prologue.DARK + 1.2).timeout
	_save("night_stern")
	while p.stage != "dawn":
		await get_tree().process_frame
	await get_tree().create_timer(Prologue.DARK + 1.2).timeout
	_save("night_dawn")
	while p.stage != "climb":
		await get_tree().process_frame
	for at: float in [0.03, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.88, 0.94, 0.98]:
		while p.climb_u < at and p.stage == "climb":
			await get_tree().process_frame
		_save("night_climb_%02d" % int(at * 100.0))
		print("climb %.2f at %s" % [at, p._cam.global_position])
	await p.finished
	await _frames(8)
	_save("night_hill")


## Prompt, info panel and pause menu over the agora.
## One frame from an arbitrary spot: eye at ground + 1.6 m, looking along yaw.
func _shot_at(player: CharacterBody3D) -> void:
	var bits := _at.split(",")
	var x := bits[0].to_float()
	var z := bits[1].to_float() if bits.size() > 1 else 0.0
	var eye := Vector3(x, Topo.surface(x, z) + 1.6, z)
	player.global_position = eye - Vector3(0, 1.6, 0)
	var yaw := deg_to_rad(_at_yaw)
	player.look_at_point(eye + Vector3(-sin(yaw), -tan(deg_to_rad(_at_pitch)), -cos(yaw)) * 14.0)
	player.camera.position.y = 0.0
	await _frames(10)
	var name := _at_name if _at_name != "" else "at_%d_%d" % [roundi(x), roundi(z)]
	var img := get_viewport().get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	print("shot ", _out.path_join(name + ".png"))


func _ui_shots(player: CharacterBody3D) -> void:
	var hud: Node = _main().get_node("HUD")
	hud.set_visible_ui(false)
	var title := _open_title()
	await _frames(10)
	_save("ui_title")
	title.start()
	title.queue_free()
	hud.set_visible_ui(true)
	var stele: Node3D = _inspectables().get("inscription_stele")
	player.global_position = Vector3(22.0, Topo.AGORA_H, -0.9)
	player.look_at_point(stele.global_position + Vector3(0, 1.1, 0))
	player.camera.position.y = 0.0
	player.set_physics_process(true)
	player.bot_enabled = true
	await _frames(12)
	_save("ui_prompt")
	player.interactor.try_interact()
	await _frames(6)
	_save("ui_info")
	_main().get_node("InfoPanel").close()
	var potter: Npc = get_tree().get_nodes_in_group(&"npc").filter(func(n: Node) -> bool: return n.npc_id == "potter").front()
	if potter:
		player.global_position = Vector3(13.4, Topo.AGORA_H, 7.0)
		player.look_at_point(potter.global_position + Vector3(0, 0.9, 0))
		await _frames(6)
		player.interactor.try_interact()
		var dlg: Node = _main().get_node("DialoguePanel")
		dlg.advance()
		await _frames(6)
		_save("ui_dialogue")
		dlg.close()
	var jrn: Node = _main().get_node("JournalPanel")
	jrn.open()
	await _frames(6)
	_save("ui_journal")
	jrn.close()
	var pause: Node = _main().get_node("PauseMenu")
	pause.open()
	await _frames(6)
	_save("ui_pause")
	pause.show_keys()
	await _frames(6)
	_save("ui_controls")
	# the same page and the dialogue hint as a pad player sees them
	Game.set_pad(true)
	pause.show_keys()
	await _frames(6)
	_save("ui_controls_pad")
	Game.set_pad(false)
	pause.close()


## THE END over black (the dream's last screen), for a look at it.
func _end_shot() -> void:
	var end: CanvasLayer = load("res://scripts/ui/end_screen.gd").new()
	_main().add_child(end)
	end.play()
	end.skip_to_keys()
	await _frames(6)
	_save("ui_end")
	end.queue_free()


## The info panel with its viewer for every find, to look at each model large.
func _find_shots() -> void:
	var info: Node = _main().get_node("InfoPanel")
	for d: Discovery in Game.registry.values():  # all of them, the dream's too
		info.show_discovery(d)
		await _frames(12)
		_save("find_%s" % d.id)
		info.close()
		await _frames(2)


func _save(name: String) -> void:
	var path := _out.path_join("%s.png" % name)
	get_viewport().get_texture().get_image().save_png(path)
	print("shot ", path)


func _clip(view: String) -> void:
	var seconds := 4.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seconds="):
			seconds = a.substr(10).to_float()
	var player: CharacterBody3D = _main().player()
	player.set_physics_process(false)
	_main().get_node("HUD").visible = false
	var vp: Array = _main().world.viewpoints()[view]
	player.global_position = vp[0] - Vector3(0, 1.6, 0)
	player.look_at_point(vp[1])
	player.camera.position.y = 0.0
	await get_tree().create_timer(seconds).timeout
	get_tree().quit()


func _report_perf() -> void:
	print("perf draw_calls=%d primitives=%d objects=%d video_mem_mb=%.1f" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
	])


# ---------------------------------------------------------------- walkthrough

const STUCK_SECONDS := 4.0
## Set once all finds are made: from then on the bot lights every lamp it passes.
var _lighting := false
var _fail := PackedStringArray()
var _qa_log: Object
var _qa_out := ""
var _qa_t0 := 0


func _inspectables() -> Dictionary:
	var out := {}
	for n in get_tree().get_nodes_in_group(&"inspectable"):
		out[String(n.discovery.id)] = n
	return out


## Route: Vector2 = walk to (x, z); String = inspect that discovery from here.
func _route() -> Array:
	var r: Array = []
	var c := Topo.HILL_CENTER
	# the actor rehearsing in the theatre, a few steps from the start
	r.append(Vector2(-88.4, -0.8))
	r.append("talk:actor")
	# out through the north gate into the park, to the marble head by the walk
	r.append(Vector2(-86.0, 6.6))
	r.append(Vector2(-86.0, 10.4))
	r.append("goddess_head")
	# down the gate walk onto the long walk, and west along it to the goddess who
	# closes it: the terracotta at her plinth is the reason to walk the park
	r.append(Vector2(-86.0, 19.0))
	r.append(Vector2(-94.6, 19.0))
	r.append(Vector2(-96.2, 19.6))
	r.append("goddess_votive")
	r.append(Vector2(-86.0, 19.0))
	r.append(Vector2(-86.0, 6.6))
	r.append(Vector2(c.x + 3.0, -4.6))
	r.append("sherd_kerch")
	r.append(Vector2(c.x + Topo.HILL_HALF.x - 1.0, 0.0))
	var items := _inspectables()
	var amph: Node3D = items.get("amphora_stamped")
	for i in range(0, Topo.STREET.size()):
		var p := Topo.STREET[i]
		if amph and p.x > amph.global_position.x and r.find("amphora_stamped") == -1:
			var ax := amph.global_position.x
			r.append(Vector2(ax, Topo.street_z(ax)))
			var toward := Vector2(amph.global_position.x, amph.global_position.z)
			var from := Vector2(ax, Topo.street_z(ax))
			r.append(toward + (from - toward).normalized() * 1.4)
			r.append("amphora_stamped")
			r.append(from)
		r.append(Vector2(p.x, p.z))
	# Agathe at the well asks after the lamp her boy left on the grass by it.
	# She stops for anyone within Npc.ATTENTION, wherever her round has taken
	# her, behind the well-head too: wait out of her sight until she is back at
	# the rope, then step up from the lane.
	# Sosias the coin striker, in his room uphill of the mule's pen: up his
	# steps, in at the door, a word over the anvil, and back to the street.
	r.append(Vector2(-1.0, 2.6))
	r.append(Vector2(-1.0, 6.0))
	r.append("talk:striker")
	r.append(Vector2(-1.0, 2.6))
	r.append(Vector2(12.5, 0.0))
	r.append("await:water_carrier:0")
	r.append(Vector2(5.0, -0.6))
	r.append("talk:water_carrier")
	r.append("take:lamp")
	r.append(Vector2(3.8, -1.7))
	r.append("pick:lamp")
	r.append("give:lamp")
	r.append(Vector2(9.0, 0.0))
	r.append(Vector2(22.0, -0.9))
	r.append("inscription_stele")
	r.append(Vector2(20.4, 4.7))
	r.append("coin_stater")
	r.append(Vector2(24.3, 5.7))
	r.append("grain_pithos")
	# potter's workshop in the south-west corner, around the stall. The boy is
	# on his round between the wheel, the woodpile and the kiln, and stops
	# wherever he is for anyone within Npc.ATTENTION: wait out of his sight
	# until he is back at the wheel, or the bot has to reach him behind the kiln.
	r.append(Vector2(25.5, 4.0))
	r.append("await:turner:0")
	r.append(Vector2(22.0, 4.5))
	r.append(Vector2(13.4, 4.8))
	r.append(Vector2(13.4, 7.0))
	r.append("talk:potter")
	r.append("talk:turner")
	r.append("take:astragal")
	r.append("check:chickens")
	r.append(Vector2(11.6, 7.7))
	r.append("mould_figurine")
	r.append(Vector2(12.5, 4.5))
	# the boy's knucklebone on the stoa's step, and back to him with it
	r.append(Vector2(14.5, -3.9))
	r.append("pick:astragal")
	r.append("await:turner:0")
	r.append(Vector2(12.5, 4.5))
	r.append("give:astragal")
	# across the square well south of the stall: its counter is the one place the
	# bot still catches a shoulder on when the timing shifts by a few seconds
	r.append(Vector2(16.2, 2.6))
	r.append(Vector2(20.0, 2.4))
	r.append(Vector2(30.0, 3.0))
	# down the footpath to Myrto's house: talk at the oven, look into both rooms
	r.append(Vector2(26.0, 9.6))
	r.append(Vector2(26.0, 17.4))
	r.append(Vector2(27.3, 18.2))
	r.append("talk:baker")
	r.append("take:loom_weight")
	# the cut block in the yard, its mason's mark still on the corner
	r.append(Vector2(24.6, 17.8))
	r.append("mason_mark")
	r.append(Vector2(27.3, 18.2))
	for door: float in [22.9, 29.1]:
		r.append(Vector2(door, 20.7))
		r.append(Vector2(door, 23.4))
		# the lamp on the stool by the hearth, the weights at the foot of the loom
		if door < 26.0:
			r.append(Vector2(23.7, 23.2))
			r.append("oil_lamp")
		else:
			r.append("loom_weights")
		r.append(Vector2(door, 20.7))
	# the loom weight out by the street door, back to Myrto at the oven
	r.append(Vector2(26.3, 15.9))
	r.append("pick:loom_weight")
	r.append(Vector2(27.3, 18.2))
	r.append("give:loom_weight")
	r.append(Vector2(26.0, 17.4))
	r.append(Vector2(26.0, 9.6))
	r.append(Vector2(30.0, 3.0))
	r.append(Vector2(34.0, -2.0))
	# out through the gap in the east parapet, down to the fisherman's camp and back
	r.append(Vector2(36.5, -7.0))
	r.append(Vector2(56.0, 6.0))
	r.append(Vector2(63.6, 14.4))
	r.append("talk:fisher")
	r.append("take:hook")
	r.append(Vector2(64.6, 13.0))
	r.append("net_sinkers")
	# the hook behind his boat, on the sea side: round the board and the fire,
	# along the boat, and back to Glaukos
	r.append(Vector2(64.3, 15.6))
	r.append(Vector2(66.4, 17.7))
	r.append(Vector2(68.4, 18.1))
	r.append("pick:hook")
	r.append(Vector2(66.4, 17.7))
	r.append(Vector2(64.3, 15.6))
	r.append(Vector2(63.6, 14.4))
	r.append("give:hook")
	r.append(Vector2(56.0, 6.0))
	# along the beach to the pier, out to the skipper by the gangway, and back
	var px0 := Topo.pier_x0()
	r.append(Vector2(px0 - 1.0, Topo.PIER_Z))
	# the anchor stock on the planks by the north edge, on the way out
	r.append(Vector2(76.0, Topo.PIER_Z - 0.2))
	r.append("anchor_stock")
	r.append(Vector2(Topo.pier_x1() - 7.0, Topo.PIER_Z - 0.4))
	r.append("talk:sailor")
	r.append(Vector2(px0 - 1.0, Topo.PIER_Z))
	r.append(Vector2(56.0, 6.0))
	r.append(Vector2(36.5, -7.0))
	r.append(Vector2(34.0, -5.5))  # around the torch at the foot of the stair
	r.append(Vector2(34.0, -9.8))
	r.append(Vector2(Topo.SANCT_STAIR[1].x, Topo.SANCT_STAIR[1].z))
	r.append(Vector2(42.0, -21.0))
	r.append(Vector2(51.5, -21.0))
	r.append(Vector2(51.6, -29.0))
	r.append("votive_figurine")
	# Night falls with the last find: light the temple door torches, then walk
	# back up to the hill, lighting lamps.
	r.append(Vector2(49.5, -25.5))
	r.append(Vector2(46.0, -25.0))
	r.append(Vector2(49.5, -25.5))
	r.append(Vector2(51.5, -21.0))
	r.append(Vector2(42.0, -21.0))
	r.append(Vector2(Topo.SANCT_STAIR[1].x, Topo.SANCT_STAIR[1].z))
	r.append(Vector2(34.0, -9.8))
	r.append(Vector2(34.0, -2.0))
	# around the bench and statue base, through the south half of the square
	r.append(Vector2(33.0, 3.5))
	r.append(Vector2(12.5, 3.5))
	r.append(Vector2(Topo.STREET[-1].x, Topo.STREET[-1].z))
	for i in range(Topo.STREET.size() - 1, -1, -1):
		r.append(Vector2(Topo.STREET[i].x, Topo.STREET[i].z))
	r.append(Vector2(Topo.HILL_CENTER.x + Topo.HILL_HALF.x - 3.0, 0.0))
	return r


func _walkthrough() -> void:
	_qa_t0 = Time.get_ticks_msec()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa-out="):
			_qa_out = a.substr(9)
			_qa_log = load("res://tests/qa/qa_log.gd").install()
			_qa_log.context = "walkthrough"
	var main := _main()
	var player: CharacterBody3D = main.player()
	player.bot_enabled = true
	await _frames(5)
	var items := _inspectables()
	print("walkthrough: %d inspectables registered, Game.total()=%d" % [items.size(), Game.total()])
	if items.size() < 5:
		_fail.append("fewer than 5 inspectables")
	await _check_title()
	_check_cicadas()
	await _check_prologue(player)
	await _check_journal(Game.total())
	var min_y := INF
	# per-step timings and failures for the QA report (--qa-out)
	var timeline: Array[Dictionary] = []
	for step in _route():
		var step_t0 := Time.get_ticks_msec()
		var step_fails := _fail.size()
		if Game.found_count() == Game.total():
			_lighting = true
		if step is Vector2:
			var ok := await _walk_to(player, step)
			if not ok:
				break
		elif String(step).begins_with("talk:"):
			await _talk(player, String(step).substr(5))
		elif step == "check:chickens":
			await _check_chickens(player)
		elif String(step).begins_with("take:") or String(step).begins_with("give:"):
			await _errand_talk(player, String(step).substr(0, 4), String(step).substr(5))
		elif String(step).begins_with("await:"):
			var bits := String(step).split(":")
			await _await_at(player, bits[1], int(bits[2]))
		elif String(step).begins_with("pick:"):
			await _pick(player, String(step).substr(5))
		else:
			await _inspect(player, items, step)
		min_y = minf(min_y, player.global_position.y)
		timeline.append({"step": str(step), "ms": Time.get_ticks_msec() - step_t0,
				"failures": Array(_fail.slice(step_fails))})
	player.bot_move = Vector2.ZERO
	if min_y < 0.0:
		_fail.append("player went below sea level (min y %.2f)" % min_y)
	if Game.found_count() != Game.total():
		_fail.append("found %d of %d discoveries" % [Game.found_count(), Game.total()])
	_check_night()
	await _check_journal(0)
	await _check_journal_view()
	await _check_dream(player)
	_check_audio(player)
	await _check_pause()
	await _check_language()
	print("walkthrough: found %d/%d, end at %s" % [Game.found_count(), Game.total(), player.global_position])
	for f in _fail:
		print("FAIL ", f)
	print("WALKTHROUGH ", "PASS" if _fail.is_empty() else "FAIL")
	_write_qa(timeline)
	get_tree().quit(0 if _fail.is_empty() else 1)


## With --qa-out=DIR, the pass as JSON for tools/qa_report.py: every route step
## with its time and failures, the engine's errors, how far it got. tests/ is
## not exported, so the log is loaded by path and only when asked for.
func _write_qa(timeline: Array[Dictionary]) -> void:
	if _qa_log == null:
		return
	var qa: GDScript = load("res://tests/qa/qa_log.gd")
	var errors: Array = _qa_log.records()
	var script_errors := errors.filter(func(r: Dictionary) -> bool: return r.type == "script").size()
	qa.write_json(_qa_out.path_join("walkthrough.json"), {
		"kind": "walkthrough", "status": "ok" if _fail.is_empty() and script_errors == 0 else "fail",
		"ms": Time.get_ticks_msec() - _qa_t0, "failures": Array(_fail), "steps": timeline, "errors": errors,
		"found": Game.found_count(), "total": Game.total(), "lamps": Game.lamps_lit(), "lamps_total": Game.lamps.size(),
	})


func _walk_to(player: CharacterBody3D, target: Vector2) -> bool:
	var last := Vector2(player.global_position.x, player.global_position.z)
	var still := 0.0
	var elapsed := 0.0
	while true:
		var pos := Vector2(player.global_position.x, player.global_position.z)
		if pos.distance_to(target) < 0.6:
			return true
		if _lighting:
			await _light_nearby(player)
		player.look_at_point(Vector3(target.x, player.camera.global_position.y, target.y))
		player.bot_move = Vector2(0, -1)
		await get_tree().physics_frame
		var dt := 1.0 / Engine.physics_ticks_per_second
		elapsed += dt
		still = still + dt if pos.distance_to(last) < 0.02 else 0.0
		last = pos
		if still > STUCK_SECONDS or elapsed > 90.0:
			var hits := PackedStringArray()
			for i in player.get_slide_collision_count():
				var c := player.get_slide_collision(i)
				hits.append("%s n=%s at %s" % [(c.get_collider() as Node).get_path(), c.get_normal().snapped(Vector3.ONE * 0.01),
						c.get_position().snapped(Vector3.ONE * 0.01)])
			_fail.append("stuck walking to %s at %s; touching: %s" % [target, player.global_position, ", ".join(hits)])
			player.bot_move = Vector2.ZERO
			return false
	return false


func _inspect(player: CharacterBody3D, items: Dictionary, id: String) -> void:
	player.bot_move = Vector2.ZERO
	await _frames(10)
	var item: Node3D = items.get(id)
	if item == null:
		_fail.append("no inspectable " + id)
		return
	var box: Vector3 = item.box_size
	player.look_at_point(item.global_position + Vector3(0, box.y * 0.5, 0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var before := Game.found_count()
	if not player.interactor.try_interact():
		_fail.append("ray does not hit %s from %s (dist %.2f)" % [id, player.global_position,
				player.camera.global_position.distance_to(item.global_position)])
		return
	await _frames(3)
	var info: Node = _main().get_node("InfoPanel")
	if not info.is_open() or not Game.ui_blocking:
		_fail.append("info panel did not open for " + id)
	var screen := Rect2(Vector2.ZERO, Vector2(1920, 1080))
	if not screen.encloses(info._panel.get_global_rect()):
		_fail.append("info panel off screen for %s: %s" % [id, info._panel.get_global_rect()])
	await _frames(2)
	_check_viewer(info, id)
	if Game.found_count() != before + 1:
		_fail.append("counter did not advance for " + id)
	print("inspected %s (%d/%d)" % [id, Game.found_count(), Game.total()])
	info.close()
	# Regression: E pressed right after closing, still looking at the find,
	# must not open it again (the player got stuck on finds).
	Input.action_press(&"interact")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"interact")
	await _frames(3)
	if info.is_open():
		_fail.append("E right after closing reopened %s" % id)
		info.close()
		await _frames(3)


## Talks to an NPC through the interactor ray and reads every line.
func _talk(player: CharacterBody3D, npc_id: String, choice: String = "", min_lines: int = 3) -> void:
	player.bot_move = Vector2.ZERO
	await _frames(5)
	var npc: Npc = null
	for n in get_tree().get_nodes_in_group(&"npc"):
		if n.npc_id == npc_id:
			npc = n
	if npc == null:
		_fail.append("no npc " + npc_id)
		return
	if npc.marker == null or not npc.marker.visible:
		_fail.append("no talk marker over " + npc_id)
	# a walking NPC (Fedr in the orchestra) is wherever his round has taken
	# him: step up to him, as a player would; he stops for the player
	var to := Vector2(npc.global_position.x - player.global_position.x, npc.global_position.z - player.global_position.z)
	if not npc.patrol.is_empty() and to.length() > 2.0:
		await _walk_to(player, Vector2(npc.global_position.x, npc.global_position.z) - to.normalized() * 1.6)
		player.bot_move = Vector2.ZERO
		await _frames(5)
	player.look_at_point(npc.global_position + Vector3(0, 0.9, 0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not player.interactor.try_interact():
		_fail.append("ray does not hit npc %s from %s" % [npc_id, player.global_position])
		return
	await _frames(3)
	var panel: Node = _main().get_node("DialoguePanel")
	if not panel.is_open():
		_fail.append("dialogue did not open for " + npc_id)
		return
	if npc.marker != null and npc.marker.visible:
		_fail.append("talk marker still shown during the talk with " + npc_id)
	var shown := 0
	var chose := choice == ""
	while panel.is_open() and shown < 20:
		shown += 1
		if not chose and panel.choose(choice):
			chose = true
		var text: String = panel._line.text
		if text.begins_with("NPC_") or text.begins_with("LOC_"):
			_fail.append("untranslated line %s" % text)
		panel.advance()
		await _frames(2)
	# A branching talk has no fixed length; reaching the end of one branch is enough.
	if not chose:
		_fail.append("talk with %s: no choice %s" % [npc_id, choice])
	if not Game.talked.get(npc_id, false) or shown < min_lines:
		_fail.append("talk with %s: %d lines, expected at least %d" % [npc_id, shown, min_lines])
	print("talked to %s (%d lines)" % [npc_id, shown])


## An errand's talk: "take" asks for it through its choice, "give" brings the
## thing back, which the giver thanks for before anything else.
func _errand_talk(player: CharacterBody3D, step: String, quest: String) -> void:
	var giver := String(Quests.LIST[quest]["giver"])
	var want := Quests.TAKEN if step == "take" else Quests.DONE
	if step == "take":
		await _talk(player, giver, String(Quests.LIST[quest]["ask"]), 2)
	else:
		await _talk(player, giver, "", 1)
	if Game.quest_state(quest) != want:
		_fail.append("errand %s after %s: state %d, expected %d" % [quest, step, Game.quest_state(quest), want])
	print("errand %s: %s" % [quest, step])


## Waits, up to a minute, for a walking NPC to reach a point of its round.
func _await_at(player: CharacterBody3D, npc_id: String, i: int) -> void:
	player.bot_move = Vector2.ZERO
	var npc: Npc = null
	for n in get_tree().get_nodes_in_group(&"npc"):
		if n.npc_id == npc_id:
			npc = n
	if npc == null:
		_fail.append("no npc " + npc_id)
		return
	var spot: Vector3 = npc._home + npc.patrol[i]
	var t := 0.0
	while t < 60.0 and Vector2(npc.position.x - spot.x, npc.position.z - spot.z).length() > 0.1:
		t += get_physics_process_delta_time()
		await get_tree().physics_frame
	if t >= 60.0:
		_fail.append("%s never came back to point %d of the round" % [npc_id, i])
	print("waited %.1f s for %s" % [t, npc_id])


## Picks a taken errand's thing off the ground: shown only now, gone after.
func _pick(player: CharacterBody3D, quest: String) -> void:
	player.bot_move = Vector2.ZERO
	await _frames(10)
	var item: QuestItem = null
	for n in get_tree().get_nodes_in_group(&"quest_item"):
		if n.quest == quest:
			item = n
	if item == null:
		_fail.append("no quest item " + quest)
		return
	if not item.visible:
		_fail.append("quest item %s hidden while the errand is taken" % quest)
	player.look_at_point(item.global_position + Vector3(0, item.box_size.y * 0.5, 0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not player.interactor.try_interact():
		var hit: Object = player.interactor.get_collider()
		_fail.append("ray does not hit quest item %s from %s (dist %.2f, hits %s)" % [quest, player.global_position,
				player.camera.global_position.distance_to(item.global_position),
				hit.get_path() if hit is Node else "nothing"])
		return
	await _frames(3)
	if Game.quest_state(quest) != Quests.FOUND or item.visible:
		_fail.append("quest item %s: state %d, visible %s after picking" % [quest, Game.quest_state(quest), item.visible])
	print("picked up %s" % quest)


## The viewer must hold the find's model, with real geometry, and render.
func _check_viewer(info: Node, id: String) -> void:
	var v: ItemViewer = info.viewer
	var box: AABB = v.shown_aabb()
	if box.size.length() < 0.02:
		_fail.append("viewer empty for %s: %s" % [id, box])
	if not v.is_visible_in_tree() or (Input.mouse_mode != Input.MOUSE_MODE_VISIBLE and DisplayServer.get_name() != "headless"):
		_fail.append("viewer not shown or cursor not free for %s" % id)


## Opens the journal like pressing J: one row per find, a hint for each one
## not yet found, then closes it.
func _check_journal(expect_hints: int) -> void:
	var j: Node = _main().get_node("JournalPanel")
	j.open()
	await _frames(3)
	var c: Vector2i = j.counts()
	if c.x != Game.total() or c.y != expect_hints:
		_fail.append("journal: %d rows, %d hints; expected %d, %d" % [c.x, c.y, Game.total(), expect_hints])
	if not Rect2(Vector2.ZERO, Vector2(1920, 1080)).encloses(j._panel.get_global_rect()):
		_fail.append("journal off screen: %s" % j._panel.get_global_rect())
	j.close()
	await _frames(2)
	print("journal: %d rows, %d hints" % [c.x, c.y])


## Night in Hecate's sanctuary: lie down on the fleece, walk the dream path
## past the figures (each must vanish), find the mirror on the altar before
## the mound, see THE END, wake in the abaton.
func _check_dream(player: CharacterBody3D) -> void:
	var dream: Node = _main().world.get_node("Dream")
	var spot: SleepSpot = _main().world.find_child("SleepSpot", true, false)
	if spot == null:
		_fail.append("no sleeping place in the abaton")
		return
	player.bot_move = Vector2.ZERO
	player.global_position = spot.global_position + Vector3(1.4, 0.05, 0.0)
	player.look_at_point(spot.global_position + Vector3(0, 0.05, 0))
	await _frames(4)
	if spot.get_prompt() != tr("UI_SLEEP"):
		_fail.append("fleece does not offer sleep with every lamp lit: %s" % spot.get_prompt())
	var abaton := player.global_position
	if not player.interactor.try_interact():
		_fail.append("ray does not hit the fleece")
		return
	await get_tree().create_timer(3.0).timeout
	var env: Environment = _main().world.get_node("Atmosphere").env
	if not Game.dreaming or player.global_position.distance_to(dream.ORIGIN) > 10.0:
		_fail.append("did not enter the dream (dreaming %s, at %s)" % [Game.dreaming, player.global_position])
		return
	if env.fog_depth_end > 80.0:
		_fail.append("dream fog not thick: ends at %.0f m" % env.fog_depth_end)
	if not dream._drone.playing:
		_fail.append("the dream's drone is silent")
	var walked := true
	for z: float in [8.0, 16.0, 24.0, 32.0, 40.0, 48.0, 56.0, 64.0, 71.0, 74.4]:
		var o: Vector3 = dream.ORIGIN
		if not await _walk_to(player, Vector2(o.x + dream.path_x(z), o.z + z)):
			walked = false
			break
	player.bot_move = Vector2.ZERO
	if not walked:
		return
	if dream.howls < 1:
		_fail.append("no howl in the dream")
	if dream.vanished != dream.FIGURES_Z.size():
		_fail.append("figures vanished: %d of %d" % [dream.vanished, dream.FIGURES_Z.size()])
	var mirror: Node3D = _inspectables().get("bronze_mirror")
	player.look_at_point(mirror.global_position + Vector3(0, 0.05, 0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not player.interactor.try_interact():
		_fail.append("ray does not hit the mirror from %s" % player.global_position)
		return
	await _frames(3)
	var info: Node = _main().get_node("InfoPanel")
	if not info.is_open() or not Game.found.has(&"bronze_mirror"):
		_fail.append("mirror panel did not open")
		return
	_check_viewer(info, "bronze_mirror")
	if Game.found_count() != Game.total():
		_fail.append("the mirror changed the city's count: %d/%d" % [Game.found_count(), Game.total()])
	info.close()
	# the mirror opens the mound: the doors creak open, then down the stair
	for i in 60:
		await get_tree().create_timer(0.1).timeout
		if dream.doors_open:
			break
	if _main().get_node_or_null("EndScreen"):
		_fail.append("THE END came at the mirror, before the tomb")
		return
	if not dream.doors_open:
		_fail.append("the mound's doors did not open after the mirror")
		return
	var o2: Vector3 = dream.ORIGIN
	var c: Vector3 = o2 + dream.chamber_center()
	for p: Vector2 in [Vector2(o2.x + 1.8, o2.z + dream.ALTAR.z - 0.6), Vector2(o2.x + 1.8, o2.z + dream.ALTAR.z + 1.2),
			Vector2(o2.x, o2.z + dream.DOOR_Z - 1.2), Vector2(o2.x, o2.z + dream.DOOR_Z + 0.6),
			Vector2(o2.x, o2.z + dream.stair_end() + 0.6), Vector2(c.x - 0.9, c.z - 0.6)]:
		if not await _walk_to(player, p):
			_fail.append("could not walk down into the tomb, stuck near %s" % player.global_position)
			player.bot_move = Vector2.ZERO
			return
	player.bot_move = Vector2.ZERO
	if player.global_position.y > o2.y - dream.DEPTH + 0.5:
		_fail.append("not down in the chamber: at %s" % player.global_position)
	var sleeper: Node3D = dream.sleeper
	player.look_at_point(sleeper.global_position + Vector3(0, 0.7, 0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	if player.interactor.current != sleeper:
		_fail.append("the ray does not find the sleeper from %s: %s" % [player.global_position, player.interactor.current])
		return
	if sleeper.get_prompt() != tr("UI_LEAN"):
		_fail.append("the sleeper does not offer to lean closer: %s" % sleeper.get_prompt())
	player.interactor.try_interact()
	var end: Node = null
	for i in 60:
		await get_tree().create_timer(0.1).timeout
		end = _main().get_node_or_null("EndScreen")
		if end:
			break
	if end == null:
		_fail.append("no THE END after leaning over the sleeper")
		return
	await _frames(3)
	end.skip_to_keys()
	await _frames(2)
	end.woke.emit()
	await get_tree().create_timer(3.0).timeout
	if dream._drone.playing:
		_fail.append("the dream's drone goes on after waking")
	if Game.dreaming or player.global_position.distance_to(abaton) > 1.5:
		_fail.append("did not wake in the abaton (dreaming %s, at %s)" % [Game.dreaming, player.global_position])
	if not Achievements.is_unlocked("ACH_DREAM"):
		_fail.append("the dream did not unlock its achievement")
	print("achievements: %d of %d" % [Achievements.count(), Achievements.LIST.size()])
	if env.fog_depth_end < 300.0:
		_fail.append("night fog did not come back after waking: %.0f m" % env.fog_depth_end)
	var j: Node = _main().get_node("JournalPanel")
	j.open()
	await _frames(2)
	var rows: Vector2i = j.counts()
	j.close()
	await _frames(2)
	if rows.x != Game.total() + 1:
		_fail.append("journal does not list the mirror after the dream: %d rows" % rows.x)
	print("dream: figures %d/%d, mirror found, doors opened, down the stair to the sleeper, woke in the abaton" % [dream.vanished, dream.FIGURES_Z.size()])


## The start screen holds the game until START, then hands it over.
func _check_title() -> void:
	var title: CanvasLayer = _open_title()
	await _frames(3)
	if not title.is_open() or not Game.ui_blocking:
		_fail.append("title screen did not hold the game")
	title.start()
	await _frames(3)
	# The headless display server cannot capture the mouse; check it where it can.
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless"
	if Game.ui_blocking or not captured:
		_fail.append("START did not hand the game over")
	await get_tree().create_timer(0.8).timeout
	if title.is_open():
		_fail.append("title screen did not fade out")
	title.queue_free()
	print("title: start ok")


## The evening before: off the Swallow onto the pier at dusk, a talk with
## Damon that counts for nothing, then dark, MORNING, the hill at the start hour.
func _check_prologue(player: CharacterBody3D) -> void:
	var p := Prologue.new()
	p.name = "Prologue"
	_main().add_child(p)
	p.begin()
	# the voyage in: the Swallow out at sea under her own camera, the legend up
	await get_tree().create_timer(2.0).timeout
	var harbour: Node = get_tree().get_first_node_in_group(&"harbour")
	var ship: Node3D = harbour.ship()
	var moored: Vector3 = harbour.ship_pos()
	if not p.voyage_running():
		_fail.append("prologue: no voyage")
	elif player.get_viewport().get_camera_3d() == player.camera:
		_fail.append("prologue: the voyage is seen through the player's eyes")
	elif Vector2(ship.global_position.x - moored.x, ship.global_position.z - moored.z).length() < 120.0:
		_fail.append("prologue: the Swallow is not out at sea but at %s" % ship.global_position)
	elif p._legend.text != tr("UI_LEGEND_1") or p._legend.modulate.a < 0.5:
		_fail.append("prologue: the legend does not run (%s)" % p._legend.text)
	elif not Game.ui_blocking:
		_fail.append("prologue: the world listens to keys during the voyage")
	var sailed := ship.global_position
	await get_tree().create_timer(1.0).timeout
	if ship.global_position.distance_to(sailed) < 2.0:
		_fail.append("prologue: the Swallow does not move")
	p.skip()  # as a key does
	await p.landed
	if p.voyage_running() or player.get_viewport().get_camera_3d() != player.camera:
		_fail.append("prologue: the skip does not end the voyage")
	if Vector2(ship.global_position.x - moored.x, ship.global_position.z - moored.z).length() > 0.1:
		_fail.append("prologue: the Swallow is not back at the pier but at %s" % ship.global_position)
	print("prologue: voyage in under the legend, %.0f m from the pier when skipped" % sailed.distance_to(moored))
	await get_tree().create_timer(1.0).timeout
	var atm: Node = _main().world.get_node("Atmosphere")
	if not Game.prologue or not is_equal_approx(atm.t, DayCycle.PROLOGUE):
		_fail.append("prologue: not dusk (prologue %s, hour %.2f)" % [Game.prologue, atm.t])
	if not Topo.on_pier(player.global_position.x, player.global_position.z, 0.0):
		_fail.append("prologue: not on the pier but at %s" % player.global_position)
	var panel: Node = _main().get_node("DialoguePanel")
	if not panel.is_open() or panel._name.text != tr("NPC_SAILOR_NAME"):
		_fail.append("prologue: Damon does not speak")
		return
	if panel._line.text != tr("LOC_PRO_1"):
		_fail.append("prologue: the talk does not begin with the arrival: %s" % panel._line.text)
	var shown := 0
	while panel.is_open() and shown < 12:
		shown += 1
		panel.advance()
		await _frames(2)
	if shown < 3:
		_fail.append("prologue: only %d lines" % shown)
	if Game.talked.get(Prologue.NPC_ID, false):
		_fail.append("prologue: the arrival counted as a talk with Damon")
	# the night at the stern, the same view at first light, the climb
	var seen := {}
	var climb_from := Vector3.INF
	var climb_to := Vector3.INF
	while is_instance_valid(p) and not p.is_queued_for_deletion() and Game.prologue:
		var st: String = p.stage
		var cam := player.get_viewport().get_camera_3d()
		if st != "" and not seen.has(st):
			seen[st] = true
			await _frames(4)
			cam = player.get_viewport().get_camera_3d()
			if cam == player.camera:
				_fail.append("prologue: the %s is seen through the player's eyes" % st)
			if not Game.ui_blocking:
				_fail.append("prologue: the world listens to keys during the %s" % st)
			var want: float = {"night": Prologue.NIGHT_HOUR, "dawn": Prologue.DAWN_HOUR, "climb": Prologue.DAWN_HOUR}[st]
			if not is_equal_approx(atm.t, want):
				_fail.append("prologue: the %s at hour %.2f, want %.2f" % [st, atm.t, want])
			if st == "night" and cam.global_position.distance_to(harbour.ship().global_position) > 8.0:
				_fail.append("prologue: the night is not seen from the Swallow but from %s" % cam.global_position)
		if st == "climb" and cam != player.camera:
			if climb_from == Vector3.INF:
				climb_from = cam.global_position
			climb_to = cam.global_position
		await get_tree().process_frame
	for st: String in ["night", "dawn", "climb"]:
		if not seen.has(st):
			_fail.append("prologue: no %s after the talk" % st)
	if climb_from != Vector3.INF and climb_to.y - climb_from.y < 20.0:
		_fail.append("prologue: the climb goes from %s to %s, not up the hill" % [climb_from, climb_to])
	if climb_to != Vector3.INF and climb_to.distance_to(player.camera.global_position) > 1.0:
		_fail.append("prologue: the climb ends %.2f m from the player's eyes" % climb_to.distance_to(player.camera.global_position))
	print("prologue: night at the stern, dawn, climb from y %.1f to %.1f" % [climb_from.y, climb_to.y])
	if is_instance_valid(p) and not p.is_queued_for_deletion():
		await p.finished
	await _frames(3)
	if Game.prologue or not is_equal_approx(atm.t, Game.time_target()) or Game.time_target() > 0.01:
		_fail.append("prologue: no morning (prologue %s, hour %.2f)" % [Game.prologue, atm.t])
	if player.global_position.distance_to(Topo.spawn_point()) > 1.0:
		_fail.append("prologue: not on the hill in the morning but at %s" % player.global_position)
	if Game.ui_blocking:
		_fail.append("prologue: the game is still held after the morning")
	if player.get_viewport().get_camera_3d() != player.camera:
		_fail.append("prologue: the game begins through someone else's camera")
	print("prologue: dusk on the pier, %d lines with Damon, morning on the hill" % shown)


func _open_title() -> CanvasLayer:
	var title: CanvasLayer = load("res://scripts/ui/title_screen.gd").new()
	title.name = "TitleScreen"
	_main().add_child(title)
	title.open()
	return title


## A found row in the journal opens that find in the info panel's viewer.
func _check_journal_view() -> void:
	var j: Node = _main().get_node("JournalPanel")
	var info: Node = _main().get_node("InfoPanel")
	var d: Discovery = Game.registry.values()[0]
	j.open()
	await _frames(2)
	j.view(d)
	await _frames(4)
	if j.is_open() or not info.is_open() or info._shown != d:
		_fail.append("journal did not open %s in the info panel" % d.id)
	else:
		_check_viewer(info, String(d.id))
	info.close()
	await _frames(2)
	print("journal view: %s" % d.id)


## Steps up to the agora flock: the nearest chicken must scatter and stay home.
func _check_chickens(player: CharacterBody3D) -> void:
	var birds := get_tree().get_nodes_in_group(&"chicken")
	if birds.size() < 4:
		_fail.append("only %d chickens" % birds.size())
		return
	var back := player.global_position
	var c: Chicken = null
	# a calm one: a hen still running from the bot passing by cannot be scared
	# again, and its count would not move
	for b: Chicken in birds:
		var calm := b.state != Chicken.State.FLEE and b.state != Chicken.State.ROOST
		if calm and b.name.begins_with("agora") and (c == null or b.global_position.distance_to(back) < c.global_position.distance_to(back)):
			c = b
	if c == null:
		_fail.append("no calm chicken on the agora to scare")
		return
	player.bot_move = Vector2.ZERO
	var before := c.fled
	player.global_position = Vector3(c.global_position.x - 1.0, Topo.AGORA_H, c.global_position.z)
	player.look_at_point(c.global_position)
	var start := c.global_position
	await _frames(60)
	if c.fled == before:
		_fail.append("chicken %s did not scatter" % c.name)
	elif c.global_position.distance_to(start) < 0.3:
		_fail.append("chicken %s scattered but did not move" % c.name)
	if Vector2(c.global_position.x - c.home.x, c.global_position.z - c.home.z).length() > c.radius + 0.05:
		_fail.append("chicken %s left home" % c.name)
	print("chickens: %d, %s scattered %.2f m" % [birds.size(), c.name, c.global_position.distance_to(start)])
	player.global_position = back
	await _frames(5)


## Turns aside to any unlit lamp within reach, lights it through the
## interactor ray (like pressing E), then returns to the route.
func _light_nearby(player: CharacterBody3D) -> void:
	for lamp: Lamp in Game.lamps:
		if lamp.lit:
			continue
		var lp := Vector2(lamp.global_position.x, lamp.global_position.z)
		var pp := Vector2(player.global_position.x, player.global_position.z)
		if pp.distance_to(lp) > 4.0:
			continue
		var steps := 0
		while Vector2(player.global_position.x, player.global_position.z).distance_to(lp) > 1.4 and steps < 240:
			player.look_at_point(Vector3(lp.x, player.camera.global_position.y, lp.y))
			player.bot_move = Vector2(0, -1)
			await get_tree().physics_frame
			steps += 1
		player.bot_move = Vector2.ZERO
		await _frames(3)
		player.look_at_point(lamp.global_position + Vector3(0, 1.0, 0))
		await get_tree().physics_frame
		await get_tree().physics_frame
		if not player.interactor.try_interact() or not lamp.lit:
			_fail.append("could not light lamp at %s from %s" % [lamp.global_position, player.global_position])
			lamp.lit = true  # do not retry forever
		else:
			print("lit lamp %d/%d" % [Game.lamps_lit(), Game.lamps.size()])
			if not lamp.just_caught():
				_fail.append("lamp at %s lit without the catch of the flame" % lamp.global_position)


## All finds bring the night; every lamp should be lit by the end of the route.
func _check_night() -> void:
	var atm: Node = _main().world.get_node("Atmosphere")
	if atm.t < 0.99:
		_fail.append("night did not fall: hour %.2f" % atm.t)
	if Game.lamps.size() < 15:
		_fail.append("only %d lamps on the route" % Game.lamps.size())
	if Game.lamps_lit() != Game.lamps.size():
		_fail.append("lit %d of %d lamps" % [Game.lamps_lit(), Game.lamps.size()])
	print("night: hour %.2f, lamps %d/%d" % [atm.t, Game.lamps_lit(), Game.lamps.size()])
	# A lit lamp must also be heard: the burning bed is what says it is burning.
	var silent := 0
	for l: Lamp in Game.lamps:
		if l.lit and not l.looping():
			silent += 1
	if silent > 0:
		_fail.append("%d of %d lit lamps are silent" % [silent, Game.lamps.size()])
	print("lamps: %d of %d burning" % [Game.lamps.size() - silent, Game.lamps.size()])
	# The square's braziers and column lamps follow the same dusk.
	var night_fires := get_tree().get_nodes_in_group(&"night_fire")
	if night_fires.size() < 10:
		_fail.append("agora: %d dusk fires, expected 10" % night_fires.size())
	for f: Node in night_fires:
		if not f.lit:
			_fail.append("agora: a brazier stayed dark after dusk")
			break
	# The children on the square went home at dusk and sit by Myrto's hearth.
	var kb: Knucklebones = _main().world.find_child("Knucklebones", true, false)
	if kb == null:
		_fail.append("no children on the square")
	else:
		var home := kb.walkers()
		if home.size() != 2:
			_fail.append("%d children went home at dusk, expected 2" % home.size())
		for i in home.size():
			var n: Npc = home[i]
			var d := Vector2(n.global_position.x, n.global_position.z).distance_to(Knucklebones.HOME_SEATS[i])
			if n.patrol.is_empty():
				_fail.append("child %d was put home, not walked there: dusk came unseen" % i)
			if d > 0.1 or n.pose_now() != "sit":
				_fail.append("child %d not sitting at home: %.2f m off, pose %s" % [i, d, n.pose_now()])
		print("children: %d home by the hearth" % home.size())
	# The watch on the town wall: a fire on every tower, and the torches answer.
	var watch: WallWatch = _main().world.find_child("WallWatch", true, false)
	if watch == null:
		_fail.append("no watch on the town wall")
	else:
		var dark := watch.fire_count() - watch.fires_lit()
		if watch.fire_count() < 8 or dark > 0 or not watch.lit:
			_fail.append("wall watch: %d of %d tower fires dark after dusk" % [dark, watch.fire_count()])
		print("wall watch: %d tower fires, relay clock %.0f s" % [watch.fire_count(), watch.clock])
	# The lamp beside the cottage door follows the same dusk.
	var wall_lamps := get_tree().get_nodes_in_group(&"wall_lamp")
	for w: Node in wall_lamps:
		if not w.lit:
			_fail.append("a wall lamp stayed dark after dusk")
			break
	print("wall lamps: %d lit of %d" % [wall_lamps.filter(func(w: Node) -> bool: return w.lit).size(), wall_lamps.size()])
	print("agora: %d dusk fires lit of %d" % [night_fires.filter(func(f: Node) -> bool: return f.lit).size(), night_fires.size()])
	# Everything the route does should have paid out; the dream one comes later.
	var missing: PackedStringArray = []
	for id: String in ["ACH_FIRST_FIND", "ACH_ALL_FINDS", "ACH_ALL_LAMPS", "ACH_HEARD_ALL"]:
		if not Achievements.is_unlocked(id):
			missing.append(id)
	if not missing.is_empty():
		_fail.append("achievements still locked: %s" % ", ".join(missing))
	print("achievements after the route: %d of %d" % [Achievements.count(), Achievements.LIST.size()])
	# The square must also be heard: the murmur bed runs for the whole slice.
	var amb: Node = _main().world.get_node_or_null("Ambience")
	if amb != null:
		var market: AudioStreamPlayer3D = amb.get_node_or_null("Market")
		if market == null or not market.playing:
			_fail.append("the market is silent")
	# Every lamp is lit by now, so the two by the orchestra have answered too.
	var fires := get_tree().get_nodes_in_group(&"corner_fire")
	if fires.size() < 4:
		_fail.append("theatre: %d corner fires, expected 4" % fires.size())
	for f: Node in fires:
		if not f.lit:
			_fail.append("theatre: a corner fire stayed dark with every lamp lit")
			break
	print("theatre: %d corner fires lit" % fires.filter(func(f: Node) -> bool: return f.lit).size())
	var om: Node = _main().world.get_node("Omens")
	if not om.night:
		_fail.append("omens: night not noticed")
	if not om.supper_lamp.visible:
		_fail.append("omens: no lamp at Hecate's supper")
	if not om.vanished:
		_fail.append("omens: the figure on the street did not vanish as the bot passed")
	if om.howls < 1:
		_fail.append("omens: no dog howled in the night")
	var dog: Node = get_tree().get_first_node_in_group(&"dog")
	if dog == null or dog.watch == Vector3.INF:
		_fail.append("omens: the dog sleeps through the night")
	print("omens: figure vanished=%s, howls=%d, dog awake=%s" % [om.vanished, om.howls, dog != null and dog.watch != Vector3.INF])


## Switching language live re-renders the open info panel and the HUD.
func _check_language() -> void:
	var info: Node = _main().get_node("InfoPanel")
	var hud: Node = _main().get_node("HUD")
	var d: Discovery = Game.registry.values()[0]
	info._on_discovered(d, false)
	for lang: String in ["ru", "en"]:
		TranslationServer.set_locale(lang)
		await _frames(2)
		var title: String = info._title.text
		var want: String = load("res://data/i18n/strings.%s.translation" % lang).get_message(d.title)
		if title != want:
			_fail.append("info panel title in %s is %s, want %s" % [lang, title, want])
		var counter: String = hud._counter.text
		if (lang == "ru") != counter.begins_with("НАХОДКИ"):
			_fail.append("HUD counter not re-rendered in %s: %s" % [lang, counter])
	info.close()
	print("language: live switch en<->ru ok" if _fail.is_empty() else "language: FAILED")


## The cicadas belong to the hill: in the late afternoon all three must be
## singing. By the night they are gone — _check_audio looks at that side.
func _check_cicadas() -> void:
	var amb: Node = _main().world.get_node_or_null("Ambience")
	if amb == null:
		_fail.append("no ambience")
		return
	var cicadas: Array = amb.find_children("Cicadas*", "AudioStreamPlayer3D", false, false)
	if cicadas.is_empty():
		_fail.append("no cicadas on the hill")
		return
	var singing := 0
	for c: AudioStreamPlayer3D in cicadas:
		if c.playing:
			singing += 1
	if singing < cicadas.size():
		_fail.append("only %d of %d cicadas sing on the hill" % [singing, cicadas.size()])
	if amb.heat < 0.9:
		_fail.append("the cicadas are already faded out in the afternoon (%.2f)" % amb.heat)
	print("cicadas on the hill: %d of %d singing, heat %.2f" % [singing, cicadas.size(), amb.heat])


func _check_audio(player: CharacterBody3D) -> void:
	var amb: Node = _main().world.get_node("Ambience")
	var wind: AudioStreamPlayer = amb.get_node("Wind")
	if not wind.playing or (wind.stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_FORWARD:
		_fail.append("wind is not playing in a loop")
	var surf := amb.find_children("Surf*", "AudioStreamPlayer3D", false, false)
	if surf.is_empty() or not (surf[0] as AudioStreamPlayer3D).playing:
		_fail.append("surf is not playing")
	if player.steps_played < 20:
		_fail.append("only %d footsteps played" % player.steps_played)
	# The walk crosses the paving of the hill and the street and the bare ground
	# of the beach: the two must be heard, or the surface lookup is dead.
	if player.stone_steps < 5:
		_fail.append("only %d steps rang on the paving" % player.stone_steps)
	if player.dirt_steps < 5:
		_fail.append("only %d steps fell on the earth" % player.dirt_steps)
	# A surface that keeps picking the same take turns the walk into one sound
	# repeated: every set must have been heard in at least three of its four takes.
	for kind: StringName in [&"stone", &"dirt"]:
		var counts: Array = player.takes_used.get(kind, [])
		var heard := counts.filter(func(c: int) -> bool: return c > 0).size()
		if heard < 3:
			_fail.append("%s steps used only %d takes of %d" % [kind, heard, counts.size()])
		print("steps on %s: %s" % [kind, str(counts)])
	if amb.gulls_played < 1:
		_fail.append("no gull call during the walk")
	if amb.heat > 0.05:
		_fail.append("the cicadas still sing at night (%.2f)" % amb.heat)
	print("audio: steps=%d (paving %d, earth %d) gulls=%d cicadas=%.2f"
			% [player.steps_played, player.stone_steps, player.dirt_steps, amb.gulls_played, amb.heat])
	var flew := 0
	for b: Bird in get_tree().get_nodes_in_group(&"pigeon"):
		flew += b.took_off
	if get_tree().get_nodes_in_group(&"gull").size() < 5:
		_fail.append("only %d gulls" % get_tree().get_nodes_in_group(&"gull").size())
	if flew < 1:
		_fail.append("no pigeon took off as the bot crossed the agora")
	var roofed := 0
	for b: Bird in get_tree().get_nodes_in_group(&"pigeon"):
		roofed += b.roofed
	if roofed < 1:
		_fail.append("no scared pigeon settled on the stoa roof")
	print("birds: %d gulls, pigeons took off %d times, settled on the roof %d times" % [get_tree().get_nodes_in_group(&"gull").size(), flew, roofed])


func _check_pause() -> void:
	var pause: Node = _main().get_node("PauseMenu")
	pause.open()
	await _frames(2)
	if not get_tree().paused or not pause.is_open():
		_fail.append("pause menu did not pause the tree")
	var player: CharacterBody3D = _main().player()
	var p0 := player.global_position
	player.bot_move = Vector2(0, -1)
	await _frames(20)
	if player.global_position.distance_to(p0) > 0.001:
		_fail.append("player moved while paused")
	player.bot_move = Vector2.ZERO
	pause.close()
	await _frames(2)
	if get_tree().paused:
		_fail.append("pause menu did not resume")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
