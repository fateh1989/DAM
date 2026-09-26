extends RefCounted

const WORLD_SOURCE := "res://source/world/MiddleEastTerrain.gd"

func _function_block(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + 5)
	if next < 0:
		return source.substr(start)
	return source.substr(start, next - start)

func run(_scene: Node) -> String:
	var source := FileAccess.get_file_as_string(WORLD_SOURCE)
	if source.is_empty():
		return "world source could not be read"
	var functions := [
		"_pan_from_screen_delta",
		"radar_center_on_uv",
		"_select_governorate",
		"_on_reset_pressed",
	]
	for function_name in functions:
		var block := _function_block(source, function_name)
		if block.is_empty():
			return "missing continuity function: %s" % function_name
		if "_clear_all_world_nodes()" in block:
			return "%s still clears the whole world" % function_name
		if "_origin_lon = _center_lon" in block or "_origin_lat = _center_lat" in block:
			return "%s still rebases world origin" % function_name
	return ""
