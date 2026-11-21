class_name Licenses
extends RefCounted
## The licence texts the credits page shows, for what the game ships that is
## not its own. Godot's own text and its third-party components come from the
## engine itself (Engine.get_license_text / get_copyright_info / get_license_info),
## so they always match the build. Dialogue Manager is an addon: its MIT text is
## copied here (test_credits checks it against addons/dialogue_manager/LICENSE),
## because a plain LICENSE file is not exported with the game.
## Licence texts stay in English, as published: they are legal text, not UI.

const DIALOGUE_MANAGER_NAME := "Dialogue Manager 3.9.1"
const DIALOGUE_MANAGER := """MIT License

Copyright (c) 2022-present Nathan Hoad and Dialogue Manager contributors.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE."""


## Godot's components as lines: "name: copyright (licence)".
static func godot_components() -> PackedStringArray:
	var out := PackedStringArray()
	for c: Dictionary in Engine.get_copyright_info():
		for part: Dictionary in c.get("parts", []):
			var who := ", ".join(PackedStringArray(part.get("copyright", [])))
			out.append("%s: %s (%s)" % [c.get("name", ""), who, part.get("license", "")])
	return out


## The full texts of the licences those components use, by name.
static func godot_component_licences() -> Dictionary:
	return Engine.get_license_info()
