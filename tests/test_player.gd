extends "res://tests/test_case.gd"
## Controller physics against simple geometry.

const PLAYER := preload("res://scenes/player/player.tscn")


func _box(root: Node3D, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	body.position = pos
	root.add_child(body)


func _walk(ledge: float) -> Vector3:
	var root := Node3D.new()
	tree.root.add_child(root)
	_box(root, Vector3(0, -0.5, 0), Vector3(40, 1, 40))
	_box(root, Vector3(14, ledge / 2.0, 0), Vector3(20, ledge, 10))
	var p: CharacterBody3D = PLAYER.instantiate()
	root.add_child(p)
	p.global_position = Vector3(0, 0.05, 0)
	p.bot_enabled = true
	for i in 30:
		await tree.physics_frame
	p.look_at_point(Vector3(10, 1.6, 0))
	p.bot_move = Vector2(0, -1)
	for i in 180:
		await tree.physics_frame
	var end := p.global_position
	root.queue_free()
	await tree.process_frame
	return end


func test_steps_over_curb() -> void:
	var end: Vector3 = await _walk(0.3)
	check(end.x > 4.5 and end.y > 0.25, "did not climb a 0.3 m curb, ended at %s" % end)


func test_wall_blocks() -> void:
	var end: Vector3 = await _walk(0.6)
	check(end.x < 4.0, "walked through/over a 0.6 m wall, ended at %s" % end)


func test_gravity() -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	_box(root, Vector3(0, -0.5, 0), Vector3(10, 1, 10))
	var p: CharacterBody3D = PLAYER.instantiate()
	root.add_child(p)
	p.global_position = Vector3(0, 3, 0)
	for i in 120:
		await tree.physics_frame
	check(p.is_on_floor() and absf(p.global_position.y) < 0.1, "did not land, at %s" % p.global_position)
	root.queue_free()
	await tree.process_frame
