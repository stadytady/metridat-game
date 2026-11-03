extends "res://tests/test_case.gd"
## The dream's mirror stands on the altar facing the path, handle down, and
## sits on the slab instead of sinking into it.


func test_mirror_faces_the_path() -> void:
	var D := load("res://scripts/world/dream.gd")
	var b: Basis = D.mirror_basis()
	var face := b * Vector3.UP  # the model lies face up
	var handle := b * Vector3(0, 0, 1)  # the handle runs along +z
	check(face.z < -0.8, "face must turn to the path (-z): %s" % face)
	check(face.y > 0.1, "leaning back, the face catches the sky: %s" % face)
	check(handle.y < -0.8, "handle must point down: %s" % handle)
	# the handle's knob (0.32 from the centre) must rest on the slab, not under it
	var knob_y: float = D.MIRROR_LIFT + (b * Vector3(0, 0, 0.32)).y
	check(knob_y > -0.02 and knob_y < 0.06, "handle end should stand on the altar: %.3f" % knob_y)
