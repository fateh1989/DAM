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

	var group: Array[int] = [0, 1]
	scene.call("select_units", group)
	units = scene.get("_units")
	var secondary_unit: Dictionary = units[0]
	var primary_unit: Dictionary = units[1]
	var secondary_node := secondary_unit.get("node") as Node3D
	var primary_node := primary_unit.get("node") as Node3D
	var secondary_ring := secondary_node.get_node_or_null("Selection") as Node3D
	var primary_ring := primary_node.get_node_or_null("Selection") as Node3D
	if secondary_ring == null or primary_ring == null:
		return "group selection rings are missing"
	if not secondary_ring.visible or not primary_ring.visible:
		return "group selection rings are not visible"
	if not (primary_ring.scale.x > secondary_ring.scale.x):
		return "primary and group selection rings are not visually distinct"
	scene.call("clear_selected_units")
	return ""
