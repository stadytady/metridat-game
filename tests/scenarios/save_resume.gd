extends "res://tests/qa/scenario.gd"
## A walk saved half way and put back in the live world: what the snapshot holds
## is what the world showed, and after a restore the finds' markers, the lamps,
## the errand's thing on the ground and the hour all agree with it again.

const PATH := "user://qa_save.cfg"


func fixture() -> Dictionary:
	return {"found": 6, "lamps": 3, "quests": {"lamp": Quests.DONE, "hook": Quests.TAKEN},
			"talked": {"potter": true}, "at": Vector2(12.5, 3.5)}


func run() -> void:
	step("snapshot")
	var p := player()
	var data := SaveGame.snapshot(p.global_position, p.rotation.y)
	check(Array(data.found).size() == 6, "the snapshot holds %d finds" % Array(data.found).size())
	check(Array(data.lamps).size() == 3, "the snapshot holds %d lit lamps" % Array(data.lamps).size())
	check(SaveGame.write(data, PATH) == OK, "the save is not written")
	step("forget and restore")
	var hour_before: float = main().world.get_node("Atmosphere").t
	# as a freshly built world: every marker up, every errand's thing hidden
	Game.found = {}
	Game.quests = {}
	Game.talked = {}
	for n in tree().get_nodes_in_group(&"inspectable"):
		var m: Node3D = n.get_node_or_null("Marker")
		if m != null:
			m.visible = true
	for q in tree().get_nodes_in_group(&"quest_item"):
		q.visible = false
	SaveGame.apply(SaveGame.read(PATH))
	SaveGame.erase(PATH)
	await frames(5)
	check(Game.found_count() == 6, "after the restore %d finds" % Game.found_count())
	check(Game.lamps_lit() == 3, "after the restore %d lamps lit" % Game.lamps_lit())
	check(Game.quest_state("hook") == Quests.TAKEN and Game.quest_state("lamp") == Quests.DONE, "the errands did not come back")
	check(Game.talked.get("potter", false), "the talk with the potter was forgotten")
	step("the world agrees")
	for n in tree().get_nodes_in_group(&"inspectable"):
		var found: bool = Game.found.has(n.discovery.id)
		var marker: Node3D = n.get_node_or_null("Marker")
		if marker != null:
			check(marker.visible != found, "the marker of %s says %s" % [n.discovery.id, "unfound" if marker.visible else "found"])
	for q in tree().get_nodes_in_group(&"quest_item"):
		var want := Game.quest_state(q.quest) == Quests.TAKEN
		check(q.visible == want, "the %s errand's thing is %s" % [q.quest, "shown" if q.visible else "hidden"])
	var hour_after: float = main().world.get_node("Atmosphere").t
	check(absf(hour_after - hour_before) < 0.02, "the hour jumped from %.2f to %.2f on restore" % [hour_before, hour_after])
