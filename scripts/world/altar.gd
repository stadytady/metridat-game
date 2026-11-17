class_name Altar
extends Node3D
## The altar of Apollo on the hill terrace. Apollo the Healer (Ietros) was the
## god of Panticapaeum, a Milesian city; his temple stood on the acropolis.
## Here it is an open-air altar of dressed stone at the south side of the
## terrace, by the blocks laid out for building, with a priest who makes the
## morning offering: a fire on the altar and its smoke while the day is young
## (until MORNING_END), a libation poured at it; then the fire is left to die and
## he stands by. What the altar looked like is the game's.

const NPC := preload("res://scripts/npc/npc.gd")
const BACKDROP := preload("res://scripts/world/backdrop.gd")

## Clear of the lampstand by the view (east), the building blocks and the
## way to the sherd lying on them (west): the test holds it off every route step.
const SPOT := Vector2(-83.6, -6.0)
const SIZE := Vector3(1.6, 1.0, 0.9)
## The priest stands north of it, facing the altar (south, -z).
const PRIEST := Vector2(-83.6, -4.85)
## The morning offering burns until this hour (DayCycle 0 dawn .. 1 night).
const MORNING_END := 0.32

var _atm: Node
var _fire: GPUParticles3D
var _smoke: GPUParticles3D
var _light: OmniLight3D
var _priest: Npc
var burning := false


func _ready() -> void:
	_atm = get_parent().get_node_or_null("Atmosphere")
	var top := Topo.HILL_PLATFORM_TOP
	var kit := MeshKit.new()
	var c := Vector3(SPOT.x, top, SPOT.y)
	# a stepped base, the block, and a moulded top with the hearth sunk in it
	kit.solid_box("limestone", c + Vector3(0, 0.08, 0), Vector3(SIZE.x + 0.4, 0.16, SIZE.z + 0.4), ["bottom"])
	kit.solid_box("limestone", c + Vector3(0, 0.16 + SIZE.y / 2.0, 0), SIZE, ["bottom"])
	kit.solid_box("limestone", c + Vector3(0, 0.16 + SIZE.y + 0.05, 0), Vector3(SIZE.x + 0.12, 0.1, SIZE.z + 0.12), [])
	kit.box("dark", c + Vector3(0, 0.16 + SIZE.y + 0.105, 0), Vector3(0.7, 0.01, 0.4), [])
	# horns at the four corners, as altars had
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			kit.box("limestone", c + Vector3(sx * (SIZE.x / 2.0 - 0.06), 0.16 + SIZE.y + 0.16, sz * (SIZE.z / 2.0 - 0.06)), Vector3(0.12, 0.12, 0.12), [])
	add_child(kit.build("Altar"))
	var hearth := c + Vector3(0, 0.16 + SIZE.y + 0.12, 0)
	_fire = Lamp._make_flame(0.35)
	_fire.position = hearth
	add_child(_fire)
	_smoke = BACKDROP._smoke_plume(BACKDROP.SMOKE_KINDS["wisp"])
	_smoke.position = hearth + Vector3(0, 0.4, 0)
	add_child(_smoke)
	_light = OmniLight3D.new()
	_light.position = hearth + Vector3(0, 0.4, 0)
	_light.light_color = Color(1.0, 0.62, 0.3)
	_light.omni_range = 6.0
	_light.shadow_enabled = false
	_light.set_script(preload("res://scripts/world/flicker.gd"))
	_light.base_energy = 1.6
	_light.amount = 0.4
	add_child(_light)
	_priest_npc(top)
	step(_hour())


func _priest_npc(top: float) -> void:
	var n: Npc = NPC.new()
	n.name = "Priest"
	n.npc_id = "priest"
	n.name_key = "NPC_PRIEST_NAME"
	n.dialogue = load("res://data/dialogues/priest.dialogue") as DialogueResource
	n.look = {"beard": 2, "hair": 2, "cloth": "chiton"}
	n.body_mat = "robe"
	n.pose = "pour"
	n.position = Vector3(PRIEST.x, top, PRIEST.y)
	n.rotation.y = 0.0  # faces -z: the altar
	add_child(n)
	_priest = n


func _hour() -> float:
	return float(_atm.t) if _atm != null else Game.time_target()


## Whether the morning offering burns at this hour.
static func offering_at(hour: float) -> bool:
	return hour < MORNING_END


func _process(_delta: float) -> void:
	step(_hour())


func step(hour: float) -> void:
	var on := offering_at(hour)
	if on != burning or _fire.visible != on:
		burning = on
		for p: GPUParticles3D in [_fire, _smoke]:
			p.visible = on
			p.emitting = on
		_light.visible = on
		_priest.pose = "pour" if on else "stand"


func priest() -> Npc:
	return _priest
