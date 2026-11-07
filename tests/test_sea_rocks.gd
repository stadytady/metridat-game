extends "res://tests/test_case.gd"
## The rocks out in the strait stand in the water: their foot is below the
## deepest trough wherever they may be put, so none shows its underside and
## seems to hang over the sea, and their top still rises over the mean sea.

const NATURE := preload("res://scripts/world/nature.gd")


func test_sea_rocks_keep_their_feet_under_the_troughs() -> void:
	# the deepest trough over the stretch the rocks are scattered on (_shore)
	var deepest := 0.0
	for x in range(75, 111, 5):
		for z in range(-90, 91, 15):
			for i in 60:
				deepest = minf(deepest, Sea.height_at(float(x), float(z), i * 0.37))
	check(deepest < -1.0, "the troughs out here are only %.2f m deep: the sample misses them" % deepest)
	for k in 11:
		var r := lerpf(1.5, 4.0, k / 10.0)
		var rock: Array[Vector3] = NATURE.sea_rock(90.0, 0.0, r)
		var foot := rock[0].y - NATURE.blob_reach_down(rock[1], NATURE.SEA_ROCK_JITTER)
		check(foot < deepest - 0.3, "a rock of %.1f m stands on %.2f, over a trough of %.2f" % [r, foot, deepest])
		var top := rock[0].y + rock[1].y * 0.851 * (1.0 - NATURE.SEA_ROCK_JITTER)
		check(top > 0.3, "a rock of %.1f m does not rise out of the sea (top %.2f)" % [r, top])
