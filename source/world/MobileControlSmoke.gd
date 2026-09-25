extends RefCounted

func run(scene: Node) -> String:
	var bar := scene.get_node_or_null("HUD/CommandBar") as Control
	var row := scene.get_node_or_null("HUD/CommandBar/Row") as Control
	var focus := scene.get_node_or_null("HUD/CommandBar/Row/FocusUnitsButton") as Button
	if bar == null or row == null or focus == null:
		return "mobile command surface is incomplete"
	if bar.mouse_filter != Control.MOUSE_FILTER_STOP or row.mouse_filter != Control.MOUSE_FILTER_STOP:
		return "command bar can leak pointer input to the world"
	scene.call("clear_selected_units")
	if not focus.disabled:
		return "focus command remained enabled without selection"
	scene.call("select_single_unit", 0)
	if focus.disabled:
		return "focus command did not enable after selection"
	scene.call("clear_selected_units")
	return ""
