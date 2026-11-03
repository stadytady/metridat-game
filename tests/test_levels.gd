extends "res://tests/test_case.gd"

const CHECK_LEVELS := 30


func test_specs_are_valid() -> void:
	for level in range(1, CHECK_LEVELS + 1):
		var s := Levels.spec(level)
		check(Solver.is_prime(s.colors), "level %d: colors must be prime" % level)
		check(s.colors <= Palette.CELLS.size(), "level %d: palette too small" % level)
		check(not s.stencils.is_empty(), "level %d: stencils" % level)


func test_levels_are_deterministic() -> void:
	for level in [1, 7, 20]:
		var a: Board = Levels.build(level).board
		var b: Board = Levels.build(level).board
		check_eq(a.cells, b.cells, "level %d cells" % level)
		check_eq(a.stencils, b.stencils, "level %d stencils" % level)


func test_levels_are_unsolved_and_solvable() -> void:
	for level in range(1, CHECK_LEVELS + 1):
		var built := Levels.build(level)
		var b: Board = built.board
		check(not b.is_solved(), "level %d starts solved" % level)
		check(built.par >= 1, "level %d par" % level)
		var r := Solver.solve(b)
		check(r.solvable, "level %d solvable" % level)
		for i in b.size():
			b.press(i, r.presses[i])
		check(b.is_solved(), "level %d solution applies" % level)


func test_progress_roundtrip() -> void:
	var path := "user://test_progress.cfg"
	var p := Progress.new()
	check(p.record(3, 10), "first record")
	check(not p.record(3, 12), "worse is not a record")
	check(p.record(3, 8), "better is a record")
	check_eq(p.unlocked, 4, "unlocked")
	check_eq(p.save_to(path), OK, "save")
	var q := Progress.new()
	q.load_from(path)
	check_eq(q.unlocked, 4, "loaded unlocked")
	check_eq(q.best.get(3), 8, "loaded best")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
