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

	if not scene._terrain_mode:
		push_error("Continuous world smoke: DAM did not start in the single RTS world")
		quit(3)
		return

	if not is_instance_valid(scene._continuous_macro_node):
		push_error("Continuous world smoke: continuous world macro LOD is missing")
		quit(4)
		return

	var world_node_id := scene._continuous_macro_node.get_instance_id()

	scene._set_rts_zoom_level(scene.RTS_ZOOM_LEVEL_MIN)
	await process_frame
	await process_frame
	if not scene._terrain_mode:
		push_error("Continuous world smoke: far zoom left the RTS world")
		quit(5)
		return
	if not is_instance_valid(scene._continuous_macro_node) or scene._continuous_macro_node.get_instance_id() != world_node_id:
		push_error("Continuous world smoke: far zoom rebuilt/replaced the world")
		quit(6)
		return
	if not scene._continuous_macro_node.visible:
		push_error("Continuous world smoke: far LOD did not activate")
		quit(7)
		return

	scene._set_rts_zoom_level(scene.RTS_ZOOM_LEVEL_MAX)
	await process_frame
	await process_frame
	if not scene._terrain_mode:
		push_error("Continuous world smoke: near zoom left the RTS world")
		quit(8)
		return
	if not is_instance_valid(scene._continuous_macro_node) or scene._continuous_macro_node.get_instance_id() != world_node_id:
		push_error("Continuous world smoke: near zoom rebuilt/replaced the world")
		quit(9)
		return
	if scene._continuous_macro_node.visible:
		push_error("Continuous world smoke: near LOD did not restore detailed world")
		quit(10)
		return

	print("Continuous world smoke: same world survives far/near RTS zoom with LOD OK")
	quit(0)
