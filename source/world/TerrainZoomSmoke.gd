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
	if "uniform float micro_detail_strength" not in shader_text:
		return "tactical terrain shader is missing micro detail control"
	var far_detail: Dictionary = scene.call("get_tactical_detail_profile", 1)
	var near_detail: Dictionary = scene.call("get_tactical_detail_profile", 5)
	if float(near_detail["detail_lod"]) <= float(far_detail["detail_lod"]):
		return "terrain detail LOD does not increase when zooming in"
	if float(near_detail["micro_detail_strength"]) <= float(far_detail["micro_detail_strength"]):
		return "micro terrain detail does not increase when zooming in"
	if float(far_detail["macro_variation_strength"]) <= float(near_detail["macro_variation_strength"]):
		return "distant terrain macro variation is not stronger"
	var material = scene.call("_get_tactical_ground_material")
	if material == null:
		return "tactical ground material could not be created"
	scene.set("_rts_zoom_level", 5)
	scene.call("_sync_tactical_ground_detail")
	if absf(float(material.get_shader_parameter("detail_lod")) - float(near_detail["detail_lod"])) > 0.001:
		return "terrain shader did not receive current zoom detail profile"
	return ""
