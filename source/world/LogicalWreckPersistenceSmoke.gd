extends RefCounted

func _find_detail_node(root: Node, logical_id: String) -> Node3D:
	if root == null:
		return null
	for child in root.get_children():
		if child is Node3D and str(child.get_meta("logical_unit_id", "")) == logical_id:
			return child as Node3D
	return null


func run(scene: Node) -> String:
	var game_state := scene.get_node_or_null("/root/GameState")
	if game_state == null:
		return "logical wreck smoke cannot access GameState"

	var governorate_index := int(scene.get("_governorate_index"))
	var representatives := {}
	for raw_unit in scene.get("_units"):
		var representative: Dictionary = raw_unit
		if int(representative.get("governorate_index", -1)) != governorate_index:
			continue
		var logical_id := str(representative.get("logical_unit_id", ""))
		if not logical_id.is_empty():
			representatives[logical_id] = true

	var all_units: Array = game_state.call("get_heavy_units_for_governorate", governorate_index, false)
	var wreck_id := ""
	for raw_unit in all_units:
		var logical: Dictionary = raw_unit
		var logical_id := str(logical.get("id", ""))
		if bool(logical.get("alive", true)) or representatives.has(logical_id):
			continue
		wreck_id = logical_id
		break
	if wreck_id.is_empty():
		return "logical wreck smoke found no destroyed non-represented heavy unit"

	var original_zoom := int(scene.call("get_rts_zoom_level"))
	scene.call("_set_rts_zoom_level", 8)
	scene.call("_sync_detail_unit_lod", true)

	var detail_root := scene.get_node_or_null("DetailedUnits")
	var wreck_node := _find_detail_node(detail_root, wreck_id)
	if wreck_node == null:
		return "destroyed logical unit did not rebuild as detail wreck"
	if not wreck_node.visible:
		return "rebuilt logical wreck is not visible"
	if not bool(wreck_node.get_meta("logical_wreck", false)):
		return "rebuilt logical wreck is missing wreck metadata"
	if not bool(wreck_node.get_meta("is_wreck", false)):
		return "rebuilt logical wreck did not receive wreck visual"

	var camera := scene.get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		return "logical wreck smoke cannot access RTS camera"
	if not camera.is_position_behind(wreck_node.global_position):
		var wreck_screen := camera.unproject_position(wreck_node.global_position)
		var picked_id := str(scene.call("pick_detail_logical_id_from_screen", wreck_screen))
		if picked_id == wreck_id:
			return "destroyed logical wreck remained touch-selectable"

	var viewport_size := scene.get_viewport().get_visible_rect().size
	scene.call("clear_logical_heavy_selection")
	scene.call("select_logical_heavy_units_in_screen_rect", Rect2(Vector2.ZERO, viewport_size), false)
	for raw_id in scene.call("get_selected_logical_heavy_ids"):
		if str(raw_id) == wreck_id:
			return "destroyed logical wreck entered rectangle selection"

	scene.call("_set_rts_zoom_level", 1)
	scene.call("_set_rts_zoom_level", 8)
	scene.call("_sync_detail_unit_lod", true)
	detail_root = scene.get_node_or_null("DetailedUnits")
	var rebuilt_wreck := _find_detail_node(detail_root, wreck_id)
	if rebuilt_wreck == null or not rebuilt_wreck.visible:
		return "logical wreck disappeared after zoom round trip"
	if not bool(rebuilt_wreck.get_meta("logical_wreck", false)):
		return "logical wreck lost wreck state after zoom round trip"

	scene.call("clear_logical_heavy_selection")
	scene.call("_set_rts_zoom_level", original_zoom)
	return ""
