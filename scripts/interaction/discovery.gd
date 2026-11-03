class_name Discovery
extends Resource
## One inspectable find. `history` must be historically established (with a
## source); `narrative` is the game's own fiction and is shown as such.
## Text fields hold translation keys (data/i18n/strings.csv); `sources` is a
## bibliography and stays untranslated.

@export var id: StringName
@export var title: String
@export var location: String
@export_multiline var description: String
@export_multiline var history: String
@export var sources: String
@export_multiline var narrative: String
## Where to look, for the journal: a nudge, not a map pin.
@export var hint: String
## The find itself: placed in the world by its Inspectable and shown large
## in the info panel's viewer.
@export var model: PackedScene
## A find of the epilogue (the dream): not counted in the city's finds, does
## not move the evening on, shown in the journal only once found.
@export var epilogue := false
