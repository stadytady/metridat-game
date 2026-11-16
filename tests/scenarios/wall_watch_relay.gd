extends "res://tests/qa/scenario.gd"
## The night watch seen from the field, as the player sees it: at dusk every
## tower fire on the wall catches, the post by the acropolis raises its torch,
## the others answer in turn, and all come down again before the next round.


func fixture() -> Dictionary:
	return {"found": 10, "lamps": "all", "hour": 1.0, "timeout": 150.0}


func run() -> void:
	var watch: WallWatch = main().world.find_child("WallWatch", true, false)
	check(watch != null, "no watch on the wall")
	if watch == null:
		return
	step("fires on the towers")
	await view("watch")
	await seconds(1.0)
	check(watch.lit and watch.fires_lit() == watch.fire_count(), "%d of %d tower fires lit" % [watch.fires_lit(), watch.fire_count()])
	await shot("towers_lit")
	step("the torches answer")
	# answers come ANSWER apart and a torch is up HOLD + 2 RAMP: two at a time
	# at most, so what counts is that every post took its turn in the round
	var n := watch.fire_count()
	var seen := {}
	var shot_taken := false
	var t := 0.0
	while t < WallWatch.RELAY_EVERY:
		for rank in n:
			if WallWatch.relay_lift(watch.clock, rank, n) > 0.5:
				seen[rank] = true
		if watch.raised() >= 2 and not shot_taken:
			shot_taken = true
			await shot("torches_raised")
		if seen.size() == n and watch.raised() == 0:
			break  # the round went along the wall and came down
		await seconds(0.25)
		t += 0.25
	check(seen.size() == n, "in a round %d of %d posts raised a torch" % [seen.size(), n])
	check(watch.raised() == 0, "%d torches still up after the round" % watch.raised())
	step("from the roof")
	await view("watch_roof")
	await shot("sentry_on_the_roof")
