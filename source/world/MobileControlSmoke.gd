extends RefCounted

func run(scene: Node) -> String:
	var bar := scene.get_node_or_null("HUD/CommandBar") as Control
	var row := scene.get_node_or_null("HUD/CommandBar/Row") as Control
	if bar == null or row == null:
		return "mobile command surface is incomplete"
	if bar.mouse_filter != Control.MOUSE_FILTER_STOP or row.mouse_filter != Control.MOUSE_FILTER_STOP:
		return "command bar can leak pointer input to the world"
	scene.set("_multi_touch_gesture_active", false)
	if not bool(scene.call("_should_accept_world_tap", 1, 0.0)):
		return "normal single tap was rejected"
	scene.set("_multi_touch_gesture_active", true)
	if bool(scene.call("_should_accept_world_tap", 1, 0.0)):
		return "multi-touch release could become a false world tap"
	scene.set("_multi_touch_gesture_active", false)
	if bool(scene.call("_should_accept_world_tap", 1, scene.TAP_MAX_DRAG_PX + 1.0)):
		return "drag release could become a false world tap"
	return ""
