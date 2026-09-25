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
		push_error("Aleppo smoke: cell engine did not compile terrain cells")
		quit(6)
		return

	if feature_count < 100:
		push_error("Aleppo smoke: real vector features were not generated")
		quit(4)
		return

	if vector_count > 8:
		push_error("Aleppo smoke: vector features were not batched")
		quit(7)
		return

	if label_count < 1:
		push_error("Aleppo smoke: place labels were not generated")
		quit(5)
		return

	quit(0)
