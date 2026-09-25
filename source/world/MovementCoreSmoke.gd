extends RefCounted

func run(scene: Node) -> String:
	scene.call("clear_selected_units")
	if bool(scene.call("issue_selected_group_move", Vector2(36.0, 35.0))):
		return "empty selection unexpectedly accepted a move order"
	var group: Array[int] = [0, 1]
	scene.call("select_units", group)
	if bool(scene.call("issue_selected_group_move", Vector2(NAN, 35.0))):
		return "NaN movement destination was accepted"
	if bool(scene.call("issue_selected_group_move", Vector2(100000.0, 35.0))):
		return "non-finite-scale movement destination was accepted"
	if not bool(scene.call("issue_selected_group_move", Vector2(100.0, 100.0))):
		return "finite out-of-region destination was not clamped and accepted"
	var units: Array = scene.get("_units")
	for index in group:
		var unit: Dictionary = units[index]
		if float(unit.get("target_lon", 0.0)) < scene.REGION_WEST or float(unit.get("target_lon", 0.0)) > scene.REGION_EAST:
			return "clamped longitude escaped strategic region"
		if float(unit.get("target_lat", 0.0)) < scene.REGION_SOUTH or float(unit.get("target_lat", 0.0)) > scene.REGION_NORTH:
			return "clamped latitude escaped strategic region"
	scene.call("stop_selected_units")
	scene.call("clear_selected_units")
	return ""
