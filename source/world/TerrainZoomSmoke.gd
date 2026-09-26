extends RefCounted

func run(scene: Node) -> String:
	if scene.RTS_ZOOM_LEVEL_MIN != 1 or scene.RTS_ZOOM_LEVEL_MAX != 5:
		return "RTS terrain zoom range is not five levels"
	if scene.RTS_ZOOM_DISTANCE_SCALES.size() != 5:
		return "RTS terrain zoom scale table does not contain five levels"
	var last := 999.0
	for level in range(1, 6):
		var scale := float(scene.call("get_rts_camera_distance_scale", level))
		if scale >= last:
			return "RTS camera distance does not get progressively closer"
		last = scale
	var far_profile: Dictionary = scene.call("get_rts_camera_profile", 1)
	var near_profile: Dictionary = scene.call("get_rts_camera_profile", 5)
	if float(near_profile["height"]) >= float(far_profile["height"]):
		return "near RTS zoom did not lower the camera"
	if float(near_profile["look_y"]) <= float(far_profile["look_y"]):
		return "near RTS zoom did not increase terrain viewing angle"
	var far_unit_scale := float(scene.call("get_rts_unit_visual_scale", 1))
	var near_unit_scale := float(scene.call("get_rts_unit_visual_scale", 5))
	if far_unit_scale <= near_unit_scale:
		return "far RTS zoom does not preserve unit readability"
	if near_unit_scale < 0.0035:
		return "near RTS unit scale became too small"
	scene.set("_terrain_mode", true)
	scene.call("_set_rts_zoom_level", 5)
	if int(scene.call("get_rts_zoom_level")) != 5:
		return "RTS terrain zoom setter did not reach level five"
	scene.call("_set_rts_zoom_level", 1)
	if int(scene.call("get_rts_zoom_level")) != 1:
		return "RTS terrain zoom setter did not return to level one"
	var shader_text := FileAccess.get_file_as_string("res://source/world/shaders/TacticalGround.gdshader")
	if "uniform float detail_lod" not in shader_text:
		return "tactical terrain shader is missing detail LOD control"
	if "uniform float slope_detail_strength" not in shader_text:
		return "tactical terrain shader is missing slope rock detail control"
	if "uniform float macro_variation_strength" not in shader_text:
		return "tactical terrain shader is missing macro variation control"
	return ""
