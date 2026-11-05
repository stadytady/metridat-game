extends District
## A wooden pier out into the strait north of the fisherman's camp, with a
## merchant ship moored alongside and her crew: the skipper, who talks, a
## sailor carrying an amphora up the gangway and another sitting on the edge
## of the deck splicing a rope. Amphorae and sacks wait on the planks. A
## lantern is hung at the pier's end at dusk, as on the ships at anchor.

const NPC := preload("res://scripts/npc/npc.gd")

## The ship lies along the pier's south side, bow out to sea.
const SHIP_GAP := 3.7  # the hull is 2.4 m either side of the keel, the yard about 3.5
## The hull rides low, like a laden merchantman: keel under the sea, rail well
## above it. The model's own floor is its bottom, so a laid deck goes over it at
## DECK_Y: the boat sits in the water and still stays dry inside.
const WATERLINE := 0.0
const DECK_Y := 0.9
## The model's keel, from its mesh bounds: the test keeps it under the sea.
const HULL_BOTTOM := -0.67
const LANTERN_FROM := 0.8

var _ship: Node3D
var _lantern: OmniLight3D
var _flame: MeshInstance3D
var _atm: Node
var _t := 0.0


static func ship_pos() -> Vector3:
	return Vector3(Topo.pier_x1() - 9.0, WATERLINE, Topo.PIER_Z - Topo.PIER_HALF - SHIP_GAP)


## Where the skipper stands: by the gangway, facing the land.
static func skipper_pos() -> Vector3:
	return Vector3(ship_pos().x + 3.6, Topo.PIER_H, Topo.PIER_Z - 0.5)


func _ready() -> void:
	_atm = get_parent().get_node_or_null("Atmosphere")
	var kit := MeshKit.new()
	_pier(kit)
	_cargo(kit)
	add_child(kit.build("Pier"))
	_ship = place("ship", ship_pos(), 0.0)
	for g: GeometryInstance3D in _ship.find_children("*", "GeometryInstance3D", true, false):
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	laid_ship_deck(_ship)
	_gangway()
	_crew()
	_end_lantern()



func _pier(kit: MeshKit) -> void:
	var x0 := Topo.pier_x0()
	var x1 := Topo.pier_x1()
	var z := Topo.PIER_Z
	var h := Topo.PIER_HALF
	var y := Topo.PIER_H
	kit.solid_box("wood", Vector3((x0 + x1) / 2.0, y - 0.1, z), Vector3(x1 - x0, 0.2, h * 2.0), [])
	# stringers along the sides, a little proud of the planks
	for s: float in [-1.0, 1.0]:
		kit.box("bark", Vector3((x0 + x1) / 2.0, y - 0.15, z + s * (h - 0.05)), Vector3(x1 - x0, 0.22, 0.14), [])
	# piles every 2.5 m, driven into the sand or the sea bed
	var x := x0 + 0.4
	while x < x1:
		for s: float in [-1.0, 1.0]:
			var bottom := minf(Topo.terrain(x, z + s * h), -0.5) - 1.5
			kit.lathe("bark", PackedVector2Array([Vector2(0.13, bottom - y), Vector2(0.12, 0.05)]), 6,
					Vector3(x, y, z + s * (h + 0.05)), 1.0, false, "wood", true)
		x += 2.5
	# bollards at the end, for the ship's lines
	for bx: float in [ship_pos().x - 5.5, ship_pos().x + 6.0]:
		kit.lathe("wood", PackedVector2Array([Vector2(0.14, 0.0), Vector2(0.12, 0.35), Vector2(0.17, 0.42)]), 7,
				Vector3(bx, y, z - h + 0.25), 1.0, false, "wood", true)
		kit.add_collider(Vector3(bx, y + 0.2, z - h + 0.25), Vector3(0.34, 0.4, 0.34))
		# the mooring line down to the ship's rail
		var a := Vector3(bx, y + 0.35, z - h + 0.25)
		var b := Vector3(bx + (0.8 if bx > ship_pos().x else -0.8), ship_pos().y + 2.4, ship_pos().z + 0.9)
		kit.xform = Transform3D(Basis.looking_at(b - a, Vector3.UP), (a + b) / 2.0)
		kit.box("cloth", Vector3.ZERO, Vector3(0.04, 0.04, a.distance_to(b)), [])
		kit.xform = Transform3D.IDENTITY


## Cargo waiting on the planks: a rack of amphorae, sacks of grain, a coil of rope.
func _cargo(kit: MeshKit) -> void:
	var y := Topo.PIER_H
	var z := Topo.PIER_Z
	var base := ship_pos().x - 2.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 520
	for i in 4:
		var p := Vector3(base - 1.2 - i * 0.5, y, z + Topo.PIER_HALF - 0.45)
		kit.blob("cloth", p + Vector3(0, 0.2, 0), Vector3(0.28, 0.22, 0.24), 0.2, rng)  # sacks
	kit.add_collider(Vector3(base - 1.95, y + 0.2, z + Topo.PIER_HALF - 0.45), Vector3(2.2, 0.4, 0.55))
	var coil := Vector3(base + 3.0, y, z + 0.7)
	for i in 3:
		kit.lathe("basket", PackedVector2Array([Vector2(0.3 - i * 0.05, i * 0.05), Vector2(0.3 - i * 0.05, i * 0.05 + 0.05)]), 9,
				coil, 3.0, false, "dark", i == 2)
	for i in 5:
		var a := Vector3(base + 0.4 * i - 0.6, y, z + Topo.PIER_HALF - 0.4)
		place("amphora", a, rng.randf_range(0, 360), Vector3.ONE * 0.9)
	kit.add_collider(Vector3(base + 0.2, y + 0.4, z + Topo.PIER_HALF - 0.4), Vector3(2.2, 0.8, 0.5))
	# two laid on their sides, ready to go aboard
	for i in 2:
		var lying := place("amphora", Vector3(base + 1.6 + i * 0.45, y + 0.18, z - 0.1), 0.0, Vector3.ONE * 0.9)
		lying.rotate_object_local(Vector3.RIGHT, PI / 2.0)


