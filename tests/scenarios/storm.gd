extends "res://tests/qa/scenario.gd"
## The developer menu raises a storm over a dry afternoon: on its weather page,
## the storm row. Then the rain is the storm's (darker than any shower), the
## swell builds, lightning flashes the town and its thunder is heard; giving the
## weather back to the walk makes it dry again.


func fixture() -> Dictionary:
	return {"found": 6, "weather": 0, "hour": 0.38, "at": Vector2(9.0, 0.0), "look": Vector3(30.0, 2.0, 3.0)}


## A key as the menu hears it: an input event, not a held action.
func _key(action: StringName) -> void:
	for down: bool in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = down
		Input.parse_input_event(ev)
		await frames(2)


func run() -> void:
	var w: Weather = main().world.find_child("Weather", true, false)
	var atm: Node = main().world.find_child("Atmosphere", true, false)
	var admin: AdminPanel = main().get_node_or_null("AdminPanel")
	check(w != null and atm != null and admin != null, "no weather, atmosphere or developer menu")
	if w == null or atm == null or admin == null:
		return
	step("a dry afternoon")
	await seconds(0.5)
	check(not w.raining(), "it rains on a dry walk")
	var dry: Dictionary = DayCycle.sample(0.38)
	step("the menu raises a storm")
	await _key(&"admin")
	check(admin.is_open(), "the tilde key does not open the developer menu")
	await _key(&"move_right")
	check(admin._page == AdminPanel.PAGE_WEATHER, "right does not lead to the weather page")
	var row := AdminPanel.WEATHER_STEPS.find(Weather.STORM)
	for i in row:
		await _key(&"move_back")
	await _key(&"interact")
	check(Game.weather_override == Weather.STORM, "the storm row does not raise a storm (%d)" % Game.weather_override)
	await _key(&"admin")
	check(not admin.is_open(), "the menu stays open")
	await seconds(1.0)
	check(w.raining(), "no rain in the storm")
	check(w.slant() > 20.0, "the storm's rain does not slant: %.0f deg" % w.slant())
	check(w._pm.particle_flag_align_y, "the streaks stand upright whatever the wind")
	var shower := Weather.apply(dry, 1.0, 0.0)
	check(atm.sun.light_energy < float(shower.sun_energy) * 0.6, "the sun is no dimmer than in a shower: %.2f" % atm.sun.light_energy)
	check(atm.env.fog_depth_end < float(shower.fog_end), "the haze is no closer than in a shower")
	step("lightning and thunder")
	var keys := {}
	var hear := func(key: String) -> void: keys[key] = true
	var was_captions := Game.captions
	Game.captions = true
	Game.caption_requested.connect(hear)
	var calm_ambient := float(Weather.apply(dry, 1.0, 1.0).ambient_energy)
	var brightest := 0.0
	var t0 := Time.get_ticks_msec()
	# the bolts run on the weather's own clock (game time): a minute of it is
	# a dozen windows, enough for several bolts and their thunder
	var until := Weather.clock + 40.0
	while Weather.clock < until and Time.get_ticks_msec() - t0 < 90000:
		await frames(1)
		brightest = maxf(brightest, atm.env.ambient_light_energy)
	Game.caption_requested.disconnect(hear)
	Game.captions = was_captions
	check(brightest > calm_ambient + 0.5, "no bolt lit the town (ambient %.2f, storm %.2f)" % [brightest, calm_ambient])
	check(keys.has("CAP_THUNDER"), "no thunder after the bolts: %s" % [keys.keys()])
	check(Sea.swell > 1.2, "the swell has not built: %.2f" % Sea.swell)
	await shot("storm")
	# across the wind, where the slant shows
	look(Vector3(9.0, 2.0, -30.0))
	await seconds(0.5)
	await shot("storm_across")
	step("back to the walk's weather")
	await _key(&"admin")
	check(admin._page == AdminPanel.PAGE_WEATHER, "the menu forgot its page")
	for i in row:
		await _key(&"move_forward")
	await _key(&"interact")
	await _key(&"admin")
	check(Game.weather_override == -1, "the menu does not give the weather back")
	await seconds(1.0)
	check(not w.raining(), "it still rains on a dry walk")
	check(is_equal_approx(atm.sun.light_energy, float(dry.sun_energy)), "the sun stays dim after the storm")
