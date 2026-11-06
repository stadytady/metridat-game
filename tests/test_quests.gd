extends "res://tests/test_case.gd"
## Errands (Quests): the state only moves forward one step at a time, the lost
## thing lies there only while it is looked for, and every giver's dialogue
## asks for its errand, gives it and thanks for it.

const Q := preload("res://scripts/core/quests.gd")
const CSV := "res://data/i18n/strings.csv"


func test_steps_only_move_forward() -> void:
	check(Q.next_state(Q.NONE, "take") == Q.TAKEN, "taking does not start an errand")
	check(Q.next_state(Q.TAKEN, "pick") == Q.FOUND, "picking up does not find a taken one")
	check(Q.next_state(Q.FOUND, "give") == Q.DONE, "giving back does not finish a found one")
	# out of order: nothing happens
	check(Q.next_state(Q.NONE, "pick") == Q.NONE, "picked up before anyone asked")
	check(Q.next_state(Q.NONE, "give") == Q.NONE, "given back before anyone asked")
	check(Q.next_state(Q.TAKEN, "give") == Q.TAKEN, "given back before it was found")
	check(Q.next_state(Q.TAKEN, "take") == Q.TAKEN, "taken twice")
	check(Q.next_state(Q.DONE, "take") == Q.DONE, "a done errand starts again")
	check(Q.next_state(Q.FOUND, "pick") == Q.FOUND, "picked up twice")
	check(Q.next_state(Q.TAKEN, "wave") == Q.TAKEN, "an unknown step changes the state")


func test_game_runs_an_errand() -> void:
	var was: Dictionary = Game.quests.duplicate()
	Game.quests.clear()
	var seen: Array[int] = []
	var on := func(id: String, s: int) -> void:
		if id == "hook":
			seen.append(s)
	Game.quest_changed.connect(on)
	check(Game.quest_offered("hook") and not Game.quest_ready("hook"), "a fresh errand is not on offer")
	Game.pick_quest_item("hook")
	check(Game.quest_state("hook") == Q.NONE, "the hook was picked up before anyone asked")
	Game.take_quest("hook")
	check(not Game.quest_offered("hook"), "a taken errand is still offered")
	Game.complete_quest("hook")
	check(Game.quest_state("hook") == Q.TAKEN, "thanked for the hook before it was found")
	Game.pick_quest_item("hook")
	check(Game.quest_ready("hook"), "the hook found is not ready to give back")
	Game.complete_quest("hook")
	check(Game.quest_state("hook") == Q.DONE, "the hook given back is not done")
	check(Game.quest_state("lamp") == Q.NONE, "another errand moved with the hook")
	check(seen == [Q.TAKEN, Q.FOUND, Q.DONE], "signals for the hook: %s" % [seen])
	Game.quest_changed.disconnect(on)
	Game.quests = was


func test_lost_thing_lies_there_only_while_looked_for() -> void:
	var was: Dictionary = Game.quests.duplicate()
	Game.quests.clear()
	for id: String in Q.LIST:
		var item := QuestItem.new()
		item.quest = id
		tree.root.add_child(item)
		var shape: CollisionShape3D = item.get_child(0)
		check(item.collision_layer == 2 and item.collision_mask == 0,
				"%s is in the world's layer: someone will trip on it" % id)
		check(not item.visible and not item.can_interact() and shape.disabled,
				"%s lies there before anyone asked" % id)
		Game.take_quest(id)
		check(item.visible and item.can_interact() and not shape.disabled,
				"%s is not there once the errand is taken" % id)
		check(not item.get_prompt().contains("%s"), "%s prompt not filled: %s" % [id, item.get_prompt()])
		item.interact()
		check(Game.quest_state(id) == Q.FOUND, "picking up %s did not find it" % id)
		check(not item.visible and not item.can_interact(), "%s still lies there once picked up" % id)
		item.free()
	Game.quests = was


func test_every_errand_has_its_model_and_words() -> void:
	var text := FileAccess.get_file_as_string(CSV)
	for id: String in Q.LIST:
		var e: Dictionary = Q.LIST[id]
		check(Props.EXTRA.has(String(e["model"])), "%s: no Props model %s" % [id, e["model"]])
		for k: String in ["title", "item", "ask"]:
			check(text.contains("\n%s," % e[k]), "%s: no string %s" % [id, e[k]])


func test_givers_ask_give_and_thank() -> void:
	for id: String in Q.LIST:
		var e: Dictionary = Q.LIST[id]
		var path := "res://data/dialogues/%s.dialogue" % e["giver"]
		check(FileAccess.file_exists(path), "%s: giver %s has no dialogue" % [id, e["giver"]])
		var d := FileAccess.get_file_as_string(path)
		var ask := "- %s [if Game.quest_offered(\"%s\")]" % [e["ask"], id]
		check(d.contains(ask), "%s: %s does not offer it once: %s" % [id, path, ask])
		check(d.contains("do Game.take_quest(\"%s\")" % id), "%s: never taken in %s" % [id, path])
		check(d.contains("if Game.quest_ready(\"%s\")" % id), "%s: never thanked for in %s" % [id, path])
		check(d.contains("do Game.complete_quest(\"%s\")" % id), "%s: never finished in %s" % [id, path])
		# the thanks comes first, before the giver's usual opening
		check(d.find("quest_ready(\"%s\")" % id) < d.find("\n- "), "%s: thanks after the choices in %s" % [id, path])
