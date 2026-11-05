extends "res://tests/test_case.gd"
## The lamp sounds: a short one-shot for the flame catching, a long looping bed
## for as long as it burns. Both must stay in the quiet part of the mix.

const DIR := "res://assets/audio"


func test_ignite_is_a_short_one_shot() -> void:
	var s: AudioStreamWAV = load(DIR + "/lamp_ignite.wav")
	check(s != null, "lamp_ignite.wav did not import")
	if s == null:
		return
	check(s.get_length() > 0.2 and s.get_length() < 1.5, "ignite is %.2f s long" % s.get_length())
	check(s.loop_mode == AudioStreamWAV.LOOP_DISABLED, "the ignite must not loop")
	check(s.get_data().size() > 1000, "the ignite has no samples")


func test_fire_bed_loops() -> void:
	var s: AudioStreamWAV = load(DIR + "/fire.wav")
	check(s != null, "fire.wav did not import")
	if s == null:
		return
	check(s.get_length() > 3.0, "the fire bed is only %.1f s" % s.get_length())
	check(s.loop_mode != AudioStreamWAV.LOOP_DISABLED, "the fire bed does not loop")


func test_lamps_are_quiet() -> void:
	# A bed at -19 dB and a catch at -11 dB: audible up close, never the loudest
	# thing in the mix.
	check(Lamp.BED_DB <= -18.0, "the burning bed sits at %.0f dB" % Lamp.BED_DB)
	check(Lamp.IGNITE_DB <= -10.0, "the catch sits at %.0f dB" % Lamp.IGNITE_DB)


func test_market_bed_loops() -> void:
	var s: AudioStreamWAV = load(DIR + "/market.wav")
	check(s != null, "market.wav did not import")
	if s == null:
		return
	check(s.get_length() > 8.0, "the market bed is only %.1f s" % s.get_length())
	check(s.loop_mode != AudioStreamWAV.LOOP_DISABLED, "the market bed does not loop")


func test_wheel_loops() -> void:
	var s: AudioStreamWAV = load(DIR + "/wheel.wav")
	check(s != null, "wheel.wav did not import")
	if s == null:
		return
	check(s.loop_mode != AudioStreamWAV.LOOP_DISABLED, "the wheel does not loop")
	check(s.get_length() > 1.0, "the wheel bed is only %.1f s" % s.get_length())


func test_cries_and_footsteps_are_one_shots() -> void:
	for name: String in ["market_cry.wav", "sandals.wav", "sheep.wav"]:
		var s: AudioStreamWAV = load(DIR + "/" + name)
		check(s != null, name + " did not import")
		if s == null:
			continue
		check(s.get_length() < 1.5, "%s is %.1f s long" % [name, s.get_length()])
		check(s.loop_mode == AudioStreamWAV.LOOP_DISABLED, name + " loops")


func test_cicadas_are_a_long_loop() -> void:
	var s: AudioStreamWAV = load(DIR + "/cicada.wav")
	check(s != null, "cicada.wav did not import")
	if s == null:
		return
	check(s.get_length() > 8.0, "the cicada bed is only %.1f s" % s.get_length())
	check(s.loop_mode != AudioStreamWAV.LOOP_DISABLED, "the cicada bed does not loop")
	check(s.get_data().size() > 100000, "the cicada bed has no samples")


## Mean sample-to-sample jump: a bright sound wiggles fast, a muffled one drifts.
func _roughness(path: String) -> float:
	var s: AudioStreamWAV = load(path)
	if s == null:
		return 0.0
	var d := s.get_data()
	var n := d.size() / 2 - 1
	if n <= 0:
		return 0.0
	var sum := 0
	for i in n:
		sum += absi(d.decode_s16((i + 1) * 2) - d.decode_s16(i * 2))
	return float(sum) / float(n)


## Paving rings, the ground swallows the ring: the two sets have to differ by a
## wide margin, not by a shade, or the walk sounds the same everywhere.
func test_steps_differ_between_paving_and_earth() -> void:
	var stone := 0.0
	var dirt := 0.0
	for i in 4:
		for kind: String in ["stone", "dirt"]:
			var path := DIR + "/step_%s_%d.wav" % [kind, i]
			var s: AudioStreamWAV = load(path)
			check(s != null, path.get_file() + " did not import")
			if s == null:
				continue
			check(s.loop_mode == AudioStreamWAV.LOOP_DISABLED, path.get_file() + " loops")
			check(s.get_length() < 0.4, "%s is %.2f s long" % [path.get_file(), s.get_length()])
		stone += _roughness(DIR + "/step_stone_%d.wav" % i)
		dirt += _roughness(DIR + "/step_dirt_%d.wav" % i)
	check(stone > 0.0 and dirt > 0.0, "a step set is silent")
	check(stone > dirt * 1.8,
			"paving (%.0f) is not clearly brighter than earth (%.0f)" % [stone / 4.0, dirt / 4.0])


## The player must have both sets wired, and each one must hold several takes.
func test_player_has_both_step_sets() -> void:
	var script: GDScript = load("res://scripts/player/player.gd")
	var consts := script.get_script_constant_map()
	check(consts.has("STEPS"), "player.gd has no STEPS table")
	if not consts.has("STEPS"):
		return
	var steps: Dictionary = consts["STEPS"]
	for kind: StringName in [&"stone", &"dirt"]:
		check(steps.has(kind), "no %s steps in the table" % kind)
		if steps.has(kind):
			check((steps[kind] as Array).size() >= 4, "only %d %s takes" % [(steps[kind] as Array).size(), kind])
