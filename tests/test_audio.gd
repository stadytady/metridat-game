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
	for name: String in ["market_cry.wav", "sandals.wav"]:
		var s: AudioStreamWAV = load(DIR + "/" + name)
		check(s != null, name + " did not import")
		if s == null:
			continue
		check(s.get_length() < 1.5, "%s is %.1f s long" % [name, s.get_length()])
		check(s.loop_mode == AudioStreamWAV.LOOP_DISABLED, name + " loops")
