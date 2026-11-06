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

## The householder reads as a woman from behind as well as from the front: her
## look puts hair and a kerchief on the head and a chiton to the ground on the
## hips, built with the figure, not boxes stuck on afterwards.
func test_a_woman_wears_hair_and_a_skirt() -> void:
	var root := Node3D.new()
	var joints := Figure.build(root, "chiton", Figure.look_for("cottage_woman"))
	var head := _materials(joints["head"])
	var hips := _materials(joints["pelvis"])
	check(head.has("hair"), "she has no hair: %s" % [head])
	check(head.has("chiton_dark"), "she has no kerchief: %s" % [head])
	check(hips.has("hem"), "her chiton does not reach a hem: %s" % [hips])
	for j: Node3D in [joints["head"], joints["pelvis"]]:
		check(j.find_children("*", "MeshInstance3D", false, false).size() == 1, "%s carries extra pieces stuck on" % j.name)
	root.free()


func _materials(joint: Node3D) -> Array[String]:
	var out: Array[String] = []
	for mi: MeshInstance3D in joint.find_children("*", "MeshInstance3D", false, false):
		for i in mi.mesh.get_surface_count():
			out.append(mi.mesh.surface_get_material(i).resource_name)
	return out


## The steps outside the door belong to the house, not to the sky: every tread sits
## between the threshold and a stride below it.
func test_the_steps_stay_at_the_door() -> void:
	var kit := MeshKit.new()
	var info := ARCH.cottage(kit, Transform3D.IDENTITY, 6.0, 7.0, 3.5, {"drop": 1.0})
	var floor_y: float = info["floor"]
	for step: float in info["steps"]:
		check(step < floor_y, "a tread stands above the floor at %.2f" % step)
		check(step > floor_y - 1.2, "a tread hangs %.2f below the threshold" % (floor_y - step))