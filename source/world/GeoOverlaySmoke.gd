extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _fail(code: int, message: String) -> void:
	push_error(message)
	quit(code)


func _run() -> void:
	var packed := load("res://source/world/MiddleEastTerrain.tscn")
	if packed == null:
		_fail(2, "Continuous geography smoke: scene load failed")
		return

	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	if scene._geo_overlay_data.is_empty():
		_fail(3, "Continuous geography smoke: Syria overlay data missing")
		return
	if scene._geo_overlay_data.get("boundaries", []).size() < 1:
		_fail(4, "Continuous geography smoke: no administrative boundaries")
		return
	if scene._geo_overlay_data.get("labels", []).size() < 10:
		_fail(5, "Continuous geography smoke: too few geography labels")
		return
	if scene.get_node_or_null("HUD/RTSRadar") == null:
		_fail(6, "Continuous geography smoke: RTS radar missing")
		return

	var world_before := scene.get_node_or_null("Terrain")
	if world_before == null:
		_fail(7, "Continuous geography smoke: terrain root missing")
		return
	var world_id := world_before.get_instance_id()

	scene._set_rts_zoom_level(scene.RTS_ZOOM_LEVEL_MIN)
	await process_frame
	scene._set_rts_zoom_level(scene.RTS_ZOOM_LEVEL_MAX)
	await process_frame

	var world_after := scene.get_node_or_null("Terrain")
	if world_after == null or world_after.get_instance_id() != world_id:
		_fail(8, "Continuous geography smoke: zoom replaced the world")
		return

	var army: Dictionary = scene.get_country_army_snapshot("syria")
	if army.is_empty():
		_fail(9, "Continuous geography smoke: persistent army not connected")
		return

	print("Continuous geography smoke: Syria data + RTS radar + one persistent world + army OK")
	quit(0)
