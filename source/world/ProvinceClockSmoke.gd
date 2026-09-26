extends RefCounted

const CLOCK_SCRIPT := preload("res://source/world/ProvinceClock.gd")


func run(scene: Node) -> String:
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
	var capture := {"index": -1}
	clock.province_requested.connect(func(index: int): capture["index"] = index)
	clock.emit_signal("pressed")
	if int(capture["index"]) != 2:
		return "province clock press did not emit its province index"
	if not bool(scene.call("focus_governorate_from_clock", 2)):
		return "world rejected valid province clock navigation"
	if int(scene.get("_governorate_index")) != 2:
		return "province clock navigation did not focus requested governorate"
	var name_label := clock.get_node_or_null("ProvinceName") as Label
	if name_label == null:
		return "province name label is missing"
	if name_label.get_theme_font_size("font_size") < 11 or name_label.get_theme_font_size("font_size") > 14:
		return "province name font is not medium sized"
	clock.set_military_status(0.95, 0.95)
	var strong_color: Color = clock.get_status_color()
	clock.set_military_status(0.10, 0.10)
	var weak_color: Color = clock.get_status_color()
	if strong_color == weak_color:
		return "clock color does not react to strength and readiness"
	if clock.get_status_score() > 0.20:
		return "weak province readiness score is incorrect"
	clock.set_attacking_state(true)
	if not clock.attacking:
		return "attack state did not enable province steam"
	if not clock.has_method("_draw_attack_steam"):
		return "province attack steam renderer is missing"
	clock.set_attacking_state(false)
	clock.set_selected_state(true)
	if not clock.selected_province:
		return "selected province highlight state was not retained"
	clock.set_selected_state(false)
	clock.free()

	var clocks: Array = scene.call("get_province_clocks")
	if clocks.size() != scene.GOVERNORATES.size() or clocks.size() != 14:
		return "strategic HUD did not create all 14 province clocks"
	for i in range(clocks.size()):
		var item = clocks[i]
		if int(item.province_index) != i:
			return "province clock index order is inconsistent"
		if str(item.display_name).is_empty():
			return "province clock is missing its governorate name"
	var grid := scene.get_node_or_null("HUD/ProvinceClockPanel/Grid") as GridContainer
	var old_bar := scene.get_node_or_null("HUD/GovernorateBar") as Control
	if grid == null or grid.columns != 7:
		return "province clocks are not arranged as a seven-by-two mobile grid"
	if old_bar == null or old_bar.visible:
		return "legacy governorate strip still competes with province clocks"
	return ""
