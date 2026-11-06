extends District
## Small agora: paved square, stoa with six Doric columns along the north,
## a merchant stall, benches, a statue base and stacked architectural pieces.

const COL_H := 3.6
## The cloth between two columns: how far it stops short of each shaft, how far
## it hangs, and how far in front of the colonnade its top edge is tied.
const BANNER_INSET := 0.35
const BANNER_DROP := 1.25
const BANNER_OUT := 0.42
## Braziers at the corners and lamps by the columns light when the sun is down.
const DUSK := 0.78

## Cloth and flies move on their own clock; everything here is stepped to 15 fps.
var _sway: Array[Node3D] = []
var _flies_nodes: Array[MeshInstance3D] = []
var _fly_centre := Vector3.ZERO
var _t := 0.0
var _night_fires: Array[CornerFire] = []
var _night_on := false
var _atm: Node


func _ready() -> void:
	_atm = get_parent().get_node_or_null("Atmosphere")
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
	# south parapet, with a gap where the footpath leaves for the courtyard house
	var gap0 := Topo.LANE[0].x - Topo.LANE_HALF - 0.2
	var gap1 := Topo.LANE[0].x + Topo.LANE_HALF + 0.2
	for seg: Vector2 in [Vector2(c.x - 3.0, gap0), Vector2(gap1, c.x + 13.0)]:
		kit.solid_box("limestone", Vector3((seg.x + seg.y) / 2.0, y + 0.45, c.y + h.y - 0.3), Vector3(seg.y - seg.x, 0.9, 0.5), ["bottom"])
	for gx: float in [gap0 - 0.25, gap1 + 0.25]:
		kit.solid_box("limestone", Vector3(gx, y + 0.65, c.y + h.y - 0.3), Vector3(0.6, 1.3, 0.6), ["bottom"])  # gate posts
	# stall on the south side, facing the stoa, under red and cream cloth
	var stall_pos := Vector3(c.x - 2.0, y, 6.5)
	Arch.stall(kit, Arch.frame(stall_pos, Vector3.LEFT), ["awning_red", "awning_cream"])
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
	_forecourt(kit)
	add_child(kit.build("Agora"))
	for p: Vector3 in cols:
		var wp := stoa_xf * p
		place("column_doric", wp, 0.0, Vector3.ONE, 0.3, COL_H)
	# capital set on the ground among the pieces
	place("column_doric", Vector3(c.x + 7.2, y - 3.2, 8.3), 15.0, Vector3.ONE)
	_stall_goods(stall_pos)
	_ribbons(cols, stoa_xf)
	_night_fires_at(c, h, y, cols, stoa_xf)
	_steam_pot(stall_pos + Vector3(1.3, 0, 0.7))
	_flies(stall_pos + Vector3(0, 1.5, 0))
	spawn_inspectable("inscription_stele", Vector3(c.x, y, -2.6), 0.0)
	spawn_inspectable("coin_stater", stall_pos + Vector3(0.4, 0.89, -0.1), 180.0)
	spawn_inspectable("grain_pithos", Vector3(c.x + 2.3, y, 7.6), 200.0)


