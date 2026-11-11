extends Node3D
## Scene root of the slice. Child nodes build themselves; this only places the
## player and exposes named viewpoints for tests and screenshots.

@onready var player: CharacterBody3D = $Player


const ZONE := preload("res://scripts/world/zone.gd")


func _ready() -> void:
	player.global_position = Topo.spawn_point()
	player.rotation.y = deg_to_rad(-90.0)  # face east, towards the strait
	player._ready()
	player.look_at_point(Vector3(20, 6, 0))
	_zone("LOC_HILL", Topo.HILL_CENTER, Topo.HILL_HALF, Topo.HILL_PLATFORM_TOP)
	_zone("LOC_STREET", Vector2(-35, 0.5), Vector2(28, 4), 16.0, 30.0)
	_zone("LOC_AGORA", Topo.AGORA_CENTER, Topo.AGORA_HALF - Vector2(1, 1), Topo.AGORA_H)
	_zone("LOC_SANCTUARY", Topo.SANCT_CENTER, Topo.SANCT_HALF, Topo.SANCT_H)
	_zone("LOC_SHORE", Vector2(64, 0), Vector2(6, 75), 1.0, 12.0)


func _zone(title: String, c: Vector2, half: Vector2, y: float, h: float = 6.0) -> void:
	var a := Area3D.new()
	a.set_script(ZONE)
	a.title = title
	a.name = "Zone_" + title
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(half.x * 2, h, half.y * 2)
	cs.shape = sh
	a.position = Vector3(c.x, y + h / 2.0 - 1.0, c.y)
	a.add_child(cs)
	add_child(a)


