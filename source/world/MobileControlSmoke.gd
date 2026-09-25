extends RefCounted

func run(scene: Node) -> String:
	var select_all := scene.get_node_or_null("HUD/CommandBar/Row/SelectAllUnitsButton") as Button
	var clear := scene.get_node_or_null("HUD/CommandBar/Row/ClearSelectionButton") as Button
	var stop := scene.get_node_or_null("HUD/CommandBar/Row/StopUnitsButton") as Button
	var previous := scene.get_node_or_null("HUD/CommandBar/Row/PreviousUnitButton") as Button
	var next := scene.get_node_or_null("HUD/CommandBar/Row/NextUnitButton") as Button
	if select_all == null or clear == null or stop == null or previous == null or next == null:
		return "mobile command buttons are missing"
	if select_all.custom_minimum_size.y < 56.0 or clear.custom_minimum_size.y < 56.0 or stop.custom_minimum_size.y < 56.0:
		return "core mobile command targets regressed"
	if previous.custom_minimum_size.x < 78.0 or next.custom_minimum_size.x < 78.0:
		return "previous/next unit touch targets are too narrow"
	if previous.custom_minimum_size.y < 56.0 or next.custom_minimum_size.y < 56.0:
		return "previous/next unit touch targets are too short"
	return ""
