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
	var name_label := clock.get_node_or_null("ProvinceName") as Label
	if name_label == null:
		return "province name label is missing"
	if name_label.get_theme_font_size("font_size") < 11 or name_label.get_theme_font_size("font_size") > 14:
		return "province name font is not medium sized"
	clock.free()
	return ""
