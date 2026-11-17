class_name Scythians
extends District
## The Scythians of the city's life. Panticapaeum lived off the steppe as much as
## off the sea: its rulers were "archons" of the Greek towns and kings of the
## peoples around, and Scythian nobles bought the work of its goldsmiths.
## Here: a trader from the steppe on the agora, in trousers, coat and pointed
## hood, his furs on a hide by the south-east corner and his horse tethered
## beside him; the gold plaques he has come to buy are the find. And out on the
## steppe west of the hill, two horsemen riding the track and back, seen from
## the terrace.

const NPC := preload("res://scripts/npc/npc.gd")

## The trader stands at his hide; the horse is tethered behind him; the find
## (gold plaques for a coat) lies on the hide by his furs.
const TRADER := Vector2(32.4, 7.2)
const HIDE := Vector2(32.4, 8.4)
const HORSE := Vector2(33.6, 9.8)
const PLAQUES := Vector2(31.9, 8.5)
## The track across the steppe: two horsemen ride it end to end and back, a
## little apart, at a walk; near enough to the terrace to be made out through
## the haze (past fifty metres a horseman is a speck at PSX resolution).
## It threads the gap between the two nearest kurgans (Steppe.KURGANS: the mounds
## are built over the terrain, and a horse on Topo.terrain would walk through
## them), up to the foot of the hill and back west.
const TRACK := [Vector2(-150.0, -14.0), Vector2(-130.0, 2.0), Vector2(-110.0, 4.0)]
const RIDERS := 2
const RIDER_GAP := 9.0


func _ready() -> void:
	var y := Topo.AGORA_H
	var kit := MeshKit.new()
	# the hide spread on the paving, furs rolled and piled on it
	kit.box("fur", Vector3(HIDE.x, y + 0.01, HIDE.y), Vector3(1.6, 0.02, 1.1), ["bottom"])
	for f: Array in [[Vector2(0.45, 0.25), 0.18], [Vector2(0.5, -0.2), 0.16], [Vector2(-0.1, -0.3), 0.14]]:
		var o: Vector2 = f[0]
		var h: float = f[1]
		kit.box("fleece", Vector3(HIDE.x + o.x, y + 0.02 + h / 2.0, HIDE.y + o.y), Vector3(0.55, h, 0.3), ["bottom"])
	# a tethering post for the horse
	kit.box("wood", Vector3(HORSE.x - 0.9, y + 0.55, HORSE.y - 0.6), Vector3(0.1, 1.1, 0.1), ["bottom"])
	add_child(kit.build("TraderGoods"))
	_trader(y)
	var horse := Rider.new()
	horse.name = "TraderHorse"
	horse.position = Vector3(HORSE.x, y, HORSE.y)
	horse.rotation.y = deg_to_rad(80.0)  # head towards the post, west
	add_child(horse)
	spawn_inspectable("gold_plaques", Vector3(PLAQUES.x, y + 0.03, PLAQUES.y), 15.0)
	_riders()


func _trader(y: float) -> void:
	var n: Npc = NPC.new()
	n.name = "Trader"
	n.npc_id = "scythian"
	n.name_key = "NPC_SCYTHIAN_NAME"
	n.dialogue = load("res://data/dialogues/scythian.dialogue") as DialogueResource
	n.look = Figure.LOOKS["scythian"]
	n.pose = "stand"
	n.position = Vector3(TRADER.x, y, TRADER.y)
	n.rotation.y = 0.0  # faces -z: out over the square, his back to his goods
	add_child(n)


## The horsemen on the steppe track: the route on the ground, each a little
## behind the other.
static func track_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p: Vector2 in TRACK:
		out.append(Vector3(p.x, Topo.terrain(p.x, p.y), p.y))
	return out


func _riders() -> void:
	for i in RIDERS:
		var r := Rider.new()
		r.name = "Horseman%d" % i
		r.route = track_points()
		r.rider_look = Figure.LOOKS["scythian_rider" if i == 0 else "scythian"]
		r.travelled = float(i) * RIDER_GAP
		r.speed = Rider.WALK
		add_child(r)


func trader() -> Npc:
	return get_node("Trader")
