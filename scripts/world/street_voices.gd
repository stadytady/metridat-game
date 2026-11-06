class_name StreetVoices
extends Node3D
## What is heard through the walls of the back streets: a smith's hammer, a loom
## being beaten, a baby, a yard dog, a woman humming. Each voice is one
## AudioStreamPlayer3D pinned to a house wall and played again and again with a
## pause of its own, seeded by the house, so the lanes are never silent and the
## rhythm never falls into step. Work and song stop at dusk; the dog and the baby
## do not.
##
## The players are placed by a static function so the tests can see exactly what
## the node builds, the same way the goods and the herms are.

const SOUNDS := {
	"hammer": preload("res://assets/audio/hammer.wav"),
	"loom": preload("res://assets/audio/loom.wav"),
	"child_cry": preload("res://assets/audio/child_cry.wav"),
	"bark": preload("res://assets/audio/bark.wav"),
	"hum": preload("res://assets/audio/hum.wav"),
}
## The voices that stop when the lamps come on: nobody beats a loom at midnight.
const BY_DAY := ["hammer", "loom", "hum"]
## One house in this many has something to hear behind its wall.
const EVERY := 7
## How far off the wall the sound sits, and how far it carries.
const OUT := 0.5
const UNIT := 3.0
const REACH := 18.0
const VOLUME := -13.0
## Pause between two playings, seconds: a range, so the city has no metronome.
const GAP := Vector2(4.5, 11.0)

## The houses to hang voices on; set before the node enters the tree.
var houses: Array = []

var _players: Array[AudioStreamPlayer3D] = []
var _kinds: Array[String] = []
var _gaps: Array[float] = []
var _wait: Array[float] = []
var _t := 0.0
var _player: Node3D


## Where each voice is and what it is. A voice hangs on the wall of one house in
## EVERY, at the height of its window, half a metre out into the lane.
## [{pos, kind}]
static func placements(houses: Array) -> Array:
	var out := []
	var kinds: Array = SOUNDS.keys()
	for i in houses.size():
		var hs: Dictionary = houses[i]
		var seed := hash(int(hs.opts.get("seed", 0)) * 13 + 3)
		if posmod(seed, EVERY) != 0:
			continue
		var basis := Basis.from_euler(Vector3(0, hs.yaw, 0))
		var front := Vector3(hs.pos.x, 0, hs.pos.y) + basis * Vector3(0, 0, hs.d / 2.0 + OUT)
		front.y = Topo.terrain(front.x, front.z) + 1.5
		out.append({"pos": front, "kind": kinds[posmod(seed >> 4, kinds.size())]})
	return out


func _ready() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Node3D
	for p: Dictionary in placements(houses):
		var voice := AudioStreamPlayer3D.new()
		voice.name = "Voice_%s" % p.kind
		voice.stream = SOUNDS[p.kind]
		voice.position = p.pos
		voice.volume_db = VOLUME
		voice.unit_size = UNIT
		voice.max_distance = REACH
		add_child(voice)
		_players.append(voice)
		_kinds.append(String(p.kind))
		var seed := hash(p.pos)
		_gaps.append(GAP.x + fposmod(float(seed), 1000.0) / 1000.0 * (GAP.y - GAP.x))
		# not all at once: the first playing is spread over the gap
		_wait.append(fposmod(float(seed >> 7), 1000.0) / 1000.0 * _gaps[-1])
		voice.pitch_scale = 0.94 + fposmod(float(seed >> 11), 100.0) / 100.0 * 0.12


## The voices keep their own time: a voice that is far off the player is not
## started at all, which keeps a walk in the lanes cheap.
func _process(delta: float) -> void:
	_t += delta
	var hour := Game.time_target()
	var quiet := hour >= DayCycle.LAMPS_ON
	for i in _players.size():
		if quiet and BY_DAY.has(_kinds[i]):
			continue
		_wait[i] -= delta
		if _wait[i] > 0.0:
			continue
		if _player != null and _player.global_position.distance_to(_players[i].global_position) > REACH:
			_wait[i] = 0.5
			continue
		_players[i].play()
		_wait[i] = _gaps[i]
