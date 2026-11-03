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
	return {
		"hill": [sp + Vector3(0, 1.6, 0), Vector3(20, 6, 0)],
		"hill_wide": [sp + Vector3(-2, 2.5, 6), Vector3(60, -6, -10)],
		"street": [Vector3(-44, Topo.street_height(-44) + 1.6, Topo.street_z(-44)), Vector3(-10, 8, 0)],
		"street_up": [Vector3(-12, Topo.street_height(-12) + 1.6, Topo.street_z(-12)), Vector3(-60, 22, 0)],
		"agora": [Vector3(11, Topo.AGORA_H + 1.6, 6), Vector3(30, 6, -8)],
		"workshop": [Vector3(14.6, Topo.AGORA_H + 1.6, 5.6), Vector3(13.0, Topo.AGORA_H + 0.7, 9.4)],
		"fishing": [Vector3(61.5, Topo.terrain(61.5, 13.2) + 1.6, 13.2), Vector3(67.5, 1.2, 15.2)],
		"chickens": [Vector3(12.2, Topo.AGORA_H + 1.3, 3.2), Vector3(15.4, Topo.AGORA_H + 0.2, 5.8)],
		"sacred_way": [Vector3(29.0, Topo.AGORA_H + 1.6, 3.5), Vector3(35.5, 7.2, -12.0)],
		"dream": [Vector3(0, 61.6, 2601), Vector3(0, 61.2, 2620)],
		"dream_mound": [Vector3(1.0, 61.7, 2668), Vector3(0, 61.5, 2680)],
		"sanctuary": [Vector3(40, Topo.SANCT_H + 1.6, -22), Vector3(50, 10, -31)],
		"surf": [Vector3(Topo.waterline_x(12) - 4.0, Topo.terrain(Topo.waterline_x(12) - 4.0, 12) + 1.6, 12),
				Vector3(Topo.waterline_x(12) + 40.0, 0.0, -18)],
		"shore": [Vector3(54, Topo.terrain(54, 18) + 1.6, 18), Vector3(400, 2, 60)],
	}
