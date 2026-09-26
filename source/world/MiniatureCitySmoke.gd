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
	if int(sample.call("get_street_count")) != 4:
		sample.free()
		return "miniature city lacks four readable radial access streets"
	if int(sample.call("get_industrial_count")) != 4:
		sample.free()
		return "miniature city lacks industrial buildings on the outer edge"
	if int(sample.call("get_detail_count")) < 8:
		sample.free()
		return "miniature city facades lack readable window and band detail"
	sample.call("set_city_health", 0.45)
	if int(sample.call("get_damage_stage")) != 2:
		sample.free()
		return "miniature city did not enter critical damage stage"
	if int(sample.call("get_collapsed_building_count")) <= 0:
		sample.free()
		return "critical city damage did not collapse any buildings"
	sample.call("set_city_health", 0.20)
	if int(sample.call("get_rubble_count")) <= 0:
		sample.free()
		return "devastated city did not leave visible rubble"
	sample.call("set_city_health", 1.0)
	if int(sample.call("get_rubble_count")) != 0:
		sample.free()
		return "fully repaired city kept stale rubble"
	sample.call("set_city_health", 0.25)
	var rubble_before_repair := int(sample.call("get_rubble_count"))
	var repaired_health := float(sample.call("repair_city", 0.45))
	if absf(repaired_health - 0.70) > 0.001:
		sample.free()
		return "city repair progression did not restore health"
	if int(sample.call("get_rubble_count")) >= rubble_before_repair:
		sample.free()
		return "city repair did not clear destroyed building rubble"
	sample.free()
	var cities: Array = scene.call("get_city_markers")
	if cities.size() != 14:
		return "strategic terrain did not create fourteen miniature cities"
	for i in range(cities.size()):
		if int(cities[i].governorate_index) != i:
			return "miniature city governorate order is inconsistent"
		if str(cities[i].city_name_ar) != str(scene.GOVERNORATES[i]["name_ar"]):
			return "miniature city name does not match governorate city marker"
	if str(cities[0].call("get_style_id")) != "damascene":
		return "Damascus miniature city did not receive Damascene style"
	if str(cities[2].call("get_style_id")) != "aleppine":
		return "Aleppo miniature city did not receive Aleppine style"
	if str(cities[5].call("get_style_id")) != "coastal":
		return "Latakia miniature city did not receive coastal style"
	if str(cities[9].call("get_style_id")) != "eastern":
		return "Deir ez-Zor miniature city did not receive eastern style"
	if str(cities[12].call("get_style_id")) != "southern":
		return "Suwayda miniature city did not receive southern basalt style"
	scene.set("_terrain_mode", true)
	scene.set("_governorate_index", 2)
	scene.set("_center_lon", float(scene.GOVERNORATES[2]["lon"]))
	scene.set("_center_lat", float(scene.GOVERNORATES[2]["lat"]))
	scene.set("_origin_lon", float(scene.GOVERNORATES[2]["lon"]))
	scene.set("_origin_lat", float(scene.GOVERNORATES[2]["lat"]))
	scene.set("_rts_zoom_level", 5)
	scene.call("_sync_city_marker_positions")
	var visible_count := int(scene.call("get_visible_city_count"))
	if visible_count < 1 or visible_count >= 14:
		return "miniature city culling is not limiting local draw cost"
	if not bool(cities[2].visible):
		return "focused Aleppo miniature city was culled"
	if int(cities[2].lod_level) != 2:
		return "close miniature city LOD is not detailed"
	var label := cities[2].get_node_or_null("CityLabel") as Label3D
	if label == null or not label.visible:
		return "focused city label is not visible at close zoom"
	if not bool(scene.call("set_governorate_city_health", 2, 0.25)):
		return "could not set Aleppo city health"
	if absf(float(scene.call("get_governorate_city_health", 2)) - 0.25) > 0.001:
		return "Aleppo city health state was not persisted"
	if absf(float(cities[2].call("get_city_health")) - 0.25) > 0.001:
		return "runtime Aleppo marker did not receive city damage"
	if int(cities[2].call("get_damage_stage")) != 3:
		return "heavily damaged Aleppo marker did not enter devastated stage"
	var rubble_before := int(cities[2].call("get_rubble_count"))
	var repaired := float(scene.call("repair_governorate_city", 2, 0.50))
	if absf(repaired - 0.75) > 0.001:
		return "governorate city repair did not restore persistent health"
	if int(cities[2].call("get_rubble_count")) >= rubble_before:
		return "repaired governorate city did not clear rubble"
	for i in range(14):
		if float(scene.call("get_governorate_city_health", i)) < 0.0:
			return "one or more governorates lack city health state"
	return ""
