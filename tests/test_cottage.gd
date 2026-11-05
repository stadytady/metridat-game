extends "res://tests/test_case.gd"
## The cottage by the sea: the front wall is split by a doorway and still adds up
## to the house's width, the door is tall enough to walk through, and its lamp
## lights at dusk like the rest of the town.

const ARCH := preload("res://scripts/world/arch.gd")


func test_cottage_doorway_leaves_a_gap_in_the_front_wall() -> void:
	for w: float in [4.2, 5.0, 6.0, 7.5]:
		var segs: Array = ARCH.cottage_front_segments(w)
		check(segs.size() == 2, "w %.1f gives %d wall segments" % [w, segs.size()])
		if segs.size() != 2:
			continue
		var gap: float = (segs[1] as Vector2).x - (segs[0] as Vector2).y
		check(is_equal_approx(gap, ARCH.COTTAGE_DOOR), "w %.1f leaves a %.2f m door" % [w, gap])
		var total: float = ((segs[0] as Vector2).y - (segs[0] as Vector2).x) + gap
		total += (segs[1] as Vector2).y - (segs[1] as Vector2).x
		check(is_equal_approx(total, w), "the front wall adds up to %.2f of %.2f" % [total, w])
	check(ARCH.COTTAGE_DOOR_H >= 1.9, "the door is only %.2f m tall" % ARCH.COTTAGE_DOOR_H)
	check(ARCH.COTTAGE_DOOR >= 1.0, "the door is only %.2f m wide" % ARCH.COTTAGE_DOOR)


func test_wall_lamp_lights_after_the_sun_is_down() -> void:
	check(WallLamp.DUSK > 0.5 and WallLamp.DUSK < 0.95, "a lamp would light at %.2f" % WallLamp.DUSK)


## The room floor sits a hair above the plinth: two faces at one height flicker.
func test_room_floor_is_above_the_plinth() -> void:
	var kit := MeshKit.new()
	var info := ARCH.cottage(kit, Transform3D.IDENTITY, 6.0, 7.0, 3.5, {"drop": 1.0})
	check(info["floor"] > 0.75, "the floor is level with the plinth at %.2f" % info["floor"])
	check(info["floor"] < 0.9, "the floor is a step, not a threshold: %.2f" % info["floor"])


## Whoever stands in the room stands on the floor, inside the walls.
func test_the_householder_stands_inside_on_the_floor() -> void:
	var kit := MeshKit.new()
	var info := ARCH.cottage(kit, Transform3D.IDENTITY, 6.0, 7.0, 3.5, {"drop": 1.0})
	var woman: Vector3 = info["woman"]
	var inside: Rect2 = info["inside"]
	check(is_equal_approx(woman.y, info["floor"]), "the woman stands at %.2f, the floor at %.2f" % [woman.y, info["floor"]])
	check(inside.has_point(Vector2(woman.x, woman.z)), "the woman stands in the wall at %s" % woman)

## The householder reads as a woman from behind as well as from the front: hair
## down the back under a kerchief, and a skirt over the legs.
func test_a_woman_wears_hair_and_a_skirt() -> void:
	var root := Node3D.new()
	var joints := Figure.build(root, "chiton_dark")
	var head: Node3D = joints["head"]
	var pelvis: Node3D = joints["pelvis"]
	var head_before := head.get_child_count()
	var pelvis_before := pelvis.get_child_count()
	Figure.dress_woman(joints)
	check(head.get_child_count() > head_before, "nothing was added to the head")
	check(pelvis.get_child_count() > pelvis_before, "nothing was added to the hips")
	root.free()