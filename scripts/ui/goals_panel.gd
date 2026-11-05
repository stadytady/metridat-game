class_name GoalsPanel
extends CanvasLayer
## Tab opens the way-book: what is left to do in the city (quests) and what has
## already been earned (achievements). Two pages, one card, keys in the footer.

const CARD := Vector2(1180, 720)

var _card: PanelContainer
var _title: Label
var _body: VBoxContainer
var _hints: Label
var _tab_buttons: Array[Button] = []
var _page := 0


func _ready() -> void:
	layer = 7
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UiStyle.panel())
	_card.custom_minimum_size = CARD
	_card.position = Vector2((1920 - CARD.x) / 2.0, (1080 - CARD.y) / 2.0)
	add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_card.add_child(col)
	_title = UiStyle.label(tr("UI_GOALS_TITLE"), 34, UiStyle.BORDER)
	col.add_child(_title)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	col.add_child(tabs)
	for i in 2:
		var b := UiStyle.button("")
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_set_page.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)
	col.add_child(_rule())
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_body)
	col.add_child(_rule())
	_hints = UiStyle.label(tr("UI_GOALS_KEYS"), 18, UiStyle.MUTED)
	col.add_child(_hints)
	_refresh()


func _rule() -> Control:
	var line := ColorRect.new()
	line.color = Color(0.55, 0.4, 0.2, 0.8)
	line.custom_minimum_size = Vector2(0, 2)
	return line


func open() -> void:
	_refresh()
	visible = true
	Game.ui_blocking = true


func close() -> void:
	visible = false
	Game.ui_blocking = false
	Game.mark_ui_closed()


func is_open() -> bool:
	return visible


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"goals"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if event.is_action_pressed(&"move_left"):
		_set_page(0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"move_right"):
		_set_page(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"pause"):
		close()


func _set_page(i: int) -> void:
	_page = clampi(i, 0, 1)
	_refresh()


func _refresh() -> void:
	_tab_buttons[0].text = tr("UI_GOALS_TAB_QUESTS")
	_tab_buttons[1].text = tr("UI_GOALS_TAB_ACH")
	for i in _tab_buttons.size():
		# The open page is lit like a pressed key; the other stays plain.
		_tab_buttons[i].set_pressed_no_signal(i == _page)
		_tab_buttons[i].add_theme_color_override("font_color",
				UiStyle.BORDER if i == _page else UiStyle.MUTED)
	for row in _body.get_children():
		_body.remove_child(row)
		row.queue_free()
	_hints.text = tr("UI_GOALS_KEYS")
	_title.text = tr("UI_GOALS_TITLE")
	if _page == 0:
		_quests()
	else:
		_achievements()


## What the slice asks of the player, with a bar for each.
func _quests() -> void:
	_body.alignment = BoxContainer.ALIGNMENT_CENTER
	var voices := Achievements.voices()
	var heard := Achievements.heard()
	var lamps := Game.lamps.size()
	var lit := Game.lamps_lit()
	_quest_row("UI_QUEST_FINDS", Game.found_count(), Game.total())
	_quest_row("UI_QUEST_LAMPS", lit, lamps)
	_quest_row("UI_QUEST_TALKS", heard, voices)
	var done := Game.dreaming or Achievements.is_unlocked("ACH_DREAM")
	_quest_row("UI_QUEST_SLEEP", 1 if done else 0, 1)
	var note := UiStyle.label(tr("UI_QUEST_NOTE"), 18, UiStyle.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(note)


func _quest_row(key: String, done: int, total: int) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	var head := HBoxContainer.new()
	var name := UiStyle.label(tr(key), 22, UiStyle.TEXT)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	head.add_child(UiStyle.label(progress_text(done, total), 20,
			UiStyle.BORDER if done >= total else UiStyle.MUTED))
	row.add_child(head)
	row.add_child(_bar(done, total))
	_body.add_child(row)


## How full the bar is, clamped: a quest cannot be more than done.
static func bar_fraction(done: int, total: int) -> float:
	if total <= 0:
		return 1.0
	return clampf(float(done) / float(total), 0.0, 1.0)


static func progress_text(done: int, total: int) -> String:
	return "%d / %d" % [mini(done, total), total]


func _bar(done: int, total: int) -> Control:
	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(0, 12)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.09, 0.06, 0.9)
	sb.border_color = Color(0.55, 0.4, 0.2, 1.0)
	sb.set_border_width_all(1)
	sb.anti_aliasing = false
	bar.add_theme_stylebox_override("panel", sb)
	var frac := bar_fraction(done, total)
	if frac > 0.0:
		var fill := ColorRect.new()
		fill.color = UiStyle.BORDER if frac < 1.0 else Color("#e8c98a")
		fill.anchor_left = 0.0
		fill.anchor_top = 0.0
		fill.anchor_right = frac
		fill.anchor_bottom = 1.0
		fill.offset_left = 1.0
		fill.offset_top = 1.0
		fill.offset_right = -1.0
		fill.offset_bottom = -1.0
		bar.add_child(fill)
	return bar


## What has been earned: a cup, the name, and how it is earned.
func _achievements() -> void:
	_body.alignment = BoxContainer.ALIGNMENT_BEGIN
	for id: String in Achievements.LIST:
		_body.add_child(_achievement_row(id))
	var done := UiStyle.label("%s %d / %d" % [tr("UI_GOALS_EARNED"), Achievements.count(),
			Achievements.LIST.size()], 18, UiStyle.MUTED)
	_body.add_child(done)


func _achievement_row(id: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var icon := TextureRect.new()
	icon.texture = AchievementPopup.icon_texture()
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = Vector2(34, 34)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var got := Achievements.is_unlocked(id)
	icon.modulate = Color.WHITE if got else Color(0.45, 0.42, 0.38, 0.7)
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var entry: Array = Achievements.LIST[id]
	col.add_child(UiStyle.label(tr(entry[0]), 22, UiStyle.BORDER if got else UiStyle.TEXT))
	col.add_child(UiStyle.label(tr(entry[1]), 17, UiStyle.MUTED))
	row.add_child(UiStyle.label("✓" if got else "—", 24,
			UiStyle.BORDER if got else Color(0.45, 0.42, 0.38, 0.8)))
	return row


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _body:
		_refresh()


## Keep the card in the middle of the screen whatever its height turned out to be.
func _center() -> void:
	var view := get_viewport().get_visible_rect().size
	_card.position = Vector2((view.x - _card.size.x) / 2.0, (view.y - _card.size.y) / 2.0)