## The forecourt before the agora (Topo.FORECOURTS): paving at the street's
## height in one-metre strips along x (the street falls 0.4 m over the six), a
## kerb down to the earth on the open sides, a collider a little wider than the
## stone so its edge is no trap. The street's own band is left to the street:
## two pavements at one height would flicker.
func _forecourt(kit: MeshKit) -> void:
	var band := Topo.STREET_HALF
	for r: Rect2 in Topo.FORECOURTS:
		# the part of the rect off the street, north or south of it
		var z0 := r.position.y
		var z1 := r.end.y
		if z0 < 0.0 and z1 > -band:
			z1 = -band
		if z0 < band and z1 > 0.0:
			z0 = band
		var x := r.position.x
		while x < r.end.x - 0.001:
			var x1 := minf(x + 1.0, r.end.x)
			var h0 := Topo.forecourt_height(x)
			var h1 := Topo.forecourt_height(x1)
			kit.quad("paving", Vector3(x, h0, z1), Vector3(x1, h1, z1), Vector3(x1, h1, z0), Vector3(x, h0, z0))
			var hm := (h0 + h1) / 2.0
			kit.add_collider(Vector3((x + x1) / 2.0, hm - 0.15, (z0 + z1) / 2.0), Vector3(x1 - x, 0.3, z1 - z0 + 0.6))
			# kerbs where the stone meets the earth: the far edge, and the west end
			var far := z0 if z0 < 0.0 else z1
			var drop := 0.45
			# counter-clockwise from outside: north faces -z, south faces +z
			if z0 < 0.0:
				kit.quad("limestone", Vector3(x, h0, far), Vector3(x1, h1, far), Vector3(x1, h1 - drop, far), Vector3(x, h0 - drop, far))
			else:
				kit.quad("limestone", Vector3(x1, h1, far), Vector3(x, h0, far), Vector3(x, h0 - drop, far), Vector3(x1, h1 - drop, far))
			x = x1
		var w := r.position.x
		var hw := Topo.forecourt_height(w)
		kit.quad("limestone", Vector3(w, hw, z1), Vector3(w, hw, z0), Vector3(w, hw - 0.45, z0), Vector3(w, hw - 0.45, z1))  # faces -x
		kit.add_collider(Vector3(w - 0.3, hw - 0.15, (z0 + z1) / 2.0), Vector3(0.6, 0.3, z1 - z0))
	# a stone bench under the stoa's west end
	var by := Topo.forecourt_height(6.0)
	Arch.bench(kit, Arch.frame(Vector3(6.0, by, -9.6), Vector3.BACK), 2.6)
	kit.xform = Transform3D.IDENTITY


## Ribbons off the column capitals and a cloth hung between two of them: the
## square is never quite still, even when nobody is walking across it.
func _ribbons(cols: Array, xf: Transform3D) -> void:
	var palette := ["ribbon", "awning_blue", "awning_cream"]
	for i in cols.size():
		var p: Vector3 = xf * (cols[i] as Vector3)
		for k in 2:
			var pivot := Node3D.new()
			# clear of the shaft: the column is a 0.3 m radius of stone
			pivot.position = p + Vector3(0, COL_H - 0.15, 0.40 + k * 0.10)
			var kit := MeshKit.new()
			kit.box(palette[(i + k) % palette.size()], Vector3(0, -0.45, 0), Vector3(0.07, 0.90, 0.02), [])
			pivot.add_child(kit.build("Ribbon"))
			add_child(pivot)
			_sway.append(pivot)
	add_child(banner(xf * (cols[2] as Vector3), xf * (cols[3] as Vector3)))


## The cloth between two columns: tied along its top edge, just in front of the
## shafts, and left to the wind below. It no longer swings as a stiff board on a
## pivot (its corners went into the columns); the psx_banner material moves the
## hem, so the mesh is cut fine enough to bend. UV x runs along the top, y from
## the tied edge (0) to the hem (1), on both faces alike.
static func banner(a: Vector3, b: Vector3) -> MeshInstance3D:
	var mid := (a + b) / 2.0
	var half := a.distance_to(b) / 2.0 - BANNER_INSET
	var kit := MeshKit.new()
	kit.max_edge = 0.3
	var front := PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	var back := PackedVector2Array([Vector2(1, 1), Vector2(0, 1), Vector2(0, 0), Vector2(1, 0)])
	kit.quad("banner_red", Vector3(-half, -BANNER_DROP, 0), Vector3(half, -BANNER_DROP, 0), Vector3(half, 0, 0), Vector3(-half, 0, 0), front)
	kit.quad("banner_red", Vector3(half, -BANNER_DROP, 0), Vector3(-half, -BANNER_DROP, 0), Vector3(-half, 0, 0), Vector3(half, 0, 0), back)
	var mi := MeshInstance3D.new()
	mi.name = "Cloth"
	mi.mesh = kit.commit()
	mi.position = Vector3(mid.x, mid.y + COL_H - 0.15, mid.z + BANNER_OUT)
	# the hem blows out by up to swell + ripple: let it, without culling it away
	mi.extra_cull_margin = 0.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the pole it is tied to, from shaft to shaft (a column is 0.3 m of stone)
	var pole := MeshKit.new()
	var reach := a.distance_to(b) / 2.0 - 0.28
	pole.box("wood", Vector3(0, 0.025, 0), Vector3(reach * 2.0, 0.05, 0.05), [])
	var pm := MeshInstance3D.new()
	pm.name = "Pole"
	pm.mesh = pole.commit()
	mi.add_child(pm)
	return mi


