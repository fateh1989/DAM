extends StaticBody3D

@onready var _collision_shape = find_child("CollisionShape3D")


func _ready():
	input_event.connect(_on_input_event)


func update_shape(reference_mesh):
	_collision_shape.shape = reference_mesh.create_trimesh_shape()


func _on_input_event(_camera, event, _click_position, _click_normal, _shape_idx):
	var is_order = (
		(event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed)
		or (event is InputEventScreenTouch and event.pressed and not get_tree().get_nodes_in_group("selected_units").is_empty())
	)
	if is_order:
		var target_point = get_viewport().get_camera_3d().get_ray_intersection(event.position)
		MatchSignals.terrain_targeted.emit(target_point)
