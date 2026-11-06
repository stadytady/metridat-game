class_name Quests
extends RefCounted
## Small errands people ask for in conversation: something lost, found
## somewhere near, brought back. A quest is taken in the giver's dialogue
## (`do Game.take_quest(id)`), its item can be picked up only then, and the
## giver thanks the player on the next talk (`do Game.complete_quest(id)`).
## No rewards yet: the thanks is the end of it.

enum { NONE, TAKEN, FOUND, DONE }

## id -> giver's npc_id, the title shown in the toast and on the Way, the
## item's name for the prompt, its model (Props.build kind) and the choice in
## the giver's dialogue that asks for it.
const LIST := {
	"loom_weight": {"giver": "baker", "title": "Q_LOOM_TITLE", "item": "Q_LOOM_ITEM", "model": "loom_weight", "ask": "LOC_Q_LOOM_ASK"},
	"lamp": {"giver": "water_carrier", "title": "Q_LAMP_TITLE", "item": "Q_LAMP_ITEM", "model": "oil_lamp", "ask": "LOC_Q_LAMP_ASK"},
	"hook": {"giver": "fisher", "title": "Q_HOOK_TITLE", "item": "Q_HOOK_ITEM", "model": "fish_hook", "ask": "LOC_Q_HOOK_ASK"},
	"astragal": {"giver": "turner", "title": "Q_ASTRA_TITLE", "item": "Q_ASTRA_ITEM", "model": "astragal", "ask": "LOC_Q_ASTRA_ASK"},
}


## What a step does to a quest's state: taking only starts an untouched quest,
## picking up only finds a taken one, giving back only finishes a found one.
static func next_state(state: int, step: String) -> int:
	match step:
		"take":
			return TAKEN if state == NONE else state
		"pick":
			return FOUND if state == TAKEN else state
		"give":
			return DONE if state == FOUND else state
	return state
