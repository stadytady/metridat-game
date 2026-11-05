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
