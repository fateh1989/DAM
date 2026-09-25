extends RefCounted

func run(scene: Node) -> String:
	scene.call("clear_selected_units")
	var group: Array[int] = [0, 1]
	scene.call("select_units", group)
	var items: Array = scene.call("get_radar_units")
	if items.size() < 3:
		return "radar unit metadata is incomplete"
	var secondary: Dictionary = items[0]
	var primary: Dictionary = items[1]
	var normal: Dictionary = items[2]
	if not bool(primary.get("primary", false)) or bool(secondary.get("primary", false)):
		return "primary radar metadata is wrong"
	var radar := scene.get_node_or_null("HUD/RTSRadar")
	if radar == null:
		return "radar node missing"
	var normal_style: Dictionary = radar.call("get_blip_style", normal)
	var secondary_style: Dictionary = radar.call("get_blip_style", secondary)
	var primary_style: Dictionary = radar.call("get_blip_style", primary)
	if not (float(primary_style.get("radius", 0.0)) > float(secondary_style.get("radius", 0.0))):
		return "primary blip is not stronger than group blip"
	if not (float(secondary_style.get("radius", 0.0)) > float(normal_style.get("radius", 0.0))):
		return "selected group blip is not stronger than normal blip"
	scene.call("clear_selected_units")
	return ""
