extends RefCounted

func run(scene: Node) -> String:
	var group: Array[int] = [0, 1, 2, 3]
	scene.call("select_units", group)
	if not bool(scene.call("issue_selected_group_move", Vector2(36.5, 35.5))):
		return "first formation move was rejected"
	var units: Array = scene.get("_units")
	var first_serial := int((units[0] as Dictionary).get("move_order_serial", 0))
	var first_targets: Array = scene.call("get_selected_move_targets")
	if first_serial <= 0:
		return "first movement order did not receive a serial"
	if not bool(scene.call("issue_selected_group_move", Vector2(37.0, 35.8))):
		return "replacement formation move was rejected"
	units = scene.get("_units")
	var second_serial := int((units[0] as Dictionary).get("move_order_serial", 0))
	var second_targets: Array = scene.call("get_selected_move_targets")
	if second_serial <= first_serial:
		return "replacement movement order did not supersede old order"
	if first_targets.size() != second_targets.size() or first_targets.is_empty():
		return "movement target snapshots are inconsistent"
	var any_changed := false
	for i in range(first_targets.size()):
		var a: Vector2 = first_targets[i]
		var b: Vector2 = second_targets[i]
		if a.distance_to(b) > 0.000001:
			any_changed = true
	if not any_changed:
		return "replacement movement order kept stale targets"
	scene.call("stop_selected_units")
	scene.call("clear_selected_units")
	return ""
