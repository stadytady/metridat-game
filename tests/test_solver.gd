extends "res://tests/test_case.gd"


func _apply(b: Board, presses: PackedInt32Array) -> Board:
	var c := b.copy()
	for i in presses.size():
		c.press(i, presses[i])
	return c


func test_solved_board_needs_zero_moves() -> void:
	var b := Board.new(4, 4, 2)
	var r := Solver.solve(b)
	check(r.solvable, "solvable")
	check_eq(r.moves, 0, "moves")


func test_single_press_is_found() -> void:
	var b := Board.new(3, 3, 3)
	b.press(4, 2)
	var r := Solver.solve(b)
	check_eq(r.moves, 1, "moves")
	check_eq(r.presses[4], 1, "press center once more")


func test_solution_solves_random_boards() -> void:
	var rng := RandomNumberGenerator.new()
	for k in [2, 3, 5]:
		for s in 20:
			rng.seed = s * 31 + k
			var b := Board.new(rng.randi_range(2, 6), rng.randi_range(2, 6), k)
			for i in b.size():
				b.stencils[i] = rng.randi_range(0, Board.Stencil.size() - 1)
			var scramble := rng.randi_range(1, 10)
			for _n in scramble:
				b.press(rng.randi_range(0, b.size() - 1))
			var r := Solver.solve(b)
			check(r.solvable, "k=%d seed=%d solvable" % [k, s])
			check(_apply(b, r.presses).is_solved(), "k=%d seed=%d applies" % [k, s])
			# Presses only go forward: undoing one scramble press costs k-1 presses.
			if r.optimal:
				var bound: int = scramble * (k - 1)
				check(r.moves <= bound, "k=%d seed=%d moves %d > bound %d" % [k, s, r.moves, bound])


func test_unreachable_cell_is_unsolvable() -> void:
	# RING never changes its own cell; on 1x1 nothing changes it.
	var b := Board.new(1, 1, 2)
	b.stencils[0] = Board.Stencil.RING
	b.cells[0] = 1
	check(not Solver.solve(b).solvable, "1x1 ring")


func test_minimum_uses_null_space() -> void:
	# 2x1, both ROW: pressing either does the same thing, so the minimum is 1, not 2.
	var b := Board.new(2, 1, 2)
	b.stencils.fill(Board.Stencil.ROW)
	b.press(0)
	var r := Solver.solve(b)
	check(r.optimal, "enumerated")
	check_eq(r.moves, 1, "moves")


func test_is_prime() -> void:
	check(Solver.is_prime(2) and Solver.is_prime(3) and Solver.is_prime(5), "primes")
	check(not Solver.is_prime(1) and not Solver.is_prime(4), "non-primes")
