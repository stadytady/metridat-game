extends "res://tests/qa/scenario.gd"
## The watchman's round through the back lanes at night: he comes out at dusk,
## walks his route with his lantern down, pauses only at its ends and never
## stands stuck against a wall in between.

const WATCH_SECONDS := 40.0
## Longest stand-still allowed: his pauses at the ends of the round are 3 s.
const STILL_MAX := 4.5


func fixture() -> Dictionary:
	return {"found": 10, "lamps": "all", "hour": 1.0, "timeout": 150.0}


func run() -> void:
	var man: Npc = main().world.find_child("Watchman", true, false)
	check(man != null, "no watchman in the lanes")
	if man == null:
		return
	step("out at dusk")
	await seconds(1.0)
	check(man.visible, "the watchman stays in at night")
	step("walks his round")
	var path := 0.0
	var still := 0.0
	var longest := 0.0
	var last := man.global_position
	var shots_left := [14.0, 24.0, 34.0]
	var trail: Array[Vector3] = []  # where he walked: a clear place to stand
	var t := 0.0
	while t < WATCH_SECONDS:
		await seconds(0.5)
		t += 0.5
		var d := man.global_position.distance_to(last)
		path += d
		still = still + 0.5 if d < 0.05 else 0.0
		longest = maxf(longest, still)
		last = man.global_position
		trail.append(last)
		if not shots_left.is_empty() and t >= float(shots_left[0]):
			shots_left.pop_front()
			# stand where he walked a few seconds ago (his own path is clear of
			# herms and walls), looking at his lantern
			var at: Vector3 = trail[maxi(0, trail.size() - 24)]  # ~12 s back: 4 m at his pace
			player().global_position = Vector3(at.x, Topo.surface(at.x, at.z) + 0.05, at.z)
			await look(man.global_position + Vector3(0, 1.1, 0))
			await shot("round_%02d" % int(t))
	check(path > WATCH_SECONDS * man.patrol_speed * 0.5, "in %.0f s he walked %.1f m" % [WATCH_SECONDS, path])
	check(longest <= STILL_MAX, "he stood still %.1f s on his round: stuck?" % longest)
