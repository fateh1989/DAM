extends RefCounted

func run(scene: Node) -> String:
	var units: Array = scene.get("_units")
	if units.size() < 4:
		return "game visual aim smoke needs four visible heavy representatives"

	var target_index := 3
	var target: Dictionary = units[target_index]
	if not bool(target.get("alive", true)):
		return "game visual aim target representative is unavailable"
	var target_node = target.get("node")
	if not (target_node is Node3D) or not is_instance_valid(target_node):
		return "game visual aim target node is missing"

	var cases := [
		{
			"index": 0,
			"type": "tank",
			"yaw_path": "TankModel/TurretPivot",
			"pitch_path": "TankModel/TurretPivot/GunMount",
		},
		{
			"index": 1,
			"type": "artillery",
			"yaw_path": "ArtilleryModel/TurretPivot",
			"pitch_path": "ArtilleryModel/TurretPivot/GunMount",
		},
		{
			"index": 2,
			"type": "rocket_launcher",
			"yaw_path": "LauncherModel/LauncherPivot",
			"pitch_path": "LauncherModel/LauncherPivot/ElevationPivot",
		},
	]

	for test_case in cases:
		var source_index := int(test_case["index"])
		var unit: Dictionary = units[source_index]
		if str(unit.get("unit_type", "")) != str(test_case["type"]):
			return "game visual aim representative order changed for " + str(test_case["type"])
		if not bool(unit.get("alive", true)):
			return "game visual aim source is destroyed for " + str(test_case["type"])

		var source_node = unit.get("node")
		if not (source_node is Node3D) or not is_instance_valid(source_node):
			return "game visual aim source node is missing"
		var yaw_node := source_node.get_node_or_null(str(test_case["yaw_path"])) as Node3D
		var pitch_node := source_node.get_node_or_null(str(test_case["pitch_path"])) as Node3D
		if yaw_node == null or pitch_node == null:
			return "game visual aim pivot hierarchy is missing for " + str(test_case["type"])

		var hull_before := source_node.rotation.y
		var expected_world_yaw := float(scene.call(
			"_game_visual_yaw_between_nodes",
			source_node,
			target_node
		))
		var expected_local_yaw := wrapf(expected_world_yaw - hull_before, -PI, PI)
		var expected_pitch := float(scene.call(
			"_game_visual_pitch_for_unit_type",
			str(test_case["type"])
		))

		if not bool(scene.call("orient_visible_weapon_visual_at_unit", source_index, target_index)):
			return "game visual aim command failed for " + str(test_case["type"])
		if absf(wrapf(yaw_node.rotation.y - expected_local_yaw, -PI, PI)) > 0.001:
			return "game visual yaw is incorrect for " + str(test_case["type"])
		if absf(pitch_node.rotation.x - expected_pitch) > 0.001:
			return "game visual pitch is incorrect for " + str(test_case["type"])
		if absf(wrapf(source_node.rotation.y - hull_before, -PI, PI)) > 0.000001:
			return "game visual aim rotated hull for " + str(test_case["type"])

	return ""
