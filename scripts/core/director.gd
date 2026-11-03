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
	var vps: Dictionary = _main().world.viewpoints()
	for name: String in vps:
		if not _only.is_empty() and name not in _only:
			continue
		var eye: Vector3 = vps[name][0]
		player.global_position = eye - Vector3(0, 1.6, 0)
		player.look_at_point(vps[name][1])
		player.camera.position.y = 0.0
		await _frames(8)
		var img := get_viewport().get_texture().get_image()
		var path := _out.path_join("%s.png" % name)
		img.save_png(path)
		print("shot ", path)
	if _only.is_empty() or "ui" in _only:
		await _ui_shots(player)
	_report_perf()
	get_tree().quit()


## Prompt, info panel and pause menu over the agora.
func _ui_shots(player: CharacterBody3D) -> void:
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
	_main().get_node("PauseMenu").open()
	await _frames(6)
	_save("ui_pause")
	_main().get_node("PauseMenu").close()


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


func _inspectables() -> Dictionary:
	var out := {}
	for n in get_tree().get_nodes_in_group(&"inspectable"):
		out[String(n.discovery.id)] = n
	return out


## Route: Vector2 = walk to (x, z); String = inspect that discovery from here.
func _route() -> Array:
	var r: Array = []
	var c := Topo.HILL_CENTER
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
	r.append(Vector2(22.0, -0.9))
	r.append("inscription_stele")
	r.append(Vector2(20.4, 4.7))
	r.append("coin_stater")
	r.append(Vector2(24.3, 5.7))
	r.append("grain_pithos")
	r.append(Vector2(34.0, -2.0))
	r.append(Vector2(34.0, -9.8))
	r.append(Vector2(Topo.SANCT_STAIR[1].x, Topo.SANCT_STAIR[1].z))
	r.append(Vector2(42.0, -21.0))
	r.append(Vector2(51.5, -21.0))
	r.append(Vector2(51.6, -29.0))
	r.append("votive_figurine")
	# Night falls with the last find: walk back up to the hill, lighting lamps.
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
	var main := _main()
	var player: CharacterBody3D = main.player()
	player.bot_enabled = true
	await _frames(5)
	var items := _inspectables()
	print("walkthrough: %d inspectables registered, Game.total()=%d" % [items.size(), Game.total()])
	if items.size() < 5:
		_fail.append("fewer than 5 inspectables")
	var min_y := INF
	for step in _route():
		if Game.found_count() == Game.total():
			_lighting = true
		if step is Vector2:
			var ok := await _walk_to(player, step)
			if not ok:
				break
		else:
			await _inspect(player, items, step)
		min_y = minf(min_y, player.global_position.y)
	player.bot_move = Vector2.ZERO
	if min_y < 0.0:
		_fail.append("player went below sea level (min y %.2f)" % min_y)
	if Game.found_count() != Game.total():
		_fail.append("found %d of %d discoveries" % [Game.found_count(), Game.total()])
	_check_night()
	_check_audio(player)
	await _check_pause()
	await _check_language()
	print("walkthrough: found %d/%d, end at %s" % [Game.found_count(), Game.total(), player.global_position])
	for f in _fail:
		print("FAIL ", f)
	print("WALKTHROUGH ", "PASS" if _fail.is_empty() else "FAIL")
	get_tree().quit(0 if _fail.is_empty() else 1)


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
	if Game.found_count() != before + 1:
		_fail.append("counter did not advance for " + id)
	print("inspected %s (%d/%d)" % [id, Game.found_count(), Game.total()])
	info.close()
	await _frames(3)


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


## All finds bring the night; every lamp should be lit by the end of the route.
func _check_night() -> void:
	var atm: Node = _main().world.get_node("Atmosphere")
	if atm.t < 0.99:
		_fail.append("night did not fall: hour %.2f" % atm.t)
	if Game.lamps_lit() != Game.lamps.size():
		_fail.append("lit %d of %d lamps" % [Game.lamps_lit(), Game.lamps.size()])
	print("night: hour %.2f, lamps %d/%d" % [atm.t, Game.lamps_lit(), Game.lamps.size()])


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
	if amb.gulls_played < 1:
		_fail.append("no gull call during the walk")
	print("audio: steps=%d gulls=%d" % [player.steps_played, amb.gulls_played])


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
