extends RefCounted

func run(scene: Node) -> String:
	var camera := scene.get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		return "rectangle selection smoke cannot access RTS camera"

	var original_zoom := int(scene.call("get_rts_zoom_level"))
	scene.call("_set_rts_zoom_level", 8)
	scene.call("clear_selected_units")
	scene.call("clear_logical_heavy_selection")

	var viewport_size := scene.get_viewport().get_visible_rect().size
	var rect := Rect2(Vector2.ZERO, viewport_size)
	var expected := {}

	var representatives: Array = scene.get("_units")
	for raw_unit in representatives:
		var unit: Dictionary = raw_unit
		var node = unit.get("node")
		if not (node is Node3D) or not is_instance_valid(node):
			continue
		if not bool(unit.get("alive", true)) or not node.visible or camera.is_position_behind(node.global_position):
			continue
		var logical_id := str(unit.get("logical_unit_id", ""))
		if logical_id.is_empty():
			continue
		var point := camera.unproject_position(node.global_position)
		if rect.has_point(point):
			expected[logical_id] = true

	var detail_root := scene.get_node_or_null("DetailedUnits")
	if detail_root == null:
		return "rectangle selection smoke cannot access detail root"
	for child in detail_root.get_children():
		if not (child is Node3D) or not child.visible or camera.is_position_behind(child.global_position):
			continue
		var logical_id := str(child.get_meta("logical_unit_id", ""))
		if logical_id.is_empty():
			continue
		var point := camera.unproject_position(child.global_position)
		if rect.has_point(point):
			expected[logical_id] = true

	if expected.size() < 2:
		return "rectangle selection smoke did not find multiple visible logical units"

	var selected_count := int(scene.call("select_logical_heavy_units_in_screen_rect", rect, false))
	if selected_count != expected.size():
		return "rectangle selection count differs from visible logical candidates"

	var selected_ids: Array = scene.call("get_selected_logical_heavy_ids")
	if selected_ids.size() != expected.size():
		return "rectangle selection id list size mismatch"
	for raw_id in selected_ids:
		var logical_id := str(raw_id)
		if not expected.has(logical_id):
			return "rectangle selection contains logical id outside screen rectangle"

	var focus_button := scene.get_node_or_null("HUD/CommandBar/Row/FocusUnitsButton") as Button
	var stop_button := scene.get_node_or_null("HUD/CommandBar/Row/StopUnitsButton") as Button
	var clear_button := scene.get_node_or_null("HUD/CommandBar/Row/ClearSelectionButton") as Button
	if focus_button == null or stop_button == null or clear_button == null:
		return "rectangle selection command buttons are missing"
	if focus_button.disabled or stop_button.disabled or clear_button.disabled:
		return "logical rectangle selection did not enable command buttons"

	var game_state := scene.get_node_or_null("/root/GameState")
	if game_state == null:
		return "rectangle selection smoke cannot access GameState"
	var first_id := str(selected_ids[0])
	var first: Dictionary = game_state.call("get_heavy_unit", first_id)
	var destination := Vector2(
		clampf(float(first.get("lon", 0.0)) + 0.03, scene.REGION_WEST, scene.REGION_EAST),
		clampf(float(first.get("lat", 0.0)) + 0.015, scene.REGION_SOUTH, scene.REGION_NORTH)
	)
	if int(scene.call("issue_selected_logical_group_move", destination)) <= 0:
		return "rectangle-selected logical group rejected movement"

	scene.call("_on_focus_units_pressed")
	var camera_uv: Vector2 = scene.call("get_radar_camera_uv")
	if camera_uv.x < 0.0 or camera_uv.x > 1.0 or camera_uv.y < 0.0 or camera_uv.y > 1.0:
		return "Focus command moved rectangle-selected group outside world bounds"

	scene.call("_on_stop_units_pressed")
	for raw_id in scene.call("get_selected_logical_heavy_ids"):
		var logical: Dictionary = game_state.call("get_heavy_unit", str(raw_id))
		if bool(logical.get("moving", true)):
			return "Stop command left rectangle-selected logical unit moving"

	scene.call("_on_clear_selection_pressed")
	if int(scene.call("get_selected_logical_heavy_count")) != 0:
		return "Clear command did not clear rectangle logical selection"

	scene.call("_set_rts_zoom_level", original_zoom)
	return ""
