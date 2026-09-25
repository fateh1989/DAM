extends RefCounted

const CLOCK_SCRIPT := preload("res://source/world/ProvinceClock.gd")


func run(_scene: Node) -> String:
	var clock := CLOCK_SCRIPT.new()
	clock.setup(2, "حلب")
	if clock.province_index != 2:
		return "province clock lost its province index"
	if clock.display_name != "حلب":
		return "province clock lost its display name"
	if clock.custom_minimum_size.x < 68.0 or clock.custom_minimum_size.x > 80.0:
		return "province clock width is outside medium mobile size"
	if clock.custom_minimum_size.y < 68.0 or clock.custom_minimum_size.y > 84.0:
		return "province clock height is outside medium mobile size"
	if not clock.has_method("_draw_station_ticks") or not clock.has_method("_draw_status_hands"):
		return "railway station clock face helpers are missing"
	clock.free()
	return ""
