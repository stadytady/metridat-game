class_name Topo
extends RefCounted
## Layout and ground height of the whole slice, in one place. Pure functions:
## terrain, buildings and props all ask here, so nothing floats or sinks.
##
## Axes: +x is east (towards the strait), y is up, sea level is y = 0.
## The hill (acropolis, cf. Mount Mithridates) is in the west, the city steps
## down eastwards to the shore.

const SEA_LEVEL := 0.0

## Street centerline: Vector3(x, height, z). Steep segments get stairs.
const STREET: Array[Vector3] = [
	Vector3(-80, 27.5, 0.0),
	Vector3(-66, 21.5, 1.0),
	Vector3(-62, 21.0, 1.5),
	Vector3(-52, 17.5, -1.0),
	Vector3(-40, 15.5, 0.5),
	Vector3(-30, 12.0, 2.0),
	Vector3(-18, 10.5, 0.5),
	Vector3(-8, 7.0, -1.0),
	Vector3(2, 5.5, 0.0),
	Vector3(9, 5.0, 0.0),
]
const STREET_HALF := 2.2
const STAIR_SLOPE := 0.22

const HILL_CENTER := Vector2(-90, 0)
const HILL_HALF := Vector2(9, 8)
const HILL_H := 27.5
const HILL_PLATFORM_TOP := 28.1

const AGORA_CENTER := Vector2(22, 0)
const AGORA_HALF := Vector2(13, 11)
const AGORA_H := 5.0

const SANCT_CENTER := Vector2(46, -27)
const SANCT_HALF := Vector2(8, 7)
const SANCT_H := 8.5
## Fisherman's camp on the beach below the agora.
const CAMP_CENTER := Vector2(66.5, 14.0)
const CAMP_HALF := Vector2(5.5, 4.0)

## Stair from the agora's north-east corner (past the stoa's end) up to the sanctuary terrace.
const SANCT_STAIR: Array[Vector3] = [Vector3(34, 5.0, -10.5), Vector3(40.5, 8.5, -19.6)]
const SANCT_STAIR_HALF := 1.6

## Ground height along x, before street/plaza pads. Linear between points:
## low-poly creases are part of the look.
const _PROFILE: Array[Vector2] = [
	Vector2(-900, 4), Vector2(-300, 10), Vector2(-160, 18), Vector2(-115, 24), Vector2(-98, 27.5),
	Vector2(-80, 27.5), Vector2(-66, 21.5), Vector2(-62, 21), Vector2(-52, 17.5), Vector2(-40, 15.5), Vector2(-30, 12),
	Vector2(-18, 10.5), Vector2(-8, 7), Vector2(2, 5.5), Vector2(9, 5), Vector2(36, 5),
	Vector2(48, 4.2), Vector2(58, 2.6), Vector2(66, 0.8), Vector2(74, -1.6), Vector2(90, -5),
	Vector2(140, -9), Vector2(2000, -12),
]

static var _noise: FastNoiseLite


static func _n() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 413
		_noise.frequency = 0.012
		_noise.fractal_octaves = 3
	return _noise


static func profile(x: float) -> float:
	for i in _PROFILE.size() - 1:
		var a := _PROFILE[i]
		var b := _PROFILE[i + 1]
		if x <= b.x:
			return lerpf(a.y, b.y, clampf((x - a.x) / (b.x - a.x), 0, 1))
	return _PROFILE[-1].y


## Coastline wobble so the shore is not a straight line.
static func coast_shift(z: float) -> float:
	return 6.0 * sin(z * 0.021) + 4.0 * sin(z * 0.057 + 1.3)


static func natural(x: float, z: float) -> float:
	var shore := smoothstep(25.0, 60.0, x)
	var xs := x - coast_shift(z) * shore
	var h := profile(xs)
	# The city sits in a shallow bowl: ground rises away from the street axis.
	var side := maxf(0.0, absf(z) - 10.0) * 0.07 * (1.0 - smoothstep(40.0, 72.0, xs))
	h += side
	h += 2.0 * exp(-((x + 100.0) ** 2 + z * z) / 700.0)
	var amp := 1.6 if xs < 60.0 else 0.6
	h += _n().get_noise_2d(x, z) * amp * smoothstep(0.0, 14.0, absf(z))
	return h


static func _rect_weight(x: float, z: float, c: Vector2, half: Vector2, falloff: float) -> float:
	var dx := maxf(absf(x - c.x) - half.x, 0.0)
	var dz := maxf(absf(z - c.y) - half.y, 0.0)
	return 1.0 - smoothstep(0.0, falloff, sqrt(dx * dx + dz * dz))


