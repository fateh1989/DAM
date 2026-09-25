extends RefCounted

func run(scene: Node) -> String:
	scene.call("clear_selected_units")
	var group: Array[int] = [0, 1]
	scene.call("select_units", group)
	var items: Array = scene.call("get_radar_units")
	if items.size() < 2:
		return "radar unit metadata is incomplete"
	var secondary: Dictionary = items[0]
	var primary: Dictionary = items[1]
	if not bool(secondary.get("selected", false)) or bool(secondary.get("primary", false)):
		return "secondary radar selection metadata is wrong"
	if not bool(primary.get("selected", false)) or not bool(primary.get("primary", false)):
		return "primary radar selection metadata is wrong"
	scene.call("clear_selected_units")
	return ""
