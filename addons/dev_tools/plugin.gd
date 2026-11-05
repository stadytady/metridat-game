@tool
extends EditorPlugin
## Project menu entries that write content for you: a find needs four files and a
## row in the string table, which is exactly the kind of busywork a menu should do.
## Editor-only: addons/dev_tools is excluded from the export.

const S := preload("res://tools/scaffold.gd")

var _dialog: AcceptDialog
var _fields := {}
var _key_dialog: AcceptDialog
var _key_fields := {}


func _enter_tree() -> void:
	add_tool_menu_item("Новая находка…", _open_find)
	add_tool_menu_item("Добавить текст…", _open_key)
	add_tool_menu_item("Где стоит камера", _print_camera)


func _exit_tree() -> void:
	remove_tool_menu_item("Новая находка…")
	remove_tool_menu_item("Добавить текст…")
	remove_tool_menu_item("Где стоит камера")
	if _dialog != null:
		_dialog.queue_free()
	if _key_dialog != null:
		_key_dialog.queue_free()


func _open_find() -> void:
	if _dialog == null:
		_dialog = AcceptDialog.new()
		_dialog.title = "Новая находка"
		_dialog.ok_button_text = "Создать"
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		for key: String in ["id", "title_en", "title_ru", "desc_en", "desc_ru", "hint_en", "hint_ru"]:
			col.add_child(_row(key, _fields))
		_dialog.add_child(col)
		_dialog.confirmed.connect(_create_find)
		EditorInterface.get_base_control().add_child(_dialog)
	_dialog.popup_centered(Vector2i(720, 420))


func _row(key: String, store: Dictionary) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = key
	label.custom_minimum_size = Vector2(110, 0)
	var edit := LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	store[key] = edit
	row.add_child(label)
	row.add_child(edit)
	return row


func _create_find() -> void:
	var id: String = (_fields["id"] as LineEdit).text.strip_edges()
	if id.is_empty():
		push_warning("dev tools: пустой id, ничего не создано")
		return
	var text := {}
	for key: String in ["title_en", "title_ru", "desc_en", "desc_ru", "hint_en", "hint_ru"]:
		text[key] = (_fields[key] as LineEdit).text
	for path: String in S.new_find(id, text):
		print("dev tools: wrote ", path)
	EditorInterface.get_resource_filesystem().scan()
	print("dev tools: поставь находку в район (spawn_inspectable) и в Director._route()")


## Prints where the 3D view looks, with the ground height there: handy for placing
## props without guessing coordinates.
func _print_camera() -> void:
	var cam := EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
	if cam == null:
		return
	var p := cam.global_position
	print("camera  ", p)
	print("ground  ", Topo.surface(p.x, p.z), "  street ", Topo.street_height(p.x), "  terrain ", Topo.terrain(p.x, p.z))


## One line into the string table: the second most frequent edit after content.
func _open_key() -> void:
	if _key_dialog == null:
		_key_dialog = AcceptDialog.new()
		_key_dialog.title = "Добавить текст"
		_key_dialog.ok_button_text = "Добавить"
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		for key: String in ["ключ", "английский", "русский"]:
			col.add_child(_row(key, _key_fields))
		_key_dialog.add_child(col)
		_key_dialog.confirmed.connect(_create_key)
		EditorInterface.get_base_control().add_child(_key_dialog)
	_key_dialog.popup_centered(Vector2i(720, 220))


func _create_key() -> void:
	var key: String = (_key_fields["ключ"] as LineEdit).text.strip_edges()
	var en: String = (_key_fields["английский"] as LineEdit).text
	var ru: String = (_key_fields["русский"] as LineEdit).text
	if S.add_key(key, en, ru) == 0:
		push_warning("dev tools: строка не добавлена (дубль или неверный перевод)")
		return
	print("dev tools: added ", key)
	EditorInterface.get_resource_filesystem().scan()