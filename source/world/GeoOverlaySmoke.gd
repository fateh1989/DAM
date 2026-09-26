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

	var world_id := scene.get_instance_id()
	if not bool(scene.get("_terrain_mode")):
		_fail(3, "Continuous geography smoke: DAM did not boot into the RTS world")
		return
	if scene.get_parent() != root or not is_instance_valid(scene) or scene.get_instance_id() != world_id:
		_fail(4, "Continuous geography smoke: world scene was replaced")
		return

	var geo_data: Dictionary = scene.get("_geo_overlay_data")
	if geo_data.is_empty():
		_fail(5, "Continuous geography smoke: Syria overlay data missing")
		return
	if geo_data.get("boundaries", []).size() < 1:
		_fail(6, "Continuous geography smoke: no administrative boundaries")
		return
	if geo_data.get("labels", []).size() < 10:
		_fail(7, "Continuous geography smoke: too few geography labels")
		return
	if scene.get_node_or_null("HUD/RTSRadar") == null:
		_fail(8, "Continuous geography smoke: RTS radar missing")
		return

	var army: Dictionary = scene.get_country_army_snapshot("syria")
	if army.is_empty():
		_fail(9, "Continuous geography smoke: persistent army not connected")
		return

	print("Continuous geography smoke: same RTS world + Syria geography + radar + persistent army OK")
	quit(0)
