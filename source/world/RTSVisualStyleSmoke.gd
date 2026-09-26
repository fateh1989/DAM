extends RefCounted

func run(scene: Node) -> String:
	var far_profile: Dictionary = scene.call("get_rts_camera_profile", 1)
	var mid_profile: Dictionary = scene.call("get_rts_camera_profile", 5)
	var near_profile: Dictionary = scene.call("get_rts_camera_profile", 8)
	if float(far_profile.get("fov", 99.0)) > 35.0:
		return "RTS far camera became too wide"
	if float(near_profile.get("fov", 99.0)) > 40.0:
		return "RTS near camera became too wide"
	if float(mid_profile.get("back", 0.0)) <= float(mid_profile.get("height", 0.0)):
		return "RTS camera lost its oblique battlefield composition"

	var environment: Environment = scene.world_environment.environment
	if environment == null:
		return "RTS environment is missing"
	if environment.adjustment_contrast < 1.14:
		return "RTS battlefield contrast became too flat"
	if environment.adjustment_saturation < 0.95:
		return "RTS battlefield color became too desaturated"
	if environment.ambient_light_energy > 0.52:
		return "RTS ambient light became too flat"

	var low := scene.call("_terrain_color", 120.0) as Color
	var mid := scene.call("_terrain_color", 700.0) as Color
	if low.distance_to(mid) < 0.12:
		return "RTS terrain palette lost elevation separation"

	var source := FileAccess.get_file_as_string("res://source/world/MiddleEastTerrain.gd")
	if 'width_km * 1.72' not in source:
		return "RTS roads lost readable shoulder width"
	if 'Color(0.80, 0.67, 0.42, 1.0)' not in source:
		return "RTS road surface lost command-view contrast"
	return ""
