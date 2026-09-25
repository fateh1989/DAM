extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://source/world/MiddleEastTerrain.tscn")
	if packed == null:
		push_error("Aleppo smoke: scene load failed")
		quit(2)
		return

	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame

	scene._on_mode_pressed()
	await process_frame
	await process_frame

	if not scene._terrain_mode:
		push_error("Aleppo smoke: terrain mode did not activate")
		quit(3)
		return

	if scene._native_core == null:
		push_error("Aleppo smoke: DAM native C++ core is not loaded")
		quit(8)
		return

	var tactical_shader_found := false
	for child in scene.terrain_root.get_children():
		if child is MeshInstance3D and child.material_override is ShaderMaterial:
			tactical_shader_found = true
			break
	if not tactical_shader_found:
		push_error("Aleppo smoke: tactical continuous ground shader is missing")
		quit(9)
		return

	scene._refresh_vector_data(true)
	await process_frame

	var vector_count: int = int(scene.vector_root.get_child_count())
	var label_count: int = int(scene.labels_root.get_child_count())
	var feature_count: int = int(scene._feature_count)
	var cell_level_count := 0
	for state in scene._tiles.values():
		var levels = state.get("cell_levels", PackedInt32Array())
		cell_level_count += levels.size()
	print("Aleppo smoke draw_nodes=", vector_count, " features=", feature_count, " labels=", label_count, " cell_levels=", cell_level_count, " trees=", scene._tree_instance_count, " cliffs=", scene._cliff_face_count)

	if cell_level_count < 100:
		push_error("Aleppo smoke: designed terrain cell mesh was not generated")
		quit(6)
		return

	if feature_count < 20:
		push_error("Aleppo smoke: art-directed battlefield features were not generated")
		quit(4)
		return

	if vector_count < 5 or vector_count > 8:
		push_error("Aleppo smoke: art-directed battlefield batches are missing")
		quit(7)
		return

	if scene._tree_instance_count < 80:
		push_error("Aleppo smoke: art-directed vegetation is missing")
		quit(10)
		return

	if label_count < 1:
		push_error("Aleppo smoke: place labels were not generated")
		quit(5)
		return

	quit(0)
