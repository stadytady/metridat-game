class_name AstragalGame
extends RefCounted
## The game the children play on the agora, as rules and nothing else: five
## astragals a throw, three throws, the higher sum takes the throw. A knucklebone
## has four flat faces and no six, so a bone counts one to four - that is the
## whole difference between astragals and dice, and it is why the children laugh
## at anyone who counts the corners.

const BONES := 5
const FACES := 4
const THROWS := 3

var rng := RandomNumberGenerator.new()
## One entry per throw: {mine: Array[int], theirs: Array[int], sum_mine, sum_theirs, winner}
var throws: Array[Dictionary] = []
var won := 0
var lost := 0
var over := false
## "", "me", "them" or "draw" - only set once the three throws are played.
var winner := ""


func _init(seed_value: int = 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()


## Five bones, each one to four.
static func throw_bones(r: RandomNumberGenerator, n: int = BONES) -> Array[int]:
	var out: Array[int] = []
	for i in n:
		out.append(r.randi_range(1, FACES))
	return out


static func total(bones: Array[int]) -> int:
	var s := 0
	for b: int in bones:
		s += b
	return s


## One throw of both hands. Returns the entry added, or {} when the game is done.
func play_throw() -> Dictionary:
	if over:
		return {}
	var mine := throw_bones(rng)
	var theirs := throw_bones(rng)
	var sm := total(mine)
	var st := total(theirs)
	var w := "me" if sm > st else ("them" if st > sm else "draw")
	if w == "me":
		won += 1
	elif w == "them":
		lost += 1
	var entry := {"mine": mine, "theirs": theirs, "sum_mine": sm, "sum_theirs": st, "winner": w}
	throws.append(entry)
	over = throws.size() >= THROWS
	if over:
		winner = "me" if won > lost else ("them" if lost > won else "draw")
	return entry


## A fresh game on the same seed source.
func restart() -> void:
	throws.clear()
	won = 0
	lost = 0
	over = false
	winner = ""
