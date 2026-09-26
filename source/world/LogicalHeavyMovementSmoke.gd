extends RefCounted

func run(scene: Node) -> String:
	var game_state := scene.get_node_or_null("/root/GameState")
	if game_state == null:
		return "logical heavy movement cannot access GameState"

	var governorate_index := int(scene.get("_governorate_index"))
	if governorate_index < 0 or governorate_index >= 14:
		return "logical heavy movement has invalid focused governorate"

	var logical_id := "G%02d-tank-002" % [governorate_index + 1]
	var representatives: Array = scene.get("_units")
	for raw_unit in representatives:
		var representative: Dictionary = raw_unit
		if str(representative.get("logical_unit_id", "")) == logical_id:
			return "logical heavy movement test unit is already a visible representative"

	var before: Dictionary = game_state.call("get_heavy_unit", logical_id)
	if before.is_empty() or not bool(before.get("alive", false)):
		return "logical heavy movement test unit is unavailable"

	var start := Vector2(float(before.get("lon", 0.0)), float(before.get("lat", 0.0)))
	var destination := Vector2(start.x + 0.01, start.y)
	var original_zoom := int(scene.call("get_rts_zoom_level"))
	scene.call("_set_rts_zoom_level", 8)

	var detail_root := scene.get_node_or_null("DetailedUnits")
	if detail_root == null:
		return "focused detail unit root is missing"
	var detail_node: Node3D = null
	for child in detail_root.get_children():
		if child is Node3D and str(child.get_meta("logical_unit_id", "")) == logical_id:
			detail_node = child as Node3D
			break
	if detail_node == null:
		return "focused non-representative tank has no detail LOD node"

	if not bool(game_state.call("issue_heavy_move", logical_id, destination.x, destination.y)):
		return "logical heavy movement order was rejected"
	scene.call("_process", 0.10)

	var after: Dictionary = game_state.call("get_heavy_unit", logical_id)
	var after_position := Vector2(float(after.get("lon", 0.0)), float(after.get("lat", 0.0)))
	if after_position.distance_to(start) <= 0.000001:
		return "non-represented logical heavy unit did not move"
	if not bool(after.get("moving", false)):
		return "non-represented logical heavy unit stopped before reaching destination"

	var expected_local: Vector3 = scene.call("_geo_to_local", after_position.x, after_position.y, 0.0)
	var detail_flat := Vector2(detail_node.position.x, detail_node.position.z)
	var expected_flat := Vector2(expected_local.x, expected_local.z)
	if detail_flat.distance_to(expected_flat) > 0.001:
		return "detail LOD node did not follow non-represented logical movement"

	if not bool(game_state.call("stop_heavy_unit", logical_id)):
		return "logical heavy movement STOP was rejected"
	var stopped: Dictionary = game_state.call("get_heavy_unit", logical_id)
	if bool(stopped.get("moving", true)):
		return "logical heavy unit remained moving after STOP"

	scene.call("_set_rts_zoom_level", original_zoom)
	return ""
