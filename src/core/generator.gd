class_name Generator
extends RefCounted
## Builds a level from a spec. Starts from a solved board and applies random
## presses, so every generated board is solvable by construction. `par` is the
## solver's minimum, which can be lower than the scramble length.

const MAX_ATTEMPTS := 64


## spec: {"w", "h", "colors", "stencils": Array[int], "scramble": int}
## Returns {"board": Board, "par": int}. Deterministic for a given seed.
static func generate(spec: Dictionary, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pool: Array = spec.stencils
	var scramble: int = spec.scramble
	# Scrambles cancel out sometimes; ask for at least half of the nominal depth.
	var want := maxi(1, ceili(scramble / 2.0))
	var best: Board = null
	var best_par := -1
	for _attempt in MAX_ATTEMPTS:
		var b := Board.new(spec.w, spec.h, spec.colors)
		for i in b.size():
			b.stencils[i] = pool[rng.randi_range(0, pool.size() - 1)]
		for _s in scramble:
			b.press(rng.randi_range(0, b.size() - 1))
		if b.is_solved():
			continue
		var par: int = Solver.solve(b).moves
		if par > best_par:
			best = b
			best_par = par
		if par >= want:
			break
	return {"board": best, "par": best_par}
