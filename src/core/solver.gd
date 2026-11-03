class_name Solver
extends RefCounted
## Solves a Board as a linear system over Z_p (p = colors, must be prime):
## find press counts x with A·x ≡ -cells (mod p), where A[i][j] = 1 if pressing j
## changes cell i. Among all solutions it picks the one with the fewest presses,
## enumerating the null space when it is small enough.

## Upper bound on null-space assignments to enumerate; beyond it the result is
## a valid solution but not guaranteed minimal (`optimal == false`).
const MAX_ENUM := 4096


static func is_prime(n: int) -> bool:
	if n < 2:
		return false
	var d := 2
	while d * d <= n:
		if n % d == 0:
			return false
		d += 1
	return true


## Returns {"solvable": bool, "presses": PackedInt32Array, "moves": int, "optimal": bool}.
static func solve(board: Board) -> Dictionary:
	var p := board.colors
	assert(is_prime(p), "Solver needs a prime number of colors")
	var n := board.size()
	var cols := n + 1
	# Flat augmented matrix: row i = cell i, column j = press j, last column = rhs.
	var a := PackedInt32Array()
	a.resize(n * cols)
	for i in n:
		a[i * cols + n] = posmod(-board.cells[i], p)
	for j in n:
		for i in board.affected(j):
			a[i * cols + j] = (a[i * cols + j] + 1) % p

	var pivots := PackedInt32Array()
	var r := 0
	for c in n:
		var piv := -1
		for i in range(r, n):
			if a[i * cols + c] != 0:
				piv = i
				break
		if piv < 0:
			continue
		if piv != r:
			for k in cols:
				var t := a[piv * cols + k]
				a[piv * cols + k] = a[r * cols + k]
				a[r * cols + k] = t
		var inv := _inverse(a[r * cols + c], p)
		for k in cols:
			a[r * cols + k] = a[r * cols + k] * inv % p
		for i in n:
			var f := a[i * cols + c]
			if i == r or f == 0:
				continue
			for k in cols:
				a[i * cols + k] = posmod(a[i * cols + k] - f * a[r * cols + k], p)
		pivots.append(c)
		r += 1

	for i in range(r, n):
		if a[i * cols + n] != 0:
			return {"solvable": false, "presses": PackedInt32Array(), "moves": -1, "optimal": true}

	var is_pivot := {}
	for c in pivots:
		is_pivot[c] = true
	var free := PackedInt32Array()
	for c in n:
		if not is_pivot.has(c):
			free.append(c)

	var total := 1
	var optimal := true
	for _f in free:
		total *= p
		if total > MAX_ENUM:
			optimal = false
			total = 1
			break

	var best := PackedInt32Array()
	var best_moves := -1
	for t in total:
		var x := PackedInt32Array()
		x.resize(n)
		var rest := t
		if optimal:
			for f in free:
				x[f] = rest % p
				rest /= p
		for row in r:
			var v := a[row * cols + n]
			for f in free:
				v -= a[row * cols + f] * x[f]
			x[pivots[row]] = posmod(v, p)
		var moves := 0
		for v in x:
			moves += v
		if best_moves < 0 or moves < best_moves:
			best_moves = moves
			best = x
	return {"solvable": true, "presses": best, "moves": best_moves, "optimal": optimal}


static func _inverse(v: int, p: int) -> int:
	# Fermat: v^(p-2) mod p, p is prime.
	var result := 1
	var base := v % p
	var e := p - 2
	while e > 0:
		if e & 1:
			result = result * base % p
		base = base * base % p
		e >>= 1
	return result
