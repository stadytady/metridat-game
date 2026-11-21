class_name TheatrePlay
extends Node3D
## The evening's play in the hill theatre. From dusk (DayCycle.LAMPS_ON: the
## same hour the town lights up, no threshold of its own) a chorus of six in
## masks works the back of the orchestra - a strophe one way round the ring, a
## pause with arms up, the antistrophe back - while Fedr has the middle, and
## people from the town sit along the lower tiers to watch. An aulos and the
## chorus's chant carry from the orchestra. All of it is a clock, not a state:
## where each dancer stands is chorus_at(i, t). No bodies, no talk: the walk past
## the theatre at night goes through them like weather.

const THEATRE := preload("res://scripts/world/theatre.gd")
const SOUND := preload("res://assets/audio/chorus.wav")

const CHORUS := 6
## The chorus keeps to a ring behind the actor's round, its arc facing the seats.
const CHORUS_R := 2.45
## The arc's middle (deg from +x, as the theatre's angles): east, the far side
## of the orchestra from the seats, so they face the audience across it.
const CHORUS_MID := 0.0
const CHORUS_SPREAD := 16.0  # deg between dancers
## One strophe: so many seconds walking round, then a pause with arms raised;
## the antistrophe walks the same way back.
const STROPHE_WALK := 9.0
const STROPHE_HOLD := 3.0
const STROPHE_SWING := 28.0  # deg the whole arc travels round the ring
## Who watches: [tier, angle deg] on the theatre's ring, in the middle of the
## seats; nobody on the very ends, where the torches stand, nor in the middle
## of the front row, where Fedr sits down between his speeches.
const AUDIENCE := [[0, 150.0], [0, 162.0], [0, 198.0], [0, 210.0], [1, 150.0], [1, 166.0], [1, 196.0], [1, 214.0], [2, 176.0]]
const AUDIENCE_LOOKS := [
	{"beard": 2, "hair": 1, "cloth": "chiton_blue"}, {"woman": true, "kerchief": "chiton_dark", "skirt": "long", "cloth": "chiton_ochre"},
	{"beard": 0, "hair": 0, "cloth": "chiton"}, {"beard": 1, "hair": 2, "cloth": "chiton_red"},
	{"woman": true, "kerchief": "cloth", "skirt": "long", "cloth": "chiton_blue"}, {"beard": 2, "hair": 0, "cloth": "chiton_dark"},
	{"beard": 0, "hair": 1, "cloth": "chiton_ochre"}, {"beard": 1, "hair": 1, "cloth": "chiton"},
	{"woman": true, "kerchief": "chiton_red", "skirt": "long", "cloth": "chiton"},
]
## The chorus's dress: one colour, so they read as a body and not as six people.
const CHORUS_LOOK := {"beard": 0, "hair": 1, "cloth": "chiton"}

var _chorus: Array[Dictionary] = []
var _audience: Array[Dictionary] = []
var _sound: AudioStreamPlayer3D
var _atm: Node
var _t := 0.0
var playing := false


func _ready() -> void:
	_atm = get_parent().get_node_or_null("Atmosphere")
	var top := Topo.HILL_PLATFORM_TOP
	for i in CHORUS:
		var root := Node3D.new()
		root.name = "Chorus%d" % i
		add_child(root)
		var j := Figure.build(root, "chiton", CHORUS_LOOK)
		_mask_on(j)
		_chorus.append({"root": root, "joints": j})
	for k in AUDIENCE.size():
		var spec: Array = AUDIENCE[k]
		var root := Node3D.new()
		root.name = "Watcher%d" % k
		var at := seat_at(int(spec[0]), float(spec[1]))
		root.position = Vector3(at.x, top + int(spec[0]) * THEATRE.TIER_RISE, at.y)
		root.rotation.y = face_centre(at)
		add_child(root)
		var j := Figure.build(root, "chiton", AUDIENCE_LOOKS[k % AUDIENCE_LOOKS.size()])
		Figure.apply_pose(j, "sit")
		_audience.append({"root": root, "joints": j})
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = SOUND
	_sound.position = Vector3(THEATRE.CENTER.x, top + 1.5, THEATRE.CENTER.y)
	_sound.unit_size = 7.0
	_sound.max_distance = 48.0
	_sound.volume_db = -6.0
	add_child(_sound)
	step(_hour(), 0.0)


