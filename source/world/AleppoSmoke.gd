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
	print("Aleppo smoke vectors=", vector_count, " labels=", label_count)

	if vector_count < 10:
		push_error("Aleppo smoke: real vector objects were not generated")
		quit(4)
		return

	if label_count < 1:
		push_error("Aleppo smoke: place labels were not generated")
		quit(5)
		return

	quit(0)
