extends RefCounted

func run(scene: Node) -> String:
	scene.call("clear_selected_units")
	var group: Array[int] = [0, 1]
	scene.call("select_units", group)
	var items: Array = scene.call("get_radar_units")
	if items.size() < 3:
		return "radar unit metadata is incomplete"
	var radar := scene.get_node_or_null("HUD/RTSRadar")
	if radar == null:
		return "radar node missing"
	var normal_style: Dictionary = radar.call("get_blip_style", items[2])
	var secondary_style: Dictionary = radar.call("get_blip_style", items[0])
	var primary_style: Dictionary = radar.call("get_blip_style", items[1])
	if not (float(primary_style.get("radius", 0.0)) > float(secondary_style.get("radius", 0.0)) and float(secondary_style.get("radius", 0.0)) > float(normal_style.get("radius", 0.0))):
		return "radar blip hierarchy is invalid"
	var camera_rect: Rect2 = scene.call("get_radar_camera_rect_uv")
	if camera_rect.size.x <= 0.0 or camera_rect.size.y <= 0.0:
		return "radar camera viewport has zero size"
	var indicator: Rect2 = radar.call("get_camera_indicator_rect")
	if indicator.size.x <= 0.0 or indicator.size.y <= 0.0:
		return "radar camera indicator was not generated"
	if not bool(radar.call("is_continuous_pointer_mode", "camera")):
		return "camera radar mode lost continuous drag"
	if bool(radar.call("is_continuous_pointer_mode", "move")):
		return "move mode would repeat commands while dragging"
	if bool(radar.call("is_continuous_pointer_mode", "select")):
		return "select mode would repeat selection while dragging"
	scene.call("clear_selected_units")
	return ""
