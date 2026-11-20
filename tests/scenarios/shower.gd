extends "res://tests/qa/scenario.gd"
## A walk whose afternoon has a shower: at its height the rain falls round the
## player, the sun is dimmed and the haze closes in; the same hour on a dry walk
## is clear again.


func fixture() -> Dictionary:
	return {"found": 6, "weather": 1, "hour": 0.38, "at": Vector2(9.0, 0.0), "look": Vector3(30.0, 2.0, 3.0)}


func run() -> void:
	var w: Weather = main().world.find_child("Weather", true, false)
	var atm: Node = main().world.find_child("Atmosphere", true, false)
	check(w != null and atm != null, "no weather or atmosphere in the world")
	if w == null or atm == null:
		return
	step("in the shower")
	check(Weather.rain_at(0.38, 1) > 0.9, "seed 1 has no shower at 0.38")
	await seconds(1.0)
	check(w.raining(), "no rain falls at the height of the shower")
	var dry: Dictionary = DayCycle.sample(0.38)
	check(atm.sun.light_energy < float(dry.sun_energy) * 0.5, "the sun is not dimmed: %.2f" % atm.sun.light_energy)
	check(atm.env.fog_depth_end < float(dry.fog_end) * 0.5, "the haze does not close in")
	await shot("shower")
	step("a dry walk")
	Game.weather_seed = 0
	await seconds(1.0)
	atm.apply(0.38)
	check(not w.raining(), "it still rains on a dry walk")
	check(is_equal_approx(atm.sun.light_energy, float(dry.sun_energy)), "the sun stays dim on a dry walk")
