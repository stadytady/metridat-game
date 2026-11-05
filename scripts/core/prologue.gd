class_name Prologue
extends Node
## The evening before: the dreamer steps off the Swallow onto the pier at dusk
## and Damon, her skipper, talks with them (data/dialogues/prologue.dialogue).
## When the talk ends, or on Esc, the screen goes dark, MORNING, and the game
## begins on the hill as it always did. The hour is DayCycle.PROLOGUE until
## then (Game.time_target), so no district sets the light itself.

signal finished

const DIALOGUE := preload("res://data/dialogues/prologue.dialogue")
const NPC_ID := "sailor"
const DARK := 1.2  # seconds to black and back
const HOLD := 1.6  # MORNING on black

var _fade: ColorRect
var _caption: Label


## Where the dreamer stands: on the pier's planks by the gangway, on the land
## side of the skipper, so he is seen against the ship and the sunset.
static func arrival_point() -> Vector3:
	var s: Vector3 = load("res://scripts/world/harbour.gd").skipper_pos()
	return Vector3(s.x - 2.2, Topo.PIER_H, Topo.PIER_Z + 0.4)


static func skipper() -> Npc:
	var tree := Engine.get_main_loop() as SceneTree
	for n in tree.get_nodes_in_group(&"npc"):
		if (n as Npc).npc_id == NPC_ID:
			return n
	return null


func begin() -> void:
	_build_overlay()
	var main := get_parent()
	var player: CharacterBody3D = main.player()
	Game.prologue = true
	Game.prologue_changed.emit(true)
	player.global_position = arrival_point() + Vector3(0, 0.05, 0)
	player.velocity = Vector3.ZERO
	var damon := skipper()
	if damon == null:
		push_warning("prologue: no skipper on the pier")
		await morning()
		return
	player.look_at_point(damon.global_position + Vector3(0, 1.55, 0))
	await get_tree().create_timer(0.6).timeout
	var panel: Node = main.get_node("DialoguePanel")
	panel.open(damon, DIALOGUE, "start", false)
	await panel.closed
	await morning()


## Dark, MORNING, the hill.
func morning() -> void:
	var main := get_parent()
	var player: CharacterBody3D = main.player()
	Game.ui_blocking = true
	await _tween(_fade, 1.0, DARK)
	_caption.text = tr("UI_PROLOGUE_MORNING")
	await _tween(_caption, 1.0, 0.4)
	Game.prologue = false
	Game.prologue_changed.emit(false)
	player.global_position = Topo.spawn_point()
	player.velocity = Vector3.ZERO
	player.look_at_point(Vector3(20, 6, 0))  # as World places the player at the start
	await get_tree().create_timer(HOLD).timeout
	await _tween(_caption, 0.0, 0.4)
	Game.ui_blocking = false
	Game.mark_ui_closed()
	await _tween(_fade, 0.0, DARK)
	finished.emit()
	queue_free()


func _tween(c: CanvasItem, a: float, seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(c, "modulate:a", a, seconds)
	await tw.finished


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	layer.add_child(_fade)
	_caption = Label.new()
	_caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 34)
	_caption.add_theme_color_override("font_color", Color("#e6d6b4"))
	_caption.modulate.a = 0.0
	layer.add_child(_caption)