## name -> [eye position, look-at point]
static func viewpoints() -> Dictionary:
	var sp := Topo.spawn_point()
	var roof: Vector3 = load("res://scripts/world/backdrop.gd").wall_towers()[2]  # north wall, x = -30
	return {
		"hill": [sp + Vector3(0, 1.6, 0), Vector3(20, 6, 0)],
		"hill_wide": [sp + Vector3(-2, 2.5, 6), Vector3(60, -6, -10)],
		"street": [Vector3(-44, Topo.street_height(-44) + 1.6, Topo.street_z(-44)), Vector3(-10, 8, 0)],
		"street_up": [Vector3(-12, Topo.street_height(-12) + 1.6, Topo.street_z(-12)), Vector3(-60, 22, 0)],
		"agora": [Vector3(11, Topo.AGORA_H + 1.6, 6), Vector3(30, 6, -8)],
		"knucklebones": [Vector3(27.6, Topo.AGORA_H + 1.7, 1.6), Vector3(26.0, Topo.AGORA_H + 0.35, -0.8)],
		"workshop": [Vector3(14.6, Topo.AGORA_H + 1.6, 5.6), Vector3(13.0, Topo.AGORA_H + 0.7, 9.4)],
		"fishing": [Vector3(61.5, Topo.terrain(61.5, 13.2) + 1.6, 13.2), Vector3(67.5, 1.2, 15.2)],
		"theatre": [Vector3(-85.0, Topo.HILL_PLATFORM_TOP + 1.6, 3.0), Vector3(-93.0, Topo.HILL_PLATFORM_TOP + 0.4, -0.5)],
		"masks": [Vector3(-86.9, Topo.HILL_PLATFORM_TOP + 1.3, 2.2), Vector3(-88.6, Topo.HILL_PLATFORM_TOP + 1.05, 3.9)],
		"park": [Vector3(-77.0, Topo.terrain(-77.0, 19.0) + 1.7, 19.0), Vector3(-98.4, Topo.terrain(-98.4, 19.0) + 1.6, 19.0)],
		"park_goddess": [Vector3(-93.5, Topo.terrain(-93.5, 19.0) + 1.6, 19.0), Vector3(-98.4, Topo.terrain(-98.4, 19.0) + 2.3, 19.0)],
		"park_south": [Vector3(-85.0, Topo.terrain(-85.0, -34.0) + 3.5, -34.0), Vector3(-85.0, Topo.terrain(-85.0, -19.0) + 0.5, -14.0)],
		# the back lanes: the corner where the -28 terrace meets the 37 lane, with
		# the herm that marks it; look along the street, not into a wall
		"side_street": [Vector3(-26.65, Topo.terrain(-26.65, 32.6) + 1.7, 32.6), Vector3(-26.65, Topo.terrain(-26.65, 38.6) + 1.0, 38.6)],
		"house_lane": [Vector3(26.0, Topo.AGORA_H + 1.6, 5.0), Vector3(26.0, Topo.AGORA_H + 1.4, 18.0)],
		"house_yard": [Vector3(25.6, Topo.HOUSE_H + 1.6, 16.0), Vector3(29.4, Topo.HOUSE_H + 0.5, 19.0)],
		"house_room": [Vector3(25.6, Topo.HOUSE_H + 1.6, 22.9), Vector3(20.6, Topo.HOUSE_H + 0.4, 25.4)],
		"house_loom": [Vector3(27.0, Topo.HOUSE_H + 1.6, 22.8), Vector3(29.2, Topo.HOUSE_H + 1.1, 26.2)],
		"pier": [Vector3(Topo.pier_x0() - 2.0, Topo.terrain(Topo.pier_x0() - 2.0, Topo.PIER_Z + 3.0) + 1.6, Topo.PIER_Z + 3.0),
			Vector3(Topo.pier_x1() - 5.0, 1.6, Topo.PIER_Z - 2.0)],
		"skipper": [Vector3(Topo.pier_x1() - 8.5, Topo.PIER_H + 1.6, Topo.PIER_Z + 0.6), Vector3(Topo.pier_x1() - 5.4, Topo.PIER_H + 1.1, Topo.PIER_Z - 0.5)],
		"actor": [Vector3(-88.4, Topo.HILL_PLATFORM_TOP + 1.6, -0.8), Vector3(-90.6, Topo.HILL_PLATFORM_TOP + 1.2, 0.3)],
		"chickens": [Vector3(12.2, Topo.AGORA_H + 1.3, 3.2), Vector3(15.4, Topo.AGORA_H + 0.2, 5.8)],
		"sacred_way": [Vector3(29.0, Topo.AGORA_H + 1.6, 3.5), Vector3(35.5, 7.2, -12.0)],
		"dream": [Vector3(0, 61.6, 2601), Vector3(0, 61.2, 2620)],
		"prologue": [Prologue.arrival_point() + Vector3(0, 1.6, 0), load("res://scripts/world/harbour.gd").skipper_pos() + Vector3(0, 1.45, 0)],
		"dream_mound": [Vector3(1.0, 61.7, 2668), Vector3(0, 61.5, 2680)],
		"dream_stair": [preload("res://scripts/world/dream.gd").ORIGIN + Vector3(0, 1.6, preload("res://scripts/world/dream.gd").DOOR_Z + 0.3), preload("res://scripts/world/dream.gd").ORIGIN + Vector3(0, -preload("res://scripts/world/dream.gd").DEPTH + 0.8, preload("res://scripts/world/dream.gd").stair_end())],
		"dream_tomb": [preload("res://scripts/world/dream.gd").ORIGIN + preload("res://scripts/world/dream.gd").chamber_center() + Vector3(-0.9, 1.6, -1.7), preload("res://scripts/world/dream.gd").ORIGIN + preload("res://scripts/world/dream.gd").chamber_center() + Vector3(0, 0.6, 0.9)],
		# the night watch on the town wall: the north wall from the park's edge, and a
		# sentry on his roof (tools/shots.sh DIR --only=watch,watch_roof --time=1)
		"watch": [Vector3(-80.0, Topo.terrain(-80.0, 40.0) + 1.6, 40.0), Vector3(-72.2, Topo.terrain(-80.0, 40.0) + 1.0, 69.0)],
		"watch_roof": [roof + Vector3(2.6, 1.6, -2.4), roof + Vector3(0, 1.2, 1.9)],
		# the coin striker's room by the mule's pen: in at the door, and from the street
		"mint": [Mint.frame() * Vector3(1.2, 2.3, -0.9), Mint.frame() * Vector3(-0.5, 1.2, -3.3)],
		"mint_street": [Vector3(-3.5, Topo.street_height(-3.5) + 1.6, -1.2), Vector3(1.5, Topo.street_height(1.5) + 1.8, 7.5)],
		"sanctuary": [Vector3(40, Topo.SANCT_H + 1.6, -22), Vector3(50, 10, -31)],
		"surf": [Vector3(Topo.waterline_x(12) - 4.0, Topo.terrain(Topo.waterline_x(12) - 4.0, 12) + 1.6, 12),
				Vector3(Topo.waterline_x(12) + 40.0, 0.0, -18)],
		"shore": [Vector3(54, Topo.terrain(54, 18) + 1.6, 18), Vector3(400, 2, 60)],
	}
