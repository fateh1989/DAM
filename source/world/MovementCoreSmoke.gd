extends RefCounted

func run(scene: Node) -> String:
	var group: Array[int] = [0, 1, 2, 3]
	scene.call("select_units", group)
	if not bool(scene.call("issue_selected_group_move", Vector2(36.5, 35.5))):
		return "formation move was rejected"
	var first_targets: Array = scene.call("get_selected_move_targets")
	if first_targets.size() != group.size():
		return "formation target count is wrong"
	for i in range(first_targets.size()):
		for j in range(i + 1, first_targets.size()):
			var a: Vector2 = first_targets[i]
			var b: Vector2 = first_targets[j]
			if a.distance_to(b) <= 0.000001:
				return "formation stacked units"

	var units: Array = scene.get("_units")
	var first_serial := int((units[0] as Dictionary).get("move_order_serial", 0))
	if not bool(scene.call("issue_selected_group_move", Vector2(37.0, 35.8))):
		return "replacement move was rejected"
	units = scene.get("_units")
	var second_serial := int((units[0] as Dictionary).get("move_order_serial", 0))
	if second_serial <= first_serial:
		return "new movement did not supersede old movement"

	var stopped := int(scene.call("stop_selected_units"))
	if stopped != group.size():
		return "STOP did not report every moving selected unit"
	if not bool(scene.call("are_selected_units_stopped")):
		return "STOP left a selected unit moving"
	units = scene.get("_units")
	for index in group:
		var unit: Dictionary = units[index]
		if float(unit.get("target_lon", 0.0)) != float(unit.get("lon", 0.0)):
			return "STOP left stale longitude target"
		if float(unit.get("target_lat", 0.0)) != float(unit.get("lat", 0.0)):
			return "STOP left stale latitude target"
	scene.call("clear_selected_units")
	return ""
