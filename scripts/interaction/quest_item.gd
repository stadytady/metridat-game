class_name QuestItem
extends StaticBody3D
## Something lost for an errand (Quests): out of sight until someone has asked
## the player to look for it, then lying where it was lost under a marker,
## picked up with E. On the interaction layer only, so nobody trips on it.

## A knucklebone or a hook at its true size is a few pixels on the ground at
## this resolution: a little larger, so the thing under the marker reads.
const MODEL_SCALE := 1.5

@export var quest := ""
## Tall enough to reach the marker: the thing itself may lie a hand below the
## edge of a path's collider, which is wider than the paving (Topo).
@export var box_size := Vector3(0.4, 0.6, 0.4)

var _model: Node3D
var _marker: MeshInstance3D
var _t := 0.0
var _shape: CollisionShape3D


func _ready() -> void:
	add_to_group(&"quest_item")
	collision_layer = 2  # the interaction ray, not the world: no one bumps into it
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = box_size
	cs.shape = sh
	cs.position.y = box_size.y / 2.0
	add_child(cs)
	_shape = cs
	var info: Dictionary = Quests.LIST[quest]
	_model = Props.build(String(info["model"])).build("Model")
	_model.scale = Vector3.ONE * MODEL_SCALE
	add_child(_model)
	_marker = _make_marker()
	add_child(_marker)
	Game.quest_changed.connect(func(_id: String, _state: int) -> void: _refresh())
	Game.state_restored.connect(_refresh)
	_refresh()


func _make_marker() -> MeshInstance3D:
	# the same ochre diamond as over a find: something to pick up here
	var kit := MeshKit.new()
	var r := 0.07
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
	mi.position.y = 0.55
	return mi


## Lying there only while it is being looked for.
func waiting() -> bool:
	return Game.quest_state(quest) == Quests.TAKEN


func _refresh() -> void:
	visible = waiting()
	# a hidden box would still stop the ray short of a find behind it
	_shape.disabled = not visible


func can_interact() -> bool:
	return waiting()


func get_prompt() -> String:
	return tr("UI_PICK_UP") % tr(String(Quests.LIST[quest]["item"]))


func interact() -> void:
	Game.pick_quest_item(quest)


func _process(delta: float) -> void:
	if visible:
		_t += delta
		_marker.rotation.y = _t * 1.8
