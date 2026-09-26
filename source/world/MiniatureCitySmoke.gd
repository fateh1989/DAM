extends RefCounted

const CITY_SCRIPT := preload("res://source/world/MiniatureCity.gd")

func run(scene: Node) -> String:
	var sample := CITY_SCRIPT.new()
	sample.setup(2, "حلب", "central")
	if sample.governorate_index != 2 or sample.city_name_ar != "حلب":
		sample.free()
		return "miniature city lost identity"
	if sample.get_node_or_null("Body") == null:
		sample.free()
		return "miniature city body was not created"
	if int(sample.call("get_building_count")) < 25:
		sample.free()
		return "miniature city does not contain a readable building cluster"
	if float(sample.call("get_core_clear_radius")) <= 0.08:
		sample.free()
		return "miniature city has no protected landmark core"
	sample.free()
	return ""
