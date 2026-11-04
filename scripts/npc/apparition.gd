class_name Apparition
extends Node3D
## A figure that is there until you come close, then crumbles away: the night
## figure on the street and those on the dream path. Its meshes use psx_ghost,
## whose per-instance `fade` drops pixels; stepped at 15 fps like the figures'
## motion, so it reads as PS1, not as a video cross-fade.

const DISSOLVE := 1.6  # 24 steps at 15 fps

## True from the moment it starts to go.
var gone := false
var _t := 0.0


## How much of it is left, DISSOLVE seconds after it began to go.
static func fade_at(t: float) -> float:
	var stepped := floorf(t * 15.0 + 0.001) / 15.0
	return clampf(1.0 - stepped / DISSOLVE, 0.0, 1.0)


func vanish() -> void:
	if gone:
		return
	gone = true
	_t = 0.0


## Back in place, whole (the dream path is walked again on every sleep).
func reset() -> void:
	gone = false
	_t = 0.0
	visible = true
	_set_fade(1.0)


func _process(delta: float) -> void:
	if not gone or not visible:
		return
	_t += delta
	var f := fade_at(_t)
	_set_fade(f)
	if f <= 0.0:
		visible = false


func _set_fade(f: float) -> void:
	for g: GeometryInstance3D in find_children("*", "GeometryInstance3D", true, false):
		g.set_instance_shader_parameter(&"fade", f)
