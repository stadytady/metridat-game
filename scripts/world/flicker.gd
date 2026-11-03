extends OmniLight3D
## Fire light flicker: layered sines, cheap and deterministic.

@export var base_energy := 2.2
@export var amount := 0.6
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	var f := sin(_t * 13.0) * 0.5 + sin(_t * 7.3 + 1.0) * 0.3 + sin(_t * 23.0 + 2.0) * 0.2
	light_energy = base_energy + f * amount
