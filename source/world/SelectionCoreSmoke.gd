extends RefCounted

func run(scene: Node) -> String:
	scene.call("clear_selected_units")
	if not bool(scene.call("select_unit", 2, false)):
		return "unified select_unit rejected a valid unit"
	var radar_units: Array = scene.call("get_radar_units")
	if radar_units.size() <= 2 or not bool((radar_units[2] as Dictionary).get("selected", false)):
		return "radar did not mirror world selection state"
	scene.call("clear_selected_units")

	if bool(scene.call("select_unit", -1, false)):
		return "invalid negative unit index was accepted"
	var units: Array = scene.get("_units")
	var probe: Dictionary = units[0]
	probe["alive"] = false
	units[0] = probe
	scene.set("_units", units)
	if bool(scene.call("select_unit", 0, false)):
		return "dead unit was accepted by selection"
	probe["alive"] = true
	units[0] = probe
	scene.set("_units", units)

	scene.call("select_unit", 1, false)
	if not bool(scene.call("clear_selection_on_empty_ground")) or int(scene.call("get_selected_unit_count")) != 0:
		return "empty-ground selection clear failed"

	scene.call("select_single_unit", 2)
	units = scene.get("_units")
	var selected_unit: Dictionary = units[2]
	var selected_node := selected_unit.get("node") as Node3D
	var primary_ring := selected_node.get_node_or_null("Selection") as Node3D
	if primary_ring == null or not primary_ring.visible:
		return "primary selection ring is not visible"
	if primary_ring.scale.x < 1.20:
		return "primary selection ring is not emphasized"
	scene.call("clear_selected_units")
	return ""
