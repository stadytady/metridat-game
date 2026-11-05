extends "res://tests/test_case.gd"
## The dog wakes for a player who comes close, and Omens still owns the night:
## the night watch must win, or the omens check in the walkthrough breaks.

func test_player_wakes_the_dog() -> void:
	var dog := Vector3(0, 0, 0)
	var near := Vector3(3, 0, 4)  # 5 m away
	check(Dog.look_target(Vector3.INF, near, dog, Dog.NOTICE) == near, "a player 5 m away is not watched")
	var far := Vector3(9, 0, 0)
	check(Dog.look_target(Vector3.INF, far, dog, Dog.NOTICE) == Vector3.INF, "a player 9 m away already wakes the dog")


func test_night_watch_wins_over_the_player() -> void:
	var shrine := Vector3(40, 8, -22)
	check(Dog.look_target(shrine, Vector3(1, 0, 1), Vector3.ZERO, Dog.NOTICE) == shrine,
		"the player overrides the sanctuary watch")


func test_no_player_no_watch() -> void:
	check(Dog.look_target(Vector3.INF, Vector3.INF, Vector3.ZERO, Dog.NOTICE) == Vector3.INF, "the dog watches nothing")
	check(Dog.look_target(Vector3.INF, Vector3(2, 0, 2), Vector3(0, 0, 6), 1.0) == Vector3.INF,
		"the notice radius is ignored")
