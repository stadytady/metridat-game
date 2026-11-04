extends CanvasLayer
## Conversation with an Npc: speaker, one line at a time, E for the next line,
## Esc to stop. Lines come from a Dialogue Manager resource, because every
## conversation in the city has choices. Text in a `.dialogue` file is a key and
## this panel translates it, so both languages stay in strings.csv.

## The player asked for the next line, or confirmed the highlighted choice.
signal advanced


var _panel: PanelContainer
var _name: Label
var _line: Label
var _choices: VBoxContainer
var _keys_hint: Label

var _npc: Npc
var _opened_frame := -1
var _lines_shown := 0
var _current: DialogueLine

var _choice_rows: Array[Label] = []
var _choice_keys := PackedStringArray()
var _choice_next := PackedStringArray()
var _choice_index := 0


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
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 2)
	_choices.visible = false
	_keys_hint = UiStyle.label("UI_DIALOGUE_KEYS", 18, UiStyle.MUTED)
	_keys_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_keys_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for n: Control in [_name, _line, _choices, _keys_hint]:
		col.add_child(n)
	_panel.visible = false
	Game.dialogue_requested.connect(open)


func is_open() -> bool:
	return _panel.visible


## How many lines the last conversation showed; the walkthrough checks this.
func lines_shown() -> int:
	return _lines_shown


func open(npc: Npc) -> void:
	_npc = npc
	_lines_shown = 0
	_current = null
	_clear_choices()
	_panel.visible = true
	_opened_frame = Engine.get_process_frames()
	Game.ui_blocking = true
	if npc.dialogue == null:
		push_warning("npc %s has no dialogue resource" % npc.npc_id)
		_finish()
		return
	_run(npc.dialogue, npc.dialogue_start)


## Show a line, wait, follow the branch the player picked. Mutations and
## conditions are the addon's business, not ours.
func _run(resource: DialogueResource, start: String) -> void:
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(resource, start, [self])
	while line != null and _panel.visible:
		if line.type == DMConstants.TYPE_DIALOGUE:
			_show_line(line)
			var next := line.next_id
			if line.responses.is_empty():
				await advanced
			else:
				_show_choices(line.responses)
				await advanced
				if not _choice_next.is_empty():
					next = _choice_next[clampi(_choice_index, 0, _choice_next.size() - 1)]
			if not _panel.visible:
				return
			line = await DialogueManager.get_next_dialogue_line(resource, next, [self])
		else:
			line = await DialogueManager.get_next_dialogue_line(resource, line.next_id, [self])
	_finish()


func _show_line(line: DialogueLine) -> void:
	_current = line
	_lines_shown += 1
	_name.text = tr(_npc.name_key)
	_line.text = tr(line.text)
	_clear_choices()
	_fit()


func _show_choices(responses: Array) -> void:
	_clear_choices()
	for r: DialogueResponse in responses:
		if not r.is_allowed:
			continue
		var row := UiStyle.label("", 22)
		_choices.add_child(row)
		_choice_rows.append(row)
		_choice_keys.append(r.text)
		_choice_next.append(r.next_id)
	if _choice_rows.is_empty():
		return
	_choices.visible = true
	_choice_index = 0
	_refresh_choices()
	_fit()


func _refresh_choices() -> void:
	for i in _choice_rows.size():
		var row := _choice_rows[i]
		var on := i == _choice_index
		row.text = ("\u203a " if on else "  ") + tr(_choice_keys[i])
		row.add_theme_color_override("font_color", UiStyle.BORDER if on else UiStyle.MUTED)


func _move_choice(delta: int) -> void:
	if _choice_rows.is_empty():
		return
	_choice_index = posmod(_choice_index + delta, _choice_rows.size())
	_refresh_choices()


func _clear_choices() -> void:
	for row in _choice_rows:
		if is_instance_valid(row):
			_choices.remove_child(row)
			row.queue_free()
	_choice_rows.clear()
	_choice_keys.clear()
	_choice_next.clear()
	_choice_index = 0
	_choices.visible = false


## Re-fit the panel after the text changed: it grows upward from the bottom.
func _fit() -> void:
	_panel.reset_size()
	_panel.position.y = 1080 - _panel.size.y - 120


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _npc and _panel.visible:
		if _current != null:
			_line.text = tr(_current.text)
			_refresh_choices()
		_keys_hint.text = tr("UI_DIALOGUE_KEYS")


## Next line, or confirm the highlighted choice.
func advance() -> void:
	if _panel.visible:
		advanced.emit()


func _finish() -> void:
	if _npc and not _npc.npc_id.is_empty():
		Game.talked[_npc.npc_id] = true
	close()


func close() -> void:
	_panel.visible = false
	Game.ui_blocking = false
	Game.mark_ui_closed()


func _process(_delta: float) -> void:
	if not _panel.visible or Engine.get_process_frames() <= _opened_frame + 1:
		return
	if Input.is_action_just_pressed(&"interact"):
		advance()
	elif Input.is_action_just_pressed(&"pause"):
		close()
	elif _choices.visible:
		if Input.is_action_just_pressed(&"move_forward"):
			_move_choice(-1)
		elif Input.is_action_just_pressed(&"move_back"):
			_move_choice(1)
