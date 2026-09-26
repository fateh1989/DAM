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
	return ""
