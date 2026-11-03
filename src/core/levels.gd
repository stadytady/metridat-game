class_name Levels
extends RefCounted
## Level progression. Hand-tuned for the first levels (each introduces one
## idea), then grows procedurally. Seeds are fixed, so level N is the same
## board for every player.

const ALL: Array[int] = [Board.Stencil.PLUS, Board.Stencil.CROSS, Board.Stencil.RING, Board.Stencil.ROW, Board.Stencil.COL]

const _TABLE := [
	{"w": 3, "h": 3, "colors": 2, "stencils": [Board.Stencil.PLUS], "scramble": 1},
	{"w": 3, "h": 3, "colors": 2, "stencils": [Board.Stencil.PLUS], "scramble": 2},
	{"w": 3, "h": 3, "colors": 2, "stencils": [Board.Stencil.PLUS], "scramble": 3},
	{"w": 3, "h": 3, "colors": 2, "stencils": [Board.Stencil.PLUS, Board.Stencil.CROSS], "scramble": 3},
	{"w": 4, "h": 4, "colors": 2, "stencils": [Board.Stencil.PLUS, Board.Stencil.CROSS], "scramble": 4},
	{"w": 4, "h": 4, "colors": 2, "stencils": [Board.Stencil.PLUS, Board.Stencil.ROW, Board.Stencil.COL], "scramble": 4},
	{"w": 3, "h": 3, "colors": 3, "stencils": [Board.Stencil.PLUS], "scramble": 3},
	{"w": 4, "h": 4, "colors": 3, "stencils": [Board.Stencil.PLUS, Board.Stencil.CROSS], "scramble": 4},
	{"w": 4, "h": 4, "colors": 2, "stencils": [Board.Stencil.PLUS, Board.Stencil.CROSS, Board.Stencil.RING], "scramble": 5},
	{"w": 5, "h": 5, "colors": 2, "stencils": [Board.Stencil.PLUS, Board.Stencil.CROSS, Board.Stencil.ROW, Board.Stencil.COL], "scramble": 5},
	{"w": 5, "h": 5, "colors": 3, "stencils": [Board.Stencil.PLUS, Board.Stencil.CROSS, Board.Stencil.RING], "scramble": 6},
	{"w": 5, "h": 5, "colors": 3, "stencils": ALL, "scramble": 7},
]


static func spec(level: int) -> Dictionary:
	assert(level >= 1)
	if level <= _TABLE.size():
		return _TABLE[level - 1]
	var extra := level - _TABLE.size()
	return {
		"w": 6,
		"h": 6,
		"colors": 3,
		"stencils": ALL,
		"scramble": mini(8 + extra / 2, 14),
	}


static func seed_for(level: int) -> int:
	return hash("metridat-level-%d" % level)


static func build(level: int) -> Dictionary:
	return Generator.generate(spec(level), seed_for(level))
