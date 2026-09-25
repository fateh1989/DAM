extends RefCounted

func run(scene: Node) -> String:
	var select_all := scene.get_node_or_null("HUD/CommandBar/Row/SelectAllUnitsButton") as Button
	var clear := scene.get_node_or_null("HUD/CommandBar/Row/ClearSelectionButton") as Button
	var stop := scene.get_node_or_null("HUD/CommandBar/Row/StopUnitsButton") as Button
	if select_all == null or clear == null or stop == null:
		return "core mobile command buttons are missing"
	if select_all.custom_minimum_size.y < 56.0 or clear.custom_minimum_size.y < 56.0 or stop.custom_minimum_size.y < 56.0:
		return "core mobile command touch targets are too short"
	return ""
