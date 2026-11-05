class_name AchievementPopup
extends Control
## The card that slides in when an achievement unlocks, the way Steam does it:
## a gold cup, a quiet caption and the name, bottom right. One at a time, in a
## queue, animated on a tween and announced by a two-note chime.

const CARD := Vector2(352, 84)
const MARGIN := 24.0
const SLIDE := 0.32
const HOLD := 4.2
const ICON := 16

var _panel: PanelContainer
var _caption: Label
var _name: Label
var _chime: AudioStreamPlayer
var _queue: Array[String] = []
var _showing := false

static var _icon: ImageTexture


## The gold cup, drawn in code like every other asset: 16 px, nearest filter.
static func icon_texture() -> ImageTexture:
	if _icon == null:
		var img := Image.create(ICON, ICON, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var gold := Color("#d9a441")
		var dark := Color("#3a2b18")
		# rim, bowl and the two handles
		for x in range(4, 12):
			img.set_pixel(x, 2, gold)
		for y in range(3, 8):
			for x in range(5, 11):
				img.set_pixel(x, y, gold)
		for p: Vector2i in [Vector2i(3, 4), Vector2i(3, 5), Vector2i(12, 4), Vector2i(12, 5)]:
			img.set_pixel(p.x, p.y, gold)
		# stem and foot
		for y in range(8, 11):
			img.set_pixel(7, y, gold)
			img.set_pixel(8, y, gold)
		for x in range(5, 11):
			img.set_pixel(x, 11, gold)
			img.set_pixel(x, 12, dark)
		_icon = ImageTexture.create_from_image(img)
	return _icon


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = CARD
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _card())
	_panel.custom_minimum_size = CARD
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_panel.add_child(row)
	var icon := TextureRect.new()
	icon.texture = icon_texture()
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = Vector2(48, 48)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	_caption = UiStyle.label(tr("UI_ACHIEVEMENT_CAPTION"), 15, UiStyle.MUTED)
	_name = UiStyle.label("", 22, UiStyle.BORDER)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_caption)
	col.add_child(_name)
	_chime = AudioStreamPlayer.new()
	_chime.stream = preload("res://assets/audio/achievement.wav")
	_chime.volume_db = -12.0
	add_child(_chime)
	visible = false
	modulate.a = 0.0


func _card() -> StyleBoxFlat:
	var sb := UiStyle.panel()
	sb.set_content_margin_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	return sb


## Queue an achievement; the card shows them one after another.
func push(id: String) -> void:
	if not Achievements.LIST.has(id):
		return
	_queue.append(id)
	if not _showing:
		_next()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _name:
		_caption.text = tr("UI_ACHIEVEMENT_CAPTION")
		if _name.text != "":
			for id: String in Achievements.LIST:
				if tr(Achievements.LIST[id][0]) == _name.text:
					_name.text = tr(Achievements.LIST[id][0])
					break


func _home() -> Vector2:
	return Vector2(size.x - CARD.x - MARGIN, size.y - CARD.y - MARGIN)


func _next() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var id: String = _queue.pop_front()
	_caption.text = tr("UI_ACHIEVEMENT_CAPTION")
	_name.text = tr(Achievements.LIST[id][0])
	var home := _home()
	position = home + Vector2(CARD.x + 40.0, 0.0)
	modulate.a = 0.0
	visible = true
	_chime.play()
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "position", home, SLIDE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, SLIDE)
	await t.finished
	await get_tree().create_timer(HOLD).timeout
	var out := create_tween()
	out.set_parallel(true)
	out.tween_property(self, "position", home + Vector2(CARD.x + 40.0, 0.0), SLIDE)
	out.tween_property(self, "modulate:a", 0.0, SLIDE)
	await out.finished
	visible = false
	_next()
