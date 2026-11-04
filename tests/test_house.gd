extends "res://tests/test_case.gd"
## The walk-in house: its floor and footpath take their height from Topo with
## the ground sunk under them, its doorways are open, and the footpath meets
## the gap in the agora's south parapet.

const H := preload("res://scripts/world/house.gd")


func _in_wall(p: Vector2) -> bool:
	for w: Array in H.walls():
		var c: Vector3 = w[0]
		var size: Vector3 = w[1]
		if absf(p.x - c.x) < size.x / 2.0 + 0.3 and absf(p.y - c.z) < size.z / 2.0 + 0.3:
			return true
	return false


func test_floor_and_path_heights_from_topo() -> void:
	for p: Vector2 in [Topo.HOUSE_CENTER, Topo.HOUSE_CENTER + Topo.HOUSE_HALF * 0.8, Vector2(26.0, 13.0), Vector2(26.0, 11.0)]:
		check(absf(Topo.surface(p.x, p.y) - Topo.HOUSE_H) < 0.01, "floor at %s is %.2f" % [p, Topo.surface(p.x, p.y)])
		check(Topo.terrain(p.x, p.y) < Topo.HOUSE_H - 0.1, "ground pokes through the floor at %s" % p)


func test_doorways_are_open() -> void:
	var z0 := H.bounds().position.y + H.WALL_T / 2.0
	for dz: float in [-0.5, 0.0, 0.5]:
		check(not _in_wall(Vector2(H.STREET_DOOR_X, z0 + dz)), "street door blocked at z %.1f" % (z0 + dz))
		for x: float in H.ROOM_DOORS:
			check(not _in_wall(Vector2(x, H.RANGE_Z + dz)), "room door at x %.1f blocked" % x)
	check(_in_wall(Vector2(H.STREET_DOOR_X + H.DOOR_W, z0)), "no wall beside the street door")


func test_rooms_closed_except_doors() -> void:
	# a point inside each room cannot see the courtyard except through its door
	for x: float in [21.0, 24.6, 27.2, 31.2]:
		check(_in_wall(Vector2(x, H.RANGE_Z)), "front wall missing at x %.1f" % x)


func test_footpath_meets_the_agora_gap() -> void:
	check(absf(Topo.LANE[0].x - H.STREET_DOOR_X) < 0.01, "path misses the street door")
	check(Topo.LANE[0].z < Topo.AGORA_CENTER.y + Topo.AGORA_HALF.y, "path stops short of the agora")
	check(Topo.LANE[1].z > H.bounds().position.y, "path stops short of the house")
