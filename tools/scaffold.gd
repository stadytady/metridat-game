@tool
class_name Scaffold
extends RefCounted
## Content helpers for people and agents: one call writes every file a piece of
## content needs, instead of five by hand. Editor-only (tools/ is not exported).

const DISCOVERIES := "res://data/discoveries"
const SCENES := "res://scenes/interactables"
const CSV := "res://data/i18n/strings.csv"


## Write a find: its Discovery resource, its Inspectable scene and the D_<ID>_*
## rows in strings.csv (EN and RU together, so test_i18n stays green).
## `text` holds the same keys twice: "title_en", "title_ru", "desc_en", ...
static func new_find(id: String, text: Dictionary, model := "res://assets/models/amphora.glb",
		box := Vector3(0.5, 0.6, 0.5), marker := 1.3, location_key := "LOC_AGORA") -> PackedStringArray:
	var written := PackedStringArray()
	var key := "D_" + id.to_upper()
	var tres := "%s/%s.tres" % [DISCOVERIES, id]
	var tscn := "%s/%s.tscn" % [SCENES, id]
	if FileAccess.file_exists(tres) or FileAccess.file_exists(tscn):
		push_error("find already exists: " + id)
		return written
	var d := DirAccess.open(DISCOVERIES)
	if d == null or not d.dir_exists(SCENES) and DirAccess.open(SCENES) == null:
		push_error("no content folders")
		return written
	_write(tres, """[gd_resource type="Resource" script_class="Discovery" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/interaction/discovery.gd" id="1_d"]
[ext_resource type="PackedScene" path="%s" id="2_m"]

[resource]
script = ExtResource("1_d")
id = &"%s"
title = "%s_TITLE"
location = "%s"
description = "%s_DESCRIPTION"
history = "%s_HISTORY"
sources = "%s"
narrative = "%s_NARRATIVE"
hint = "%s_HINT"
model = ExtResource("2_m")
""" % [model, id, key, location_key, key, key, String(text.get("sources", "TODO: источники")), key, key])
	written.append(tres)
	_write(tscn, """[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/interaction/inspectable.gd" id="1_insp"]
[ext_resource type="Resource" path="%s" id="2_disc"]

[node name="%s" type="StaticBody3D"]
script = ExtResource("1_insp")
discovery = ExtResource("2_disc")
box_size = Vector3(%.3f, %.3f, %.3f)
marker_height = %s
""" % [tres, _camel(id), box.x, box.y, box.z, marker])
	written.append(tscn)
	var rows := [
		[key + "_TITLE", text.get("title_en", "TODO title"), text.get("title_ru", "TODO заголовок")],
		[key + "_DESCRIPTION", text.get("desc_en", "TODO description"), text.get("desc_ru", "TODO описание")],
		[key + "_HISTORY", text.get("hist_en", "TODO: what is known"), text.get("hist_ru", "TODO: что известно")],
		[key + "_NARRATIVE", text.get("story_en", "TODO: the fiction"), text.get("story_ru", "TODO: вымысел")],
		[key + "_HINT", text.get("hint_en", "TODO: where to look"), text.get("hint_ru", "TODO: где искать")],
	]
	add_keys(rows)
	written.append(CSV)
	return written


## Append rows ([key, en, ru]) to strings.csv, quoting anything with a comma.
## Existing keys are left alone, so the call is safe to repeat.
static func add_keys(rows: Array) -> int:
	var path := ProjectSettings.globalize_path(CSV)
	var current := FileAccess.get_file_as_string(CSV)
	var added := 0
	for row: Array in rows:
		var key: String = row[0]
		if current.contains("\n" + key + ",") or current.begins_with(key + ","):
			continue
		current += "%s,%s,%s\n" % [key, _field(row[1]), _field(row[2])]
		added += 1
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write " + CSV)
		return 0
	f.store_string(current)
	f.close()
	return added


static func _field(value: Variant) -> String:
	var s := String(value).replace("\"", "'")
	if s.contains(","):
		return "\"" + s + "\""
	return s


static func _camel(id: String) -> String:
	var out := ""
	for part: String in id.split("_", false):
		out += part.substr(0, 1).to_upper() + part.substr(1)
	return out


## Adds one row and refuses the usual slips: an empty field, a Russian column
## copied from the English one, or one without a single Cyrillic letter.
static func add_key(key: String, en: String, ru: String) -> int:
	key = key.strip_edges()
	if key.is_empty() or en.strip_edges().is_empty() or ru.strip_edges().is_empty():
		push_error("add_key: пустой ключ или перевод")
		return 0
	if ru == en:
		push_error("add_key: русский текст совпадает с английским")
		return 0
	if RegEx.create_from_string("[а-яА-ЯёЁ]").search(ru) == null:
		push_error("add_key: в русском тексте нет кириллицы")
		return 0
	return add_keys([[key, en, ru]])


static func _write(path: String, body: String) -> void:
	var f := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	if f == null:
		push_error("cannot write " + path)
		return
	f.store_string(body)
	f.close()
