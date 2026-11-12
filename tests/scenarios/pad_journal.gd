extends "res://tests/qa/scenario.gd"
## The game with only a gamepad, through real button events: Y opens the
## journal and its hints name the pad's buttons, the d-pad picks a find and A
## opens it, B closes it; START pauses with the focus on Resume, B goes back.


func fixture() -> Dictionary:
	return {"found": 3, "at": Vector2(Topo.STREET[1].x, Topo.STREET[1].z), "pad": false}


func run() -> void:
	var journal: Node = main().get_node("JournalPanel")
	var info: Node = main().get_node("InfoPanel")
	var pause: Node = main().get_node("PauseMenu")
	step("the pad is picked up")
	await pad_button(JOY_BUTTON_Y)
	check(Game.pad, "a pad button did not switch the texts to the pad")
	await frames(3)
	check(journal.is_open(), "Y did not open the journal")
	var hints := PackedStringArray()
	for l: Node in journal.find_children("*", "Label", true, false):
		hints.append((l as Label).text)
	check("[A]" in "\n".join(hints) and "[B]" in "\n".join(hints), "the journal's hints do not name A and B")
	step("pick and open a find")
	var first: Discovery = journal.selected()
	check(first != null, "nothing is picked in the journal on the pad")
	await pad_button(JOY_BUTTON_DPAD_DOWN)
	var second: Discovery = journal.selected()
	check(second != null and second != first, "the d-pad did not move the pick")
	await pad_button(JOY_BUTTON_A)
	await frames(4)
	check(info.is_open() and not journal.is_open(), "A did not open the picked find")
	await pad_button(JOY_BUTTON_B)
	await frames(4)
	check(not info.is_open(), "B did not close the find")
	step("pause")
	await frames(30)  # let the closed panel hand the input back first
	await pad_button(JOY_BUTTON_START)
	await frames(3)
	check(pause.is_open(), "START did not pause")
	var focus: Control = main().get_viewport().gui_get_focus_owner()
	check(focus != null and focus == pause._resume, "on the pad the pause menu holds no focus (%s)" % focus)
	await pad_button(JOY_BUTTON_B)
	await frames(3)
	check(not pause.is_open() and not tree().paused, "B did not leave the pause menu")
