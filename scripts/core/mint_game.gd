class_name MintGame
extends RefCounted
## Striking staters at Sosias's anvil: he lays a blank on the die and holds the
## punch on it, the player swings the hammer - one blow a coin, as he says
## (twice, and "the satyr has two noses"), three blanks a sitting. A needle runs
## across a meter with the swing; the mark is where the punch stands upright
## under it, and it drifts as his hand tires. On the mark the coin comes out
## crisp; near it the punch tilts and the design doubles; off it the blank
## slides and the design lands off centre.
## (A Greek coin was struck between an anvil die and a punch die with a hand
## hammer; doubled and off-centre strikes are common on real coins. The meter,
## the drift and the grades are this game's.)
## Pure: the clock is passed in, so tests and the scenario drive it exactly.

const BLANKS := 3
## The needle's swing, radians a second: about one pass in 1.2 s.
const SWING := 2.6
## Half the width of the true mark, on a meter 0..1.
const MARK_HALF := 0.07
## Past the true mark, still a glancing blow out to this many half-widths.
const NEAR := 2.4
## How far the mark wanders from the middle, and how fast.
const DRIFT := 0.24
const DRIFT_SPEED := 0.75

enum { MISS, GLANCE, TRUE }

## Seconds since the panel opened on this sitting.
var clock := 0.0
## One grade per blank struck so far.
var grades: Array[int] = []


## Where the needle is at time t (0 left .. 1 right).
static func needle(t: float) -> float:
	return 0.5 + 0.46 * sin(t * SWING)


## The middle of the mark for this blank at time t.
static func mark(t: float, blank: int) -> float:
	return 0.5 + DRIFT * sin(t * DRIFT_SPEED + float(blank) * 2.1)


static func grade(needle_at: float, mark_at: float) -> int:
	var off := absf(needle_at - mark_at)
	if off <= MARK_HALF:
		return TRUE
	if off <= MARK_HALF * NEAR:
		return GLANCE
	return MISS


## What one blow made of its blank.
static func quality(g: int) -> String:
	return ["off_centre", "doubled", "crisp"][g] if g >= 0 and g <= TRUE else ""


## How far a blow put the design off the middle of its blank (in blank radii):
## a miss slides the blank a good way, each blank its own way.
static func offset(g: int, blank: int) -> Vector2:
	return Vector2.from_angle(1.3 + float(blank) * 2.4) * (0.24 if g == MISS else 0.0)


## A glancing blow tilts the punch: the design is there twice, the second faint.
static func doubled(g: int) -> bool:
	return g == GLANCE


## Strikes the next blank now; returns its grade, -1 once all are struck.
func strike() -> int:
	if over():
		return -1
	var g := grade(needle(clock), mark(clock, grades.size()))
	grades.append(g)
	return g


func over() -> bool:
	return grades.size() >= BLANKS


func reset() -> void:
	grades.clear()
	clock = 0.0
