extends RefCounted

func run(scene: Node) -> String:
	var game_state := scene.get_node_or_null("/root/GameState")
	if game_state == null:
		return "logical selection smoke cannot access GameState"

	var governorate_index := int(scene.get("_governorate_index"))
	if governorate_index < 0 or governorate_index >= 14:
		return "logical selection smoke has invalid focused governorate"

	var original_zoom := int(scene.call("get_rts_zoom_level"))
	scene.call("_set_rts_zoom_level", 8)

	var selected_count := int(scene.call(
		"select_governorate_logical_heavy_units",
		governorate_index,
		"tank",
		10
	))
	if selected_count != 10:
		return "logical selection did not select exactly ten tanks"

	var selected_ids: Array = scene.call("get_selected_logical_heavy_ids")
	if selected_ids.size() != 10:
		return "logical selection id count is not ten"

	var unique_ids := {}
	for raw_id in selected_ids:
		var logical_id := str(raw_id)
		if logical_id.is_empty() or unique_ids.has(logical_id):
			return "logical selection contains empty or duplicate ids"
		unique_ids[logical_id] = true
		var logical: Dictionary = game_state.call("get_heavy_unit", logical_id)
		if logical.is_empty():
			return "logical selection points to missing roster unit"
		if str(logical.get("unit_type", "")) != "tank":
			return "logical selection contains non-tank unit"
		if int(logical.get("current_governorate_index", -1)) != governorate_index:
			return "logical selection escaped focused governorate"

	var selected_ring_count := 0
	var representatives: Array = scene.get("_units")
	for raw_unit in representatives:
		var unit: Dictionary = raw_unit
		var logical_id := str(unit.get("logical_unit_id", ""))
		if not unique_ids.has(logical_id):
			continue
		var node = unit.get("node")
		if node is Node3D and is_instance_valid(node):
			var selection = node.get_node_or_null("Selection")
			if selection != null and selection.visible:
				selected_ring_count += 1

	var detail_root := scene.get_node_or_null("DetailedUnits")
	if detail_root == null:
		return "logical selection detail root is missing"
	for child in detail_root.get_children():
		if not (child is Node3D):
			continue
		var logical_id := str(child.get_meta("logical_unit_id", ""))
		if not unique_ids.has(logical_id):
			continue
		var selection = child.get_node_or_null("Selection")
		if selection != null and selection.visible:
			selected_ring_count += 1
	if selected_ring_count != 10:
		return "logical selection did not render ten selection rings"

	var first: Dictionary = game_state.call("get_heavy_unit", str(selected_ids[0]))
	var destination := Vector2(
		clampf(float(first.get("lon", 0.0)) + 0.04, scene.REGION_WEST, scene.REGION_EAST),
		clampf(float(first.get("lat", 0.0)) + 0.02, scene.REGION_SOUTH, scene.REGION_NORTH)
	)
	var issued := int(scene.call("issue_selected_logical_group_move", destination))
	if issued != 10:
		return "logical group movement did not issue ten orders"

	var target_keys := {}
	for raw_id in selected_ids:
		var logical: Dictionary = game_state.call("get_heavy_unit", str(raw_id))
		if not bool(logical.get("moving", false)):
			return "selected logical tank did not enter moving state"
		var target_lon := float(logical.get("target_lon", 0.0))
		var target_lat := float(logical.get("target_lat", 0.0))
		var key := "%.6f,%.6f" % [target_lon, target_lat]
		target_keys[key] = true
	if target_keys.size() != 10:
		return "logical group movement stacked formation targets"

	scene.call("clear_logical_heavy_selection")
	if int(scene.call("get_selected_logical_heavy_count")) != 0:
		return "logical selection did not clear"
	scene.call("_set_rts_zoom_level", original_zoom)
	return ""
