extends RefCounted

func run(scene: Node) -> String:
	var button := scene.get_node_or_null("HUD/CommandBar/Row/BoxSelectButton") as Button
	var box := scene.get_node_or_null("HUD/SelectionBox") as ColorRect
	if button == null or box == null:
		return "box selection UI nodes are missing"

	var original_zoom := int(scene.call("get_rts_zoom_level"))
	scene.call("_set_rts_zoom_level", 8)
	scene.call("clear_selected_units")
	scene.call("clear_logical_heavy_selection")

	var viewport_size := scene.get_viewport().get_visible_rect().size
	if viewport_size.x < 100.0 or viewport_size.y < 100.0:
		return "box selection smoke viewport is too small"
	var start := Vector2(4.0, 4.0)
	var finish := viewport_size - Vector2(4.0, 4.0)
	var camera_before: Vector2 = scene.call("get_radar_camera_uv")

	scene.call("_on_box_select_pressed")
	if not bool(scene.get("_box_select_mode")):
		return "box selection button did not arm selection mode"

	var press := InputEventScreenTouch.new()
	press.index = 91
	press.position = start
	press.pressed = true
	scene.call("_unhandled_input", press)
	if not bool(scene.get("_box_select_active")) or not box.visible:
		return "touch press did not start visible box selection"

	var drag := InputEventScreenDrag.new()
	drag.index = 91
	drag.position = finish
	drag.relative = finish - start
	scene.call("_unhandled_input", drag)
	if box.size.x <= 10.0 or box.size.y <= 10.0:
		return "touch drag did not grow selection rectangle"

	var release := InputEventScreenTouch.new()
	release.index = 91
	release.position = finish
	release.pressed = false
	scene.call("_unhandled_input", release)

	if bool(scene.get("_box_select_mode")) or bool(scene.get("_box_select_active")):
		return "touch box selection did not return to normal camera mode"
	if box.visible:
		return "touch box selection overlay remained visible after release"
	if int(scene.call("get_selected_logical_heavy_count")) < 2:
		return "touch box selection did not select multiple real heavy units"
	var camera_after: Vector2 = scene.call("get_radar_camera_uv")
	if camera_after.distance_to(camera_before) > 0.000001:
		return "touch box selection incorrectly panned RTS camera"

	scene.call("_on_clear_selection_pressed")
	scene.call("_on_box_select_pressed")
	var mouse_press := InputEventMouseButton.new()
	mouse_press.button_index = MOUSE_BUTTON_LEFT
	mouse_press.position = start
	mouse_press.pressed = true
	scene.call("_unhandled_input", mouse_press)

	var mouse_drag := InputEventMouseMotion.new()
	mouse_drag.position = finish
	mouse_drag.relative = finish - start
	scene.call("_unhandled_input", mouse_drag)

	var mouse_release := InputEventMouseButton.new()
	mouse_release.button_index = MOUSE_BUTTON_LEFT
	mouse_release.position = finish
	mouse_release.pressed = false
	scene.call("_unhandled_input", mouse_release)

	if int(scene.call("get_selected_logical_heavy_count")) < 2:
		return "mouse box selection did not select multiple real heavy units"
	if scene.call("get_radar_camera_uv").distance_to(camera_before) > 0.000001:
		return "mouse box selection incorrectly panned RTS camera"

	scene.call("_on_clear_selection_pressed")
	scene.call("_set_rts_zoom_level", original_zoom)
	return ""