## Returns Vector3(distance, height on the segment, t) for the closest segment point.
static func _segment(x: float, z: float, a: Vector3, b: Vector3) -> Vector3:
	var p := Vector2(x, z)
	var pa := Vector2(a.x, a.z)
	var pb := Vector2(b.x, b.z)
	var ab := pb - pa
	var t := clampf((p - pa).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var q := pa + ab * t
	return Vector3(p.distance_to(q), lerpf(a.y, b.y, t), t)


static func _apply_path(h: float, x: float, z: float, path: Array[Vector3], half: float, falloff: float, sink: float) -> float:
	var best_d := INF
	var best_h := h
	for i in path.size() - 1:
		var s := _segment(x, z, path[i], path[i + 1])
		if s.x < best_d:
			best_d = s.x
			best_h = s.y
	var w := 1.0 - smoothstep(half, half + falloff, best_d)
	return lerpf(h, best_h - sink, w)


## Terrain height (the dirt/grass mesh). Paved areas sit slightly above it.
static func terrain(x: float, z: float) -> float:
	var h := natural(x, z)
	h = lerpf(h, HILL_H - 0.3, _rect_weight(x, z, HILL_CENTER, HILL_HALF, 7.0))
	h = _apply_path(h, x, z, STREET, STREET_HALF + 1.5, 4.0, 0.25)
	h = lerpf(h, AGORA_H - 0.25, _rect_weight(x, z, AGORA_CENTER, AGORA_HALF, 6.0))
	h = _apply_path(h, x, z, SANCT_STAIR, SANCT_STAIR_HALF + 1.0, 2.0, 0.25)
	h = lerpf(h, SANCT_H - 0.25, _rect_weight(x, z, SANCT_CENTER, SANCT_HALF, 3.0))
	return h


## Street centerline height at a given x (the street runs west to east).
static func street_height(x: float) -> float:
	if x <= STREET[0].x:
		return STREET[0].y
	for i in STREET.size() - 1:
		var a := STREET[i]
		var b := STREET[i + 1]
		if x <= b.x:
			return lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
	return STREET[-1].y


static func street_z(x: float) -> float:
	if x <= STREET[0].x:
		return STREET[0].z
	for i in STREET.size() - 1:
		var a := STREET[i]
		var b := STREET[i + 1]
		if x <= b.x:
			return lerpf(a.z, b.z, (x - a.x) / (b.x - a.x))
	return STREET[-1].z


## x where the terrain goes below sea level at this z (first crossing from the
## city side). The sea shader foams along it; Nature's boundary follows it too.
static func waterline_x(z: float) -> float:
	var x := 30.0
	while x < 200.0 and terrain(x, z) > SEA_LEVEL:
		x += 0.5
	# refine between the last dry and first wet sample
	var lo := x - 0.5
	var hi := x
	for i in 8:
		var mid := (lo + hi) * 0.5
		if terrain(mid, z) > SEA_LEVEL:
			lo = mid
		else:
			hi = mid
	return hi


static func in_rect(x: float, z: float, c: Vector2, half: Vector2, margin: float = 0.0) -> bool:
	return absf(x - c.x) <= half.x + margin and absf(z - c.y) <= half.y + margin


## Walkable surface height where props stand: paving if paved, else terrain.
static func surface(x: float, z: float) -> float:
	if in_rect(x, z, AGORA_CENTER, AGORA_HALF):
		return AGORA_H
	if in_rect(x, z, SANCT_CENTER, SANCT_HALF):
		return SANCT_H
	if in_rect(x, z, HILL_CENTER, HILL_HALF - Vector2(1, 1)):
		return HILL_PLATFORM_TOP
	if x >= STREET[0].x and x <= STREET[-1].x and absf(z - street_z(x)) <= STREET_HALF:
		return street_height(x)
	return terrain(x, z)


## Areas the backdrop city must keep clear of.
static func is_reserved(x: float, z: float, margin: float) -> bool:
	if in_rect(x, z, AGORA_CENTER, AGORA_HALF, margin):
		return true
	if in_rect(x, z, SANCT_CENTER, SANCT_HALF, margin):
		return true
	if in_rect(x, z, HILL_CENTER, HILL_HALF, margin + 6.0):
		return true
	if _segment(x, z, SANCT_STAIR[0], SANCT_STAIR[1]).x < SANCT_STAIR_HALF + margin:
		return true
	if x > STREET[0].x - 4 and x < STREET[-1].x + 2 and absf(z - street_z(x)) < 10.0 + margin:
		return true
	return false


static func spawn_point() -> Vector3:
	# Near the east edge of the terrace, so the city is in view below.
	return Vector3(HILL_CENTER.x + HILL_HALF.x - 4.0, HILL_PLATFORM_TOP + 0.1, HILL_CENTER.y)
