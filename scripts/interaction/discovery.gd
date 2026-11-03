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