## A plank from the pier's edge to the ship's foredeck.
func _gangway() -> void:
	var a := Vector3(ship_pos().x + 5.4, Topo.PIER_H + 0.02, Topo.PIER_Z - Topo.PIER_HALF + 0.3)
	var b := Vector3(ship_pos().x + 5.4, ship_pos().y + 2.27, ship_pos().z + 0.4)
	var kit := MeshKit.new()
	kit.xform = Transform3D(Basis.looking_at(b - a, Vector3.UP), (a + b) / 2.0)
	kit.box("wood", Vector3.ZERO, Vector3(0.55, 0.06, a.distance_to(b) + 0.2), [])
	for i in 4:
		kit.box("bark", Vector3(0, 0.04, -a.distance_to(b) / 2.0 + 0.3 + i * 0.45), Vector3(0.55, 0.03, 0.05), [])  # cleats
	kit.xform = Transform3D.IDENTITY
	add_child(kit.build("Gangway"))


func _crew() -> void:
	var skipper: Npc = NPC.new()
	skipper.npc_id = "sailor"
	skipper.name_key = "NPC_SAILOR_NAME"
	skipper.dialogue = load("res://data/dialogues/sailor.dialogue") as DialogueResource
	skipper.body_mat = "cloth"
	skipper.position = skipper_pos()
	skipper.rotation.y = deg_to_rad(90.0)  # faces -x, the land
	add_child(skipper)
	# a felt cap
	var cap := MeshKit.new()
	cap.box("bark", Vector3(0, 0.25, 0), Vector3(0.22, 0.08, 0.24), [])
	cap.box("bark", Vector3(0, 0.31, 0), Vector3(0.15, 0.06, 0.17), [])
	var cm := MeshInstance3D.new()
	cm.mesh = cap.commit()
	(skipper.joints["head"] as Node3D).add_child(cm)
	# carrying an amphora to the gangway
	var carrier: Npc = NPC.new()
	carrier.npc_id = "carrier"
	carrier.name_key = "NPC_SAILOR_NAME"
	carrier.pose = "carry"
	carrier.body_mat = "chiton_dark"
	carrier.talkable = false
	carrier.position = Vector3(ship_pos().x + 5.4, Topo.PIER_H, Topo.PIER_Z + 0.2)
	carrier.rotation.y = 0.0  # faces -z, the ship
	add_child(carrier)
	var jar := Props.instance("amphora")
	jar.position = Vector3(0, 0.05, -0.32)
	jar.scale = Vector3.ONE * 0.75
	(carrier.joints["chest"] as Node3D).add_child(jar)
	# sitting on the edge, legs over the water, splicing a rope
	var splicer: Npc = NPC.new()
	splicer.npc_id = "splicer"
	splicer.name_key = "NPC_SAILOR_NAME"
	splicer.pose = "mender"
	splicer.body_mat = "chiton"
	splicer.talkable = false
	splicer.position = Vector3(ship_pos().x + 1.5, Topo.PIER_H - Figure.SEAT["mender"] + 0.05, Topo.PIER_Z + Topo.PIER_HALF - 0.1)
	splicer.rotation.y = PI  # faces +z, the open water
	add_child(splicer)


func _end_lantern() -> void:
	var p := Vector3(Topo.pier_x1() - 0.3, Topo.PIER_H, Topo.PIER_Z + Topo.PIER_HALF - 0.2)
	var kit := MeshKit.new()
	kit.solid_box("wood", p + Vector3(0, 0.9, 0), Vector3(0.12, 1.8, 0.12), ["bottom"])
	kit.box("wood", p + Vector3(-0.25, 1.75, 0), Vector3(0.5, 0.06, 0.06), [])
	add_child(kit.build("LanternPost"))
	_lantern = OmniLight3D.new()
	_lantern.position = p + Vector3(-0.45, 1.55, 0)
	_lantern.light_color = Color(1, 0.62, 0.3)
	_lantern.omni_range = 8.0
	_lantern.set_script(preload("res://scripts/world/flicker.gd"))
	_lantern.base_energy = 1.3
	_lantern.amount = 0.3
	add_child(_lantern)
	var fk := MeshKit.new()
	fk.box("flame", Vector3.ZERO, Vector3(0.18, 0.24, 0.18), [])
	_flame = MeshInstance3D.new()
	_flame.mesh = fk.commit()
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lantern.add_child(_flame)


func _process(delta: float) -> void:
	_t += delta
	# moored, she still rides the swell: heave in full, her lines check the rolling
	var f := Sea.float_pose(ship_pos(), 0.0, 7.0, 2.2)
	_ship.position.y = WATERLINE + f.x
	_ship.rotation = Vector3(f.y * 0.5, 0.0, f.z * 0.5)
	var hour: float = _atm.t if _atm else 0.0
	_lantern.visible = hour >= LANTERN_FROM
