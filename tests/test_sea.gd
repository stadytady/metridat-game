extends "res://tests/test_case.gd"
## The CPU copy of the waves: calm on the beach, bounded, moving with the
## clock; and a hull floated on it keeps its deck above the water.

const B := preload("res://scripts/world/backdrop.gd")


func test_waves_calm_on_the_beach_and_bounded() -> void:
	var max_h := 0.0
	for i in 200:
		var t := i * 0.37
		check(absf(Sea.height_at(Topo.waterline_x(0.0) - 2.0, 0.0, t)) < 0.001, "waves on the sand")
		max_h = maxf(max_h, absf(Sea.height_at(Topo.waterline_x(10.0) + 20.0, 10.0, t)))
	check(max_h > 0.3, "no waves in the shallows: %.2f" % max_h)
	check(max_h < 1.08 * 1.7 * 1.25 + 0.01, "waves higher than the shader can make: %.2f" % max_h)
	check(Sea.height_at(120.0, 0.0, 1.0) != Sea.height_at(120.0, 0.0, 2.0), "the sea stands still")


func test_floating_hull_keeps_its_deck_dry() -> void:
	# a ship of scale 1: keel at WATERLINE (-1), deck at 1.25, hull 7 m either way of midships
	for p: Vector3 in [Vector3(85.0, 0, -10.9), Vector3(128.0, 0, 10.0), Vector3(240.0, 0, -55.0)]:
		for i in 120:
			var t := i * 0.53
			var f := Sea.float_pose(p, 0.0, 7.0, 2.2, t)
			var deck := -1.0 + f.x + 2.25
			for dx: float in [-7.0, 0.0, 7.0]:
				# the deck tilts with the pitch along the hull
				var deck_here := deck + tan(f.z) * dx
				check(Sea.height_at(p.x + dx, p.z, t) < deck_here - 0.3, "water over the deck at %s t %.1f" % [p + Vector3(dx, 0, 0), t])


## The wind is one: the swell rolls in to the shore (west, the land side) and
## the hearth smoke over the roofs leans the same way, inland, not out to sea.
func test_the_swell_and_the_smoke_go_with_one_wind() -> void:
	check(Sea.ONSHORE.x < 0.0, "the wind blows out to sea: %s" % Sea.ONSHORE)
	# open water, far from the shoaling: where do the crests go in half a second?
	var best := 0.0
	var best_err := INF
	for step in range(-30, 31):
		var shift := step * 0.05
		var err := 0.0
		for i in 200:
			var x := 300.0 + i * 0.5
			err += absf(Sea.height_at(x, 0.0, 10.5) - Sea.height_at(x - shift, 0.0, 10.0))
		if err < best_err:
			best_err = err
			best = shift
	check(best < -0.2, "the swell moves %.2f m along x in half a second: out to sea, not in to the shore" % best)
	# the shader keeps the same wave list as the CPU (ships ride height_at)
	var shader := FileAccess.get_file_as_string("res://assets/shaders/psx_water.gdshader")
	for w: Vector4 in Sea.WAVES:
		var line := "vec4(%s, %s, %s, %s)" % [_num(w.x), _num(w.y), _num(w.z), _num(w.w)]
		check(shader.contains(line), "psx_water has no wave %s: the sea and the ships part ways" % line)
	# the smoke leans downwind
	var plume: GPUParticles3D = B._smoke_plume(B.SMOKE_KINDS["wisp"])
	var g: Vector3 = (plume.process_material as ParticleProcessMaterial).gravity
	check(Vector2(g.x, g.z).normalized().dot(Sea.ONSHORE) > 0.99, "the smoke leans %s, the wind blows %s" % [Vector2(g.x, g.z), Sea.ONSHORE])
	plume.free()


func _num(v: float) -> String:
	var s := String.num(v, 3)  # Vector4 holds float32: 0.55 reads back 0.55000001
	return s if s.contains(".") else s + ".0"
