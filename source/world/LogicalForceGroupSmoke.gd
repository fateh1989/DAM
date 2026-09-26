extends RefCounted

func run(scene: Node) -> String:
	var game_state := scene.get_node_or_null("/root/GameState")
	if game_state == null:
		return "logical force group smoke cannot access GameState"

	var governorate_index := int(scene.get("_governorate_index"))
	if governorate_index < 0 or governorate_index >= 14:
		return "logical force group smoke has invalid focused governorate"

	var original_zoom := int(scene.call("get_rts_zoom_level"))
	scene.call("_set_rts_zoom_level", 8)

	var selected_count := int(scene.call(
		"select_governorate_force_mix",
		governorate_index,
		6,
		2,
		2
	))
	if selected_count != 10:
		return "mixed logical force selection did not create ten-unit group"

	var selected_ids: Array = scene.call("get_selected_logical_heavy_ids")
	if selected_ids.size() != 10:
		return "mixed logical force id count is not ten"

	var type_counts := {
		"tank": 0,
		"artillery": 0,
		"rocket_launcher": 0,
	}
	for raw_id in selected_ids:
		var logical: Dictionary = game_state.call("get_heavy_unit", str(raw_id))
		if logical.is_empty():
			return "mixed logical force points to missing roster unit"
		var unit_type := str(logical.get("unit_type", ""))
		if not type_counts.has(unit_type):
			return "mixed logical force contains unsupported unit type"
		type_counts[unit_type] = int(type_counts[unit_type]) + 1
	if int(type_counts["tank"]) != 6:
		return "mixed logical force tank quota is not six"
	if int(type_counts["artillery"]) != 2:
		return "mixed logical force artillery quota is not two"
	if int(type_counts["rocket_launcher"]) != 2:
		return "mixed logical force launcher quota is not two"

	var toggled_id := str(selected_ids[0])
	if not bool(scene.call("toggle_logical_heavy_selection", toggled_id)):
		return "logical force toggle remove failed"
	if int(scene.call("get_selected_logical_heavy_count")) != 9:
		return "logical force toggle did not remove one unit"
	if not bool(scene.call("toggle_logical_heavy_selection", toggled_id)):
		return "logical force toggle add failed"
	if int(scene.call("get_selected_logical_heavy_count")) != 10:
		return "logical force toggle did not restore one unit"

	var first: Dictionary = game_state.call("get_heavy_unit", toggled_id)
	var destination := Vector2(
		clampf(float(first.get("lon", 0.0)) + 0.05, scene.REGION_WEST, scene.REGION_EAST),
		clampf(float(first.get("lat", 0.0)) + 0.025, scene.REGION_SOUTH, scene.REGION_NORTH)
	)
	var issued := int(scene.call("issue_selected_logical_group_move", destination))
	if issued != 10:
		return "mixed logical force movement did not issue ten orders"

	var formation_targets := {}
	for raw_id in scene.call("get_selected_logical_heavy_ids"):
		var logical: Dictionary = game_state.call("get_heavy_unit", str(raw_id))
		if not bool(logical.get("moving", false)):
			return "mixed logical force contains unit without moving state"
		var target_key := "%.7f:%.7f" % [float(logical.get("target_lon", 0.0)), float(logical.get("target_lat", 0.0))]
		formation_targets[target_key] = true
	if formation_targets.size() != 10:
		return "mixed logical force collapsed multiple units onto the same formation slot"

	if not bool(scene.call("focus_selected_logical_heavy_units")):
		return "logical force camera focus failed"
	var camera_uv: Vector2 = scene.call("get_radar_camera_uv")
	if camera_uv.x < 0.0 or camera_uv.x > 1.0 or camera_uv.y < 0.0 or camera_uv.y > 1.0:
		return "logical force camera focus escaped world bounds"

	var stopped := int(scene.call("stop_selected_logical_heavy_units"))
	if stopped != 10:
		return "mixed logical force STOP did not stop ten units"
	for raw_id in scene.call("get_selected_logical_heavy_ids"):
		var logical: Dictionary = game_state.call("get_heavy_unit", str(raw_id))
		if bool(logical.get("moving", true)):
			return "mixed logical force retained moving unit after STOP"

	scene.call("clear_logical_heavy_selection")
	if int(scene.call("get_selected_logical_heavy_count")) != 0:
		return "mixed logical force selection did not clear"
	scene.call("_set_rts_zoom_level", original_zoom)
	return ""
