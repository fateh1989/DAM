extends RefCounted

func run(scene: Node) -> String:
	scene.call("clear_selected_units")
	if not bool(scene.call("select_unit", 2, false)):
		return "unified select_unit rejected a valid unit"
	if int(scene.call("get_selected_unit_count")) != 1:
		return "unified selection count is not one"
	var indices: Array = scene.call("get_selected_unit_indices")
	if indices.is_empty() or int(indices[0]) != 2:
		return "unified selection did not retain unit index 2"
	var radar_units: Array = scene.call("get_radar_units")
	if radar_units.size() <= 2:
		return "radar unit list is incomplete"
	var radar_item: Dictionary = radar_units[2]
	if int(radar_item.get("index", -1)) != 2 or not bool(radar_item.get("selected", false)):
		return "radar did not mirror world selection state"
	scene.call("clear_selected_units")
	return ""
