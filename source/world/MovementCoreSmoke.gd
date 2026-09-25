extends RefCounted

func run(scene: Node) -> String:
	scene.call("clear_selected_units")
	if bool(scene.call("issue_selected_group_move", Vector2(36.0, 35.0))):
		return "empty selection unexpectedly accepted a move order"
	var group: Array[int] = [0, 1]
	scene.call("select_units", group)
	if not bool(scene.call("issue_selected_group_move", Vector2(36.5, 35.5))):
		return "selected group move did not report success"
	if bool(scene.call("are_selected_units_stopped")):
		return "successful group move did not arm selected units"
	scene.call("stop_selected_units")
	scene.call("clear_selected_units")
	return ""
