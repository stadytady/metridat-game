extends District
## Small agora: paved square, stoa with six Doric columns along the north,
## a merchant stall, benches, a statue base and stacked architectural pieces.

const COL_H := 3.6


func _ready() -> void:
	var c := Topo.AGORA_CENTER
	var h := Topo.AGORA_HALF
	var y := Topo.AGORA_H
	var kit := MeshKit.new()
	Arch.platform(kit, c, h, y, District.min_terrain(c, h) - 1.0)
	# stoa on the north edge, open to the south
	var stoa_xf := Arch.frame(Vector3(c.x, y, -5.0), Vector3.RIGHT)
	var cols := Arch.stoa(kit, stoa_xf, 20.0, 5.5, 6, COL_H)
	# parapet on the east edge, where the square stands above the slope
	kit.solid_box("limestone", Vector3(c.x + h.x - 0.3, y + 0.45, 3.0), Vector3(0.5, 0.9, h.y * 2 - 6.0), ["bottom"])
	kit.solid_box("limestone", Vector3(c.x + 5.0, y + 0.45, c.y + h.y - 0.3), Vector3(16.0, 0.9, 0.5), ["bottom"])
	# stall on the south side, facing the stoa
	var stall_pos := Vector3(c.x - 2.0, y, 6.5)
	Arch.stall(kit, Arch.frame(stall_pos, Vector3.LEFT))
	for b: Array in [[Vector3(c.x - h.x + 0.6, y, -6.0), Vector3.BACK, 3.0], [Vector3(c.x - h.x + 0.6, y, 5.5), Vector3.BACK, 2.5],
			[Vector3(c.x + 6.0, y, -2.0), Vector3.RIGHT, 2.8]]:
		Arch.bench(kit, Arch.frame(b[0], b[1]), b[2])
	# statue base (the bronze is gone) and architectural pieces
	kit.solid_box("limestone", Vector3(c.x + 1.0, y + 0.6, 0.5), Vector3(1.4, 1.2, 1.4), ["bottom"])
	kit.box("limestone", Vector3(c.x + 1.0, y + 1.27, 0.5), Vector3(1.6, 0.14, 1.6), ["bottom"])
	Arch.drum(kit, Arch.frame(Vector3(c.x + 8.5, y, 7.5), Vector3(1, 0, 0.3)), 0.3, 1.0)
	Arch.drum(kit, Arch.frame(Vector3(c.x + 9.8, y, 6.2), Vector3(0.2, 0, 1)), 0.3, 0.8)
	for i in 3:
		# east side: the south-west corner belongs to the potter's workshop
		kit.solid_box("limestone", Vector3(c.x + 11.6, y + 0.25 + i * 0.5, 9.0 - i * 0.1), Vector3(1.2 - i * 0.2, 0.5, 0.8), ["bottom"])
	add_child(kit.build("Agora"))
	for p: Vector3 in cols:
		var wp := stoa_xf * p
		place("column_doric", wp, 0.0, Vector3.ONE, 0.3, COL_H)
	# capital set on the ground among the pieces
	place("column_doric", Vector3(c.x + 7.2, y - 3.2, 8.3), 15.0, Vector3.ONE)
	_stall_goods(stall_pos)
	spawn_inspectable("inscription_stele", Vector3(c.x, y, -2.6), 0.0)
	spawn_inspectable("coin_stater", stall_pos + Vector3(0.4, 0.89, -0.1), 180.0)
	spawn_inspectable("grain_pithos", Vector3(c.x + 2.3, y, 7.6), 200.0)


func _stall_goods(p: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	place("krater", p + Vector3(-0.8, 0.89, 0.0), 30.0, Vector3.ONE * 0.8)
	place("krater", p + Vector3(-0.3, 0.89, 0.15), 80.0, Vector3.ONE * 0.6)
	for i in 4:
		place("amphora", p + Vector3(-1.9 + i * 0.3, 0, -0.9 + (i % 2) * 0.2), rng.randf_range(0, 360), Vector3.ONE, 0.17, 0.8)
	var kit := MeshKit.new()
	for b: Vector3 in [p + Vector3(1.9, 0, -0.4), p + Vector3(2.3, 0, 0.2), p + Vector3(-1.2, 0.89, 0.1)]:
		var r := 0.22 if b.y < p.y + 0.5 else 0.14
		kit.lathe("basket", PackedVector2Array([Vector2(r * 0.7, b.y - p.y), Vector2(r, b.y - p.y + r * 1.1)]), 7,
				Vector3(b.x, p.y, b.z), 2.0, true, "dark", true)
	add_child(kit.build("Baskets"))