## The hem's offset out of the cloth's plane (metres, along its local z) at a
## point (uv) and time; the psx_banner shader computes the same.
static func banner_offset(uv: Vector2, t: float, swell := 0.32, ripple := 0.04, speed := 1.3) -> float:
	var hang := pow(clampf(uv.y, 0.0, 1.0), 1.3)
	var gust := 0.6 + 0.4 * sin(t * speed + uv.x * 2.5)
	return hang * (swell * gust + ripple * sin(uv.x * 8.0 + t * speed * 2.1))


## A pot of something hot by the stall, with steam coming off it.
func _steam_pot(pos: Vector3) -> void:
	place("pithos", pos, 0.0, Vector3.ONE * 0.45)
	add_child(_steam(pos + Vector3(0, 0.55, 0)))


func _steam(pos: Vector3) -> GPUParticles3D:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.92, 0.9, 0.86, 0.45))
	grad.set_color(1, Color(0.92, 0.9, 0.86, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	ramp.width = 8
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 8.0
	pm.initial_velocity_min = 0.18
	pm.initial_velocity_max = 0.32
	pm.gravity = Vector3(0, 0.12, 0)
	pm.color_ramp = ramp
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	quad.material = mat
	var p := GPUParticles3D.new()
	p.amount = 8
	p.lifetime = 2.0
	p.fixed_fps = 15
	p.process_material = pm
	p.draw_pass_1 = quad
	p.emitting = true
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = pos
	return p


## Flies over the wares: three specks that never settle.
func _flies(centre: Vector3) -> void:
	_fly_centre = centre
	for i in 4:
		var kit := MeshKit.new()
		kit.box("dark", Vector3.ZERO, Vector3(0.035, 0.035, 0.035), [])
		var m := MeshInstance3D.new()
		m.mesh = kit.commit()
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		_flies_nodes.append(m)


## Braziers at the four corners of the paving and a lamp beside each column: they
## wait for dusk, then take fire together, the way the theatre answers its lamps.
func _night_fires_at(c: Vector2, h: Vector2, y: float, cols: Array, xf: Transform3D) -> void:
	for p: Vector2 in [Vector2(c.x - h.x + 1.4, c.y - h.y + 1.4), Vector2(c.x + h.x - 1.4, c.y - h.y + 1.4),
			Vector2(c.x - h.x + 1.4, c.y + h.y - 1.4), Vector2(c.x + h.x - 1.4, c.y + h.y - 1.4)]:
		_fire(Vector3(p.x, y, p.y), "torch_post", false)
	for i in cols.size():
		var p: Vector3 = xf * (cols[i] as Vector3)
		_fire(p + Vector3(0, 0, 0.55), "lampstand", true)


func _fire(pos: Vector3, kind: String, quiet: bool) -> void:
	var f := CornerFire.new()
	f.kind = kind
	f.quiet = quiet
	f.position = pos
	add_child(f)
	f.add_to_group(&"night_fire")
	_night_fires.append(f)


## Wind and flies at 15 fps, the clock the rest of the city moves on.
func _process(delta: float) -> void:
	_t += delta
	var q := floorf(_t * 15.0) / 15.0
	for i in _sway.size():
		var n := _sway[i]
		n.rotation.z = sin(q * 1.7 + i * 1.3) * 0.10
		n.rotation.x = sin(q * 1.1 + i * 0.7) * 0.05
	for i in _flies_nodes.size():
		var a := q * 2.4 + i * 2.1
		_flies_nodes[i].position = _fly_centre + Vector3(cos(a) * 0.45, sin(q * 5.0 + i) * 0.1 + i * 0.04, sin(a) * 0.35)
	var on: bool = _atm != null and _atm.t >= DUSK
	if on != _night_on:
		_night_on = on
		for f in _night_fires:
			f.set_lit(on)


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
