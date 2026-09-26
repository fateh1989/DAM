extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://source/world/MiddleEastTerrain.tscn")
	if packed == null:
		push_error("Continuous world smoke: scene load failed")
		quit(2)
		return

	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var terrain_root := scene.get_node_or_null("Terrain")
	if terrain_root == null:
		push_error("Continuous world smoke: terrain root missing")
		quit(3)
		return
	var terrain_id := terrain_root.get_instance_id()

	if not is_instance_valid(scene._continuous_macro_node):
		push_error("Continuous world smoke: far-world LOD node missing")
		quit(4)
		return

	scene._set_rts_zoom_level(scene.RTS_ZOOM_LEVEL_MIN)
	await process_frame
	if not scene._continuous_macro_node.visible:
		push_error("Continuous world smoke: far LOD did not activate")
		quit(5)
		return
	if scene.get_node("Terrain").get_instance_id() != terrain_id:
		push_error("Continuous world smoke: far zoom rebuilt the terrain root")
		quit(6)
		return

	scene._set_rts_zoom_level(scene.RTS_ZOOM_LEVEL_MAX)
	await process_frame
	if scene._continuous_macro_node.visible:
		push_error("Continuous world smoke: near zoom did not restore detailed world")
		quit(7)
		return
	if scene.get_node("Terrain").get_instance_id() != terrain_id:
		push_error("Continuous world smoke: near zoom rebuilt the terrain root")
		quit(8)
		return

	print("Continuous world smoke: one terrain root survives full RTS zoom range")
	quit(0)
