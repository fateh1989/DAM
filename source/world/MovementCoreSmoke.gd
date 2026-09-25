extends RefCounted

func run(scene: Node) -> String:
	var group: Array[int] = [0, 1, 2, 3]
	scene.call("select_units", group)
	if not bool(scene.call("issue_selected_group_move", Vector2(36.5, 35.5))):
		return "formation move was rejected"
	var targets: Array = scene.call("get_selected_move_targets")
	if targets.size() != group.size():
		return "formation target count does not match selection"
	for i in range(targets.size()):
		for j in range(i + 1, targets.size()):
			var a: Vector2 = targets[i]
			var b: Vector2 = targets[j]
			if a.distance_to(b) <= 0.000001:
				return "group formation stacked two units on one target"
	scene.call("stop_selected_units")
	scene.call("clear_selected_units")
	return ""
