class_name Inspectable
extends StaticBody3D
## Anything the player can inspect with E. The model is a child scene; the
## collider is a box sized by `box_size` so the ray hits reliably.

@export var discovery: Discovery
@export var model: PackedScene
@export var box_size := Vector3(0.6, 0.8, 0.6)
@export var marker_height := 1.3

var _marker: MeshInstance3D
var _t := 0.0


func _ready() -> void:
	collision_layer = 3  # world + inspectable
	add_to_group(&"inspectable")
	set_meta(&"surface", &"stone")
	if model:
		var m := model.instantiate()
		add_child(m)
		Mats.apply_to(m)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	cs.shape = shape
	cs.position.y = box_size.y / 2.0
	add_child(cs)
	_marker = _make_marker()
	add_child(_marker)
	if discovery:
		Game.register(discovery)
		Game.discovered.connect(_on_discovered)


func _make_marker() -> MeshInstance3D:
	# Spinning ochre diamond above undiscovered finds: adventure-game convention.
	var kit := MeshKit.new()
	var r := 0.09
	var top := Vector3(0, r * 1.6, 0)
	var bot := Vector3(0, -r * 1.6, 0)
	var ring := [Vector3(r, 0, 0), Vector3(0, 0, r), Vector3(-r, 0, 0), Vector3(0, 0, -r)]
	for i in 4:
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % 4]
		kit.tri("marker", a, top, b, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
		kit.tri("marker", a, b, bot, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	var mi := MeshInstance3D.new()
	mi.name = "Marker"
	mi.mesh = kit.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = marker_height
	return mi


func _process(delta: float) -> void:
	if _marker.visible:
		_t += delta
		_marker.rotation.y = _t * 1.8
		_marker.position.y = marker_height + sin(_t * 2.4) * 0.05


func inspect() -> void:
	Game.mark_found(discovery)


func _on_discovered(d: Discovery, _is_new: bool) -> void:
	if d == discovery:
		_marker.visible = false
