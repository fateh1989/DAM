extends RefCounted

func run(scene: Node) -> String:
	var focus := scene.get_node_or_null("HUD/CommandBar/Row/FocusUnitsButton") as Button
	var clear := scene.get_node_or_null("HUD/CommandBar/Row/ClearSelectionButton") as Button
	var stop := scene.get_node_or_null("HUD/CommandBar/Row/StopUnitsButton") as Button
	if focus == null or clear == null or stop == null:
		return "selection-aware command buttons are missing"
	if focus.custom_minimum_size.x < 108.0 or focus.custom_minimum_size.y < 56.0:
		return "focus touch target is too small"
	scene.call("clear_selected_units")
	if not focus.disabled or not clear.disabled or not stop.disabled:
		return "selection-only commands remained enabled with no selection"
	scene.call("select_single_unit", 0)
	if focus.disabled or clear.disabled or stop.disabled:
		return "selection-only commands did not enable after selection"
	scene.call("clear_selected_units")
	return ""
