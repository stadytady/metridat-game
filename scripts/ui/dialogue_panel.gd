extends CanvasLayer
## Conversation with an Npc: speaker, one line at a time, E for the next line,
## Esc to stop. NPCs and their words are the game's fiction, and say so.

var _panel: PanelContainer
var _name: Label
var _line: Label
var _npc: Npc
var _index := 0
var _opened_frame := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiStyle.panel())
	_panel.custom_minimum_size = Vector2(1100, 0)
	_panel.position = Vector2((1920 - 1100) / 2.0, 1080 - 330)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)
	_name = UiStyle.label("", 30, UiStyle.BORDER)
	_line = UiStyle.label("", 26)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size.x = 1060
	var foot := HBoxContainer.new()
	var tag := UiStyle.label("UI_NPC_FICTION", 18, UiStyle.FICTION)
	tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(tag)
	foot.add_child(UiStyle.label("UI_DIALOGUE_KEYS", 18, UiStyle.MUTED))
	for n: Control in [_name, _line, foot]:
		col.add_child(n)
	_panel.visible = false
	Game.dialogue_requested.connect(open)


func is_open() -> bool:
	return _panel.visible


func open(npc: Npc) -> void:
	_npc = npc
	_index = 0
	_panel.visible = true
	_opened_frame = Engine.get_process_frames()
	Game.ui_blocking = true
	_show()


func _show() -> void:
	_name.text = tr(_npc.name_key)
	_line.text = tr(_npc.lines[_index])
	_panel.reset_size()
	_panel.position.y = 1080 - _panel.size.y - 120


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _npc and _panel.visible:
		_show()


## Next line, or close after the last one.
func advance() -> void:
	_index += 1
	if _index >= _npc.lines.size():
		Game.talked[_npc.npc_id] = true
		close()
	else:
		_show()


func close() -> void:
	_panel.visible = false
	Game.ui_blocking = false
	Game.ui_closed_frame = Engine.get_process_frames()


func _process(_delta: float) -> void:
	if not _panel.visible or Engine.get_process_frames() <= _opened_frame + 1:
		return
	if Input.is_action_just_pressed(&"interact"):
		advance()
	elif Input.is_action_just_pressed(&"pause"):
		close()
