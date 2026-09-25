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
	if camera_rect.position.x < 0.0 or camera_rect.position.y < 0.0 or camera_rect.end.x > 1.0001 or camera_rect.end.y > 1.0001:
		return "radar camera viewport escaped normalized bounds"
	var center: Vector2 = scene.call("get_radar_camera_uv")
	if not camera_rect.has_point(center):
		return "radar camera viewport does not contain camera center"
	scene.call("clear_selected_units")
	return ""