## A mask over the face: the same plate the actor carries, worn.
func _mask_on(j: Dictionary) -> void:
	var k := MeshKit.new()
	k.box("mask", Vector3(0, 0.16, -0.1), Vector3(0.2, 0.25, 0.03), [])
	k.box("dark", Vector3(-0.05, 0.2, -0.117), Vector3(0.05, 0.03, 0.01), [])
	k.box("dark", Vector3(0.05, 0.2, -0.117), Vector3(0.05, 0.03, 0.01), [])
	k.box("dark", Vector3(0, 0.1, -0.117), Vector3(0.08, 0.04, 0.01), [])
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	(j["head"] as Node3D).add_child(mi)


## Where a watcher sits on a tier at an angle: just in from the front edge.
static func seat_at(tier: int, angle_deg: float) -> Vector2:
	var r := THEATRE.INNER_R + tier * THEATRE.TIER_DEPTH + 0.18
	var a := deg_to_rad(angle_deg)
	return THEATRE.CENTER + Vector2(cos(a), sin(a)) * r


## The yaw that turns a figure (it faces local -z) at `p` towards the orchestra.
static func face_centre(p: Vector2) -> float:
	var d := p - THEATRE.CENTER
	return atan2(d.x, d.y)


## How far round the ring the chorus has gone at time t (deg), and whether it
## is walking: out over STROPHE_WALK, hold, back over STROPHE_WALK, hold.
static func strophe(t: float) -> Array:
	var cycle := 2.0 * (STROPHE_WALK + STROPHE_HOLD)
	var u := fposmod(t, cycle)
	if u < STROPHE_WALK:
		return [smoothstep(0.0, 1.0, u / STROPHE_WALK) * STROPHE_SWING, true, 1.0]
	u -= STROPHE_WALK
	if u < STROPHE_HOLD:
		return [STROPHE_SWING, false, 0.0]
	u -= STROPHE_HOLD
	if u < STROPHE_WALK:
		return [(1.0 - smoothstep(0.0, 1.0, u / STROPHE_WALK)) * STROPHE_SWING, true, -1.0]
	return [0.0, false, 0.0]


## Where dancer i stands at time t (x, z), on the ring behind the actor.
static func chorus_at(i: int, t: float) -> Vector2:
	var s: Array = strophe(t)
	var a := deg_to_rad(CHORUS_MID + (i - (CHORUS - 1) / 2.0) * CHORUS_SPREAD - STROPHE_SWING / 2.0 + float(s[0]))
	return THEATRE.CENTER + Vector2(cos(a), sin(a)) * CHORUS_R


## The play is on from dusk until the night is over (not in the dream, nor on
## the evening of the prologue, when the walk has not begun).
static func on_at(hour: float, dreaming := false, prologue := false) -> bool:
	return hour >= DayCycle.LAMPS_ON and hour <= 1.0 and not dreaming and not prologue


func _hour() -> float:
	return float(_atm.t) if _atm != null else Game.time_target()


func _process(delta: float) -> void:
	step(_hour(), delta)


func step(hour: float, delta: float) -> void:
	var on := on_at(hour, Game.dreaming, Game.prologue)
	if on != playing or (_chorus[0]["root"] as Node3D).visible != on:
		playing = on
		for d: Dictionary in _chorus + _audience:
			(d["root"] as Node3D).visible = on
		if on:
			_sound.play(fposmod(_t, SOUND.get_length()))
		else:
			_sound.stop()
	if not on:
		return
	_t += delta
	Game.caption("CAP_CHORUS", _sound.global_position, 30.0)
	var q := floorf(_t * 15.0) / 15.0
	var s: Array = strophe(q)
	var walking: bool = s[1]
	var top := Topo.HILL_PLATFORM_TOP
	for i in CHORUS:
		var d: Dictionary = _chorus[i]
		var p := chorus_at(i, q)
		var root: Node3D = d["root"]
		root.position = Vector3(p.x, top, p.y)
		if walking:
			# along the ring, the way the strophe goes: a tangent to it
			var r := p - THEATRE.CENTER
			var tangent := Vector2(-r.y, r.x) * float(s[2])
			root.rotation.y = atan2(-tangent.x, -tangent.y)
			Figure.apply_pose(d["joints"], "walk", Figure.step_motion(fposmod(q * 0.9, 1.0)))
		else:
			# turned to the seats across the orchestra, both arms up
			root.rotation.y = face_centre(p)
			Figure.apply_pose(d["joints"], "declaim", {"l_shoulder": Vector3(115, 0, 25), "head": Vector3(-6, 0, 0)})
	# the audience is still, but not stone: now and then a head turns
	for k in _audience.size():
		var a: Dictionary = _audience[k]
		var turn := sin(q * 0.31 + k * 1.7)
		(a["joints"]["head"] as Node3D).rotation_degrees.y = turn * 14.0 if absf(turn) > 0.85 else 0.0
