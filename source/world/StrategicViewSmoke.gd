extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://source/world/MiddleEastTerrain.tscn")
	if packed == null:
		push_error("Strategic smoke: scene load failed")
		quit(2)
		return

	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame

	scene._set_map_zoom(scene.SYRIA_OVERVIEW_ZOOM, true)
	await process_frame
	await process_frame

	if not scene._is_strategic_map():
		push_error("Strategic smoke: Syria overview did not activate")
		quit(3)
		return

	if not is_instance_valid(scene._strategic_node):
		push_error("Strategic smoke: global Syria macro mesh is missing")
		quit(4)
		return

	if scene._strategic_node.name != "StrategicSyriaMacro":
		push_error("Strategic smoke: wrong strategic node")
		quit(5)
		return

	if not (scene._strategic_node.material_override is ShaderMaterial):
		push_error("Strategic smoke: macro shader material is missing")
		quit(6)
		return

	print("Strategic smoke: global macro mesh + shader OK")
	quit(0)
