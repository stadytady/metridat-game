extends "res://tests/test_case.gd"
## The hour drives every light; check its ends and its continuity.


func test_ends_match_keys() -> void:
	var day := DayCycle.sample(0.0)
	var night := DayCycle.sample(1.0)
	check(day.sun_energy > 1.0 and day.moon_energy == 0.0, "afternoon: sun up, no moon")
	check(night.sun_energy == 0.0 and night.moon_energy > 0.2, "night: no sun, moon up")
	check(day.sky_weights == Vector3(1, 0, 0) and night.sky_weights == Vector3(0, 0, 1), "sky weights at the ends")
	check(night.ambient_energy < day.ambient_energy, "night is darker")


func test_continuous_and_monotonic_darkening() -> void:
	var prev: Dictionary = DayCycle.sample(0.0)
	for i in range(1, 101):
		var cur := DayCycle.sample(i / 100.0)
		check(absf(cur.sun_energy - prev.sun_energy) < 0.15, "sun energy jumps at t=%.2f" % (i / 100.0))
		check(cur.ambient_energy <= prev.ambient_energy + 1e-6, "ambient brightens at t=%.2f" % (i / 100.0))
		check(cur.sun_elevation <= prev.sun_elevation + 1e-6, "sun rises at t=%.2f" % (i / 100.0))
		var w: Vector3 = cur.sky_weights
		check(absf(w.x + w.y + w.z - 1.0) < 1e-4, "sky weights do not sum to 1 at t=%.2f" % (i / 100.0))
		prev = cur


func test_target_follows_finds() -> void:
	check(DayCycle.target_for(0, 6) == 0.0, "start in the afternoon")
	check(DayCycle.target_for(6, 6) == 1.0, "all finds bring the night")
	check(DayCycle.target_for(3, 6) > DayCycle.target_for(2, 6), "each find moves the evening on")


## Past night lies the dream: fog close around, the moon brighter than at
## night, and no hour beyond it.
func test_dream_key() -> void:
	var night := DayCycle.sample(1.0)
	var dream := DayCycle.sample(DayCycle.DREAM)
	check(dream.fog_end < night.fog_end / 5.0, "dream fog must close in: %.0f vs %.0f" % [dream.fog_end, night.fog_end])
	check(dream.fog_begin < night.fog_begin, "dream fog starts nearer")
	check(dream.moon_energy > night.moon_energy, "the dream's moon is brighter")
	check(dream.sun_energy == 0.0, "no sun in the dream")
	var fog: Color = dream.fog_color
	check(fog.get_luminance() < 0.2, "the dream's fog is night fog, not a grey day: %.2f" % fog.get_luminance())
	check(DayCycle.sample(DayCycle.DREAM + 1.0).fog_end == dream.fog_end, "nothing past the dream")
	check(DayCycle.sample(0.5).fog_end == night.fog_end, "the waking day keeps its far fog")


## The town's lamps come on at the eighth of the city's finds, not before.
func test_the_lamps_come_on_at_the_eighth_find() -> void:
	var total := 0
	for f: String in DirAccess.get_files_at("res://data/discoveries"):
		if f.ends_with(".tres"):
			var d: Discovery = load("res://data/discoveries/" + f)
			if not d.epilogue:
				total += 1
	var at := DayCycle.LAMPS_ON_AT_FIND
	check(DayCycle.target_for(at, total) >= DayCycle.LAMPS_ON, "the lamps are still dark at find %d of %d" % [at, total])
	check(DayCycle.target_for(at - 1, total) < DayCycle.LAMPS_ON, "the lamps are already lit at find %d of %d" % [at - 1, total])
	for lamp: float in [WallLamp.DUSK, load("res://scripts/world/agora.gd").DUSK, load("res://scripts/world/backdrop.gd").GLOW_FROM,
			load("res://scripts/world/harbour.gd").LANTERN_FROM]:
		check(is_equal_approx(lamp, DayCycle.LAMPS_ON), "a light keeps its own hour: %.2f" % lamp)
	# and the prologue's dusk has them lit
	check(DayCycle.PROLOGUE >= DayCycle.LAMPS_ON, "the prologue's dusk is too early for the lamps")
