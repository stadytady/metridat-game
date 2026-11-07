class_name AstragalGame
extends RefCounted
## The game the children play on the agora, as rules and nothing else, after
## the Greek and Roman throw of four astragals: a knucklebone lands on one of
## four long faces, and they counted 1, 3, 4 and 6 - no two and no five. The
## broad faces (3 and 4) come up far more often than the narrow ones (1 and 6).
## The best throw is all four faces different, "Aphrodite's throw"; the worst
## is four ones, "the dog". Otherwise the higher sum takes the throw. Three
## throws a game.
## (The face values and the two named throws: Pollux, Onomasticon 9.99-100;
## Suetonius, Augustus 71. The odds per face are this game's round numbers.)

const BONES := 4
const THROWS := 3
## The count on each face, and how often a bone comes to rest on it.
const FACE_VALUES: Array[int] = [1, 3, 4, 6]
const FACE_WEIGHTS: Array[float] = [0.12, 0.38, 0.38, 0.12]
## What a hand is beyond its sum.
const VENUS := "venus"
const DOG := "dog"

var rng := RandomNumberGenerator.new()
## One entry per throw: {mine, theirs, sum_mine, sum_theirs, kind_mine, kind_theirs, winner}
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


## One bone: a face, the broad ones more likely than the narrow.
static func throw_bone(r: RandomNumberGenerator) -> int:
	var x := r.randf()
	for i in FACE_VALUES.size():
		x -= FACE_WEIGHTS[i]
		if x < 0.0:
			return FACE_VALUES[i]
	return FACE_VALUES[FACE_VALUES.size() - 1]


static func throw_bones(r: RandomNumberGenerator, n: int = BONES) -> Array[int]:
	var out: Array[int] = []
	for i in n:
		out.append(throw_bone(r))
	return out


static func total(bones: Array[int]) -> int:
	var s := 0
	for b: int in bones:
		s += b
	return s


## "venus" when every face is different, "dog" when all are ones, else "".
static func kind(bones: Array[int]) -> String:
	var seen := {}
	for b: int in bones:
		seen[b] = true
	if bones.size() == FACE_VALUES.size() and seen.size() == FACE_VALUES.size():
		return VENUS
	if seen.size() == 1 and seen.has(1):
		return DOG
	return ""


## Which hand takes the throw: Aphrodite beats everything, the dog loses to
## everything, and between two of a kind (or none) the sum decides.
static func judge(mine: Array[int], theirs: Array[int]) -> String:
	var rank := func(h: Array[int]) -> int:
		var k := kind(h)
		return 2 if k == VENUS else (0 if k == DOG else 1)
	var rm: int = rank.call(mine)
	var rt: int = rank.call(theirs)
	if rm != rt:
		return "me" if rm > rt else "them"
	var sm := total(mine)
	var st := total(theirs)
	return "me" if sm > st else ("them" if st > sm else "draw")


## One throw of both hands. Returns the entry added, or {} when the game is done.
func play_throw() -> Dictionary:
	if over:
		return {}
	var mine := throw_bones(rng)
	var theirs := throw_bones(rng)
	var w := judge(mine, theirs)
	if w == "me":
		won += 1
	elif w == "them":
		lost += 1
	var entry := {"mine": mine, "theirs": theirs, "sum_mine": total(mine), "sum_theirs": total(theirs),
		"kind_mine": kind(mine), "kind_theirs": kind(theirs), "winner": w}
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
