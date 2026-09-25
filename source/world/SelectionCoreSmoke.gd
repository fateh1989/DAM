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
	if int(scene.call("get_selected_unit_count")) != 0:
		return "dead unit changed selection state"
	probe["alive"] = true
	units[0] = probe
	scene.set("_units", units)
	return ""
