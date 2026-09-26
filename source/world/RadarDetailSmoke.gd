extends RefCounted

func run(scene: Node) -> String:
	var original_zoom := int(scene.call("get_rts_zoom_level"))
	var detail_zoom := int(scene.call("get_rts_detail_lod_min"))
	scene.call("_set_rts_zoom_level", detail_zoom)
	var radar_units: Array = scene.call("get_radar_units")
	var focused_governorate := int(scene.get("_governorate_index"))
	var focused_detail := 0
	var sample_detail: Dictionary = {}
	for raw_item in radar_units:
		var item: Dictionary = raw_item
		if bool(item.get("logical_detail", false)) and int(item.get("governorate_index", -1)) == focused_governorate:
			focused_detail += 1
			if sample_detail.is_empty():
				sample_detail = item
	if focused_detail < 90:
		scene.call("_set_rts_zoom_level", original_zoom)
		return "close radar does not expose enough persistent heavy units"
	if sample_detail.is_empty():
		scene.call("_set_rts_zoom_level", original_zoom)
		return "close radar has no persistent detail target"
	var sample_id := str(sample_detail.get("logical_id", ""))
	if sample_id.is_empty():
		scene.call("_set_rts_zoom_level", original_zoom)
		return "persistent radar detail has no logical id"
	if not bool(scene.call("select_nearest_radar_target_uv", sample_detail.get("uv", Vector2.ZERO), 0.002)):
		scene.call("_set_rts_zoom_level", original_zoom)
		return "persistent radar target could not be selected"
	var selected_ids: Array[String] = scene.call("get_selected_logical_heavy_ids")
	if selected_ids.size() != 1 or selected_ids[0] != sample_id:
		scene.call("_set_rts_zoom_level", original_zoom)
		return "radar selection did not reach exact persistent unit state"
	scene.call("clear_logical_heavy_selection")
	scene.call("_set_rts_zoom_level", original_zoom)
	if int(scene.call("get_rts_zoom_level")) != original_zoom:
		return "radar detail smoke did not restore original zoom"
	return ""
