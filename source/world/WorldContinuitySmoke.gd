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

	var strategic_block := _function_block(source, "_is_strategic_map")
	if "return false" not in strategic_block:
		return "legacy strategic map mode can activate again"
	var tactical_block := _function_block(source, "_is_tactical_overview")
	if "return false" not in tactical_block:
		return "legacy tactical overview can replace continuous RTS zoom"
	for zoom_function in ["_on_zoom_in_pressed", "_on_zoom_out_pressed", "_on_zoom_wheel_changed"]:
		var zoom_block := _function_block(source, zoom_function)
		if "_set_map_zoom" in zoom_block:
			return "%s still routes user zoom into legacy map mode" % zoom_function
		if "_set_rts_zoom_level" not in zoom_block:
			return "%s no longer controls the RTS camera" % zoom_function

	var camera_block := _function_block(source, "_position_camera")
	if camera_block.is_empty():
		return "RTS camera function is missing"
	if "PROJECTION_ORTHOGONAL" in camera_block:
		return "camera can still switch to legacy orthographic overview"
	if "PROJECTION_PERSPECTIVE" not in camera_block:
		return "camera is no longer locked to RTS perspective"
	if "_is_strategic_map" in camera_block or "_is_tactical_overview" in camera_block:
		return "camera still branches into legacy world modes"

	var pan_block := _function_block(source, "_pan_from_screen_delta")
	if "camera.size" in pan_block:
		return "camera panning still depends on legacy orthographic map size"

	var zoom_setter := _function_block(source, "_set_rts_zoom_level")
	if "_is_tactical_overview" in zoom_setter or "_set_map_zoom" in zoom_setter:
		return "RTS zoom still routes through legacy map/tactical modes"
	return ""
