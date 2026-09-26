extends RefCounted

func _screen_point_is_clear(scene: Node, camera: Camera3D, screen_position: Vector2) -> bool:
	if not str(scene.call("pick_detail_logical_id_from_screen", screen_position)).is_empty():
		return false
	var units: Array = scene.get("_units")
	for raw_unit in units:
		var unit: Dictionary = raw_unit
		var node = unit.get("node")
		if not (node is Node3D) or not is_instance_valid(node):
			continue
		if not bool(unit.get("alive", true)) or not node.visible:
			continue
		if camera.is_position_behind(node.global_position):
			continue
		var unit_screen := camera.unproject_position(node.global_position)
		if unit_screen.distance_to(screen_position) < 60.0:
			return false
	return true


func run(scene: Node) -> String:
	var game_state := scene.get_node_or_null("/root/GameState")
	if game_state == null:
		return "touch logical selection smoke cannot access GameState"

	var camera := scene.get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		return "touch logical selection smoke cannot access RTS camera"

	var original_zoom := int(scene.call("get_rts_zoom_level"))
	scene.call("_set_rts_zoom_level", 8)
	scene.call("clear_selected_units")
	scene.call("clear_logical_heavy_selection")

	var detail_root := scene.get_node_or_null("DetailedUnits")
	if detail_root == null:
		return "touch logical selection detail root is missing"

	var detail_node: Node3D = null
	for child in detail_root.get_children():
		if child is Node3D and child.visible and not str(child.get_meta("logical_unit_id", "")).is_empty():
			detail_node = child as Node3D
			break
	if detail_node == null:
		return "touch logical selection has no visible detail unit"

	var detail_screen := camera.unproject_position(detail_node.global_position)
	var expected_id := str(scene.call("pick_detail_logical_id_from_screen", detail_screen))
	if expected_id.is_empty():
		return "detail touch picker did not resolve a logical unit"

	scene.call("_handle_world_tap", detail_screen)
	var selected_ids: Array = scene.call("get_selected_logical_heavy_ids")
	if selected_ids.size() != 1:
		return "detail touch did not create one logical selection"
	if str(selected_ids[0]) != expected_id:
		return "detail touch selected the wrong logical heavy id"

	var before: Dictionary = game_state.call("get_heavy_unit", expected_id)
	if before.is_empty():
		return "selected detail logical unit is missing from roster"

	var viewport_size := scene.get_viewport().get_visible_rect().size
	var candidates := [
		Vector2(viewport_size.x * 0.82, viewport_size.y * 0.72),
		Vector2(viewport_size.x * 0.18, viewport_size.y * 0.72),
		Vector2(viewport_size.x * 0.82, viewport_size.y * 0.28),
		Vector2(viewport_size.x * 0.18, viewport_size.y * 0.28),
		Vector2(viewport_size.x * 0.50, viewport_size.y * 0.82),
	]
	var ground_screen := Vector2(-1.0, -1.0)
	for candidate in candidates:
		if _screen_point_is_clear(scene, camera, candidate) and scene.call("_screen_to_ground", candidate) != null:
			ground_screen = candidate
			break
	if ground_screen.x < 0.0:
		return "touch logical selection could not find clear ground point"

	scene.call("_handle_world_tap", ground_screen)
	var after: Dictionary = game_state.call("get_heavy_unit", expected_id)
	if not bool(after.get("moving", false)):
		return "ground touch did not move selected logical heavy unit"
	var target_before := Vector2(
		float(before.get("target_lon", before.get("lon", 0.0))),
		float(before.get("target_lat", before.get("lat", 0.0)))
	)
	var target_after := Vector2(
		float(after.get("target_lon", after.get("lon", 0.0))),
		float(after.get("target_lat", after.get("lat", 0.0)))
	)
	if target_after.distance_to(target_before) <= 0.000001:
		return "ground touch did not change logical movement target"

	scene.call("stop_selected_logical_heavy_units")
	scene.call("clear_selection_on_empty_ground")
	if int(scene.call("get_selected_logical_heavy_count")) != 0:
		return "empty ground clear left logical unit selected"
	if int(scene.call("get_selected_unit_count")) != 0:
		return "empty ground clear left representative unit selected"

	scene.call("_set_rts_zoom_level", original_zoom)
	return ""
