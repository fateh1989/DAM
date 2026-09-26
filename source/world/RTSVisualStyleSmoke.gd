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
	var palette_delta := Vector3(low.r - mid.r, low.g - mid.g, low.b - mid.b).length()
	if palette_delta < 0.12:
		return "RTS terrain palette lost elevation separation"

	var coast := scene.call("_continuous_macro_color", 220.0, 35.8, 35.5) as Color
	var east := scene.call("_continuous_macro_color", 220.0, 41.0, 35.5) as Color
	var south := scene.call("_continuous_macro_color", 220.0, 36.7, 32.8) as Color
	var north := scene.call("_continuous_macro_color", 220.0, 37.5, 36.8) as Color
	if Vector3(coast.r - east.r, coast.g - east.g, coast.b - east.b).length() < 0.10:
		return "RTS macro terrain lost west-to-east biome contrast"
	if Vector3(south.r - north.r, south.g - north.g, south.b - north.b).length() < 0.08:
		return "RTS macro terrain lost south-to-north biome contrast"
	if north.g <= south.g + 0.055:
		return "RTS macro terrain north steppe is not visibly greener than south"
	var central := scene.call("_continuous_macro_color", 220.0, 36.75, 35.15) as Color
	var plateau := scene.call("_continuous_macro_color", 220.0, 38.25, 35.15) as Color
	if Vector3(central.r - plateau.r, central.g - plateau.g, central.b - plateau.b).length() < 0.07:
		return "RTS macro terrain lost fertile-to-plateau transition"

	var source := FileAccess.get_file_as_string("res://source/world/MiddleEastTerrain.gd")
	if 'width_km * 1.72' not in source:
		return "RTS roads lost readable shoulder width"
	if 'Color(0.80, 0.67, 0.42, 1.0)' not in source:
		return "RTS road surface lost command-view contrast"
	scene.call("_refresh_vector_data", true)
	var vector_root := scene.get_node_or_null("VectorRoot")
	if vector_root == null:
		return "RTS terrain vector root is missing"
	for required_node in ["ArtDirtRoads", "ArtFields", "ArtRocks", "ArtSettlement"]:
		if vector_root.get_node_or_null(required_node) == null:
			return "RTS battlefield missing " + required_node
	var feature_snapshot: Dictionary = scene.call("get_art_battlefield_feature_snapshot")
	if int(feature_snapshot.get("roads", 0)) < 3:
		return "RTS battlefield lost feeder road network"
	if int(feature_snapshot.get("buildings", 0)) < 40:
		return "RTS battlefield settlement density became too sparse"
	if int(feature_snapshot.get("vector_children", 0)) < 7:
		return "RTS battlefield vector layer batch is incomplete"
	return ""
