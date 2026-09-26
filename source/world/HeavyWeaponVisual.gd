extends Node3D

var weapon_type := "tank"
var family := "east"
var province_index := -1
var represented_count := 0

var _model_root: Node3D
var _count_label: Label3D

func setup(kind: String, requested_family: String, province: int, count: int) -> void:
	weapon_type = kind if kind in ["tank", "launcher", "artillery"] else "tank"
	family = requested_family if requested_family in ["west", "east"] else "east"
	province_index = province
	represented_count = maxi(0, count)
	_rebuild()


func _mat(color: Color, metallic: float = 0.18) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	material.metallic = metallic
	return material


func _box(parent: Node3D, name_value: String, position_value: Vector3, size_value: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size_value
	var node := MeshInstance3D.new()
	node.name = name_value
	node.mesh = mesh
	node.position = position_value
	node.material_override = material
	parent.add_child(node)
	return node


func _cylinder(parent: Node3D, name_value: String, position_value: Vector3, radius: float, height: float, material: Material, segments: int = 12) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	var node := MeshInstance3D.new()
	node.name = name_value
	node.mesh = mesh
	node.position = position_value
	node.material_override = material
	parent.add_child(node)
	return node


func _palette() -> Dictionary:
	if family == "west":
		return {
			"body": Color(0.48, 0.45, 0.36, 1.0),
			"dark": Color(0.18, 0.20, 0.18, 1.0),
			"metal": Color(0.34, 0.35, 0.31, 1.0),
		}
	return {
		"body": Color(0.27, 0.34, 0.22, 1.0),
		"dark": Color(0.14, 0.17, 0.13, 1.0),
		"metal": Color(0.29, 0.31, 0.26, 1.0),
	}


func _add_tracks(parent: Node3D, palette: Dictionary, length: float, width: float) -> void:
	for side in [-1.0, 1.0]:
		var x: float = float(side) * width * 0.5
		_box(parent, "Track_%s" % ("L" if side < 0.0 else "R"), Vector3(x, 0.22, 0), Vector3(0.28, 0.34, length), _mat(palette["dark"]))
		for wheel_index in range(6):
			var z := lerpf(-length * 0.38, length * 0.38, float(wheel_index) / 5.0)
			var wheel := _cylinder(parent, "Wheel_%s_%02d" % [("L" if side < 0.0 else "R"), wheel_index], Vector3(x, 0.21, z), 0.16, 0.08, _mat(palette["metal"]), 10)
			wheel.rotation_degrees = Vector3(0, 0, 90)


func _build_tank(parent: Node3D, palette: Dictionary) -> void:
	var western := family == "west"
	var hull_width := 1.82 if western else 1.62
	var hull_length := 2.85 if western else 2.60
	var hull_height := 0.48 if western else 0.40
	_add_tracks(parent, palette, hull_length * 0.96, hull_width)
	var hull := _box(parent, "Hull", Vector3(0, 0.46, 0), Vector3(hull_width, hull_height, hull_length), _mat(palette["body"]))
	hull.rotation_degrees.x = -2.0 if western else -4.0
	var glacis := _box(parent, "Glacis", Vector3(0, 0.58, -hull_length * 0.38), Vector3(hull_width * 0.86, 0.20, 0.62), _mat(palette["body"].lightened(0.04)))
	glacis.rotation_degrees.x = -18.0 if western else -24.0
	var turret_pivot := Node3D.new()
	turret_pivot.name = "TurretPivot"
	turret_pivot.position = Vector3(0, 0.79 if western else 0.72, -0.05)
	parent.add_child(turret_pivot)
	var turret_size := Vector3(1.42, 0.48, 1.52) if western else Vector3(1.20, 0.40, 1.28)
	var turret := _box(turret_pivot, "Turret", Vector3.ZERO, turret_size, _mat(palette["body"].lightened(0.05)))
	turret.rotation_degrees.y = 0.0
	if not western:
		var dome := _cylinder(turret_pivot, "TurretDome", Vector3(0, 0.18, 0), 0.50, 0.24, _mat(palette["body"].lightened(0.03)), 14)
		dome.scale.z = 0.88
	var barrel_pivot := Node3D.new()
	barrel_pivot.name = "BarrelPivot"
	barrel_pivot.position = Vector3(0, 0.02, -turret_size.z * 0.47)
	turret_pivot.add_child(barrel_pivot)
	_box(barrel_pivot, "Barrel", Vector3(0, 0, -1.20), Vector3(0.13, 0.13, 2.35), _mat(palette["metal"], 0.35))
	_box(turret_pivot, "RearStowage", Vector3(0, 0.05, turret_size.z * 0.53), Vector3(turret_size.x * 0.72, 0.22, 0.30), _mat(palette["dark"]))


func _build_launcher(parent: Node3D, palette: Dictionary) -> void:
	var western := family == "west"
	var chassis_width := 1.72 if western else 1.62
	var chassis_length := 2.90
	_add_tracks(parent, palette, chassis_length * 0.94, chassis_width)
	_box(parent, "Hull", Vector3(0, 0.43, 0), Vector3(chassis_width, 0.42, chassis_length), _mat(palette["body"]))
	var pivot := Node3D.new()
	pivot.name = "LauncherPivot"
	pivot.position = Vector3(0, 0.88, 0.15)
	parent.add_child(pivot)
	var pod_count := 2 if western else 3
	for pod_index in range(pod_count):
		var x: float = (float(pod_index) - float(pod_count - 1) * 0.5) * 0.48
		_box(pivot, "RocketPod_%02d" % pod_index, Vector3(x, 0.12, -0.20), Vector3(0.40, 0.44, 1.55), _mat(palette["dark"]))
		for tube_index in range(4):
			var tx: float = x + (-0.11 if tube_index % 2 == 0 else 0.11)
			var ty := 0.04 + (0.16 if tube_index >= 2 else 0.0)
			_cylinder(pivot, "Tube_%02d_%02d" % [pod_index, tube_index], Vector3(tx, ty, -1.03), 0.045, 0.22, _mat(palette["metal"]), 8).rotation_degrees = Vector3(90, 0, 0)


func _build_artillery(parent: Node3D, palette: Dictionary) -> void:
	var western := family == "west"
	var chassis_width := 1.72 if western else 1.60
	var chassis_length := 2.78
	_add_tracks(parent, palette, chassis_length * 0.94, chassis_width)
	_box(parent, "Hull", Vector3(0, 0.43, 0), Vector3(chassis_width, 0.42, chassis_length), _mat(palette["body"]))
	var turret_pivot := Node3D.new()
	turret_pivot.name = "TurretPivot"
	turret_pivot.position = Vector3(0, 0.84, 0.18)
	parent.add_child(turret_pivot)
	_box(turret_pivot, "Turret", Vector3(0, 0, 0), Vector3(1.35 if western else 1.18, 0.52 if western else 0.46, 1.30 if western else 1.18), _mat(palette["body"].lightened(0.04)))
	if western:
		_box(turret_pivot, "RearAmmoBox", Vector3(0, 0.04, 0.72), Vector3(1.08, 0.34, 0.34), _mat(palette["dark"]))
	else:
		_cylinder(turret_pivot, "CommanderCupola", Vector3(0.34, 0.34, 0.10), 0.15, 0.16, _mat(palette["dark"]), 10)
	var barrel_pivot := Node3D.new()
	barrel_pivot.name = "BarrelPivot"
	barrel_pivot.position = Vector3(0, 0.04, -0.58)
	barrel_pivot.rotation_degrees.x = -10.0
	turret_pivot.add_child(barrel_pivot)
	_box(barrel_pivot, "Barrel", Vector3(0, 0, -1.55), Vector3(0.15, 0.15, 3.10), _mat(palette["metal"], 0.35))
	_box(turret_pivot, "BreechHousing", Vector3(0, 0.03, -0.48), Vector3(0.40, 0.30, 0.48), _mat(palette["dark"]))


func _rebuild() -> void:
	for child in get_children():
		child.free()
	var palette := _palette()
	_model_root = Node3D.new()
	_model_root.name = "Model"
	add_child(_model_root)
	match weapon_type:
		"launcher": _build_launcher(_model_root, palette)
		"artillery": _build_artillery(_model_root, palette)
		_: _build_tank(_model_root, palette)
	_count_label = Label3D.new()
	_count_label.name = "CountLabel"
	_count_label.text = "×%d" % represented_count
	_count_label.position = Vector3(0, 1.45, 0)
	_count_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_count_label.font_size = 30
	_count_label.pixel_size = 0.012
	_count_label.outline_size = 5
	_count_label.modulate = Color(0.98, 0.94, 0.82, 1)
	_count_label.outline_modulate = Color(0.03, 0.03, 0.03, 0.95)
	add_child(_count_label)


func set_aim_yaw(degrees: float) -> bool:
	var pivot_name := "LauncherPivot" if weapon_type == "launcher" else "TurretPivot"
	var pivot := get_part(pivot_name) as Node3D
	if pivot == null:
		return false
	pivot.rotation_degrees.y = wrapf(degrees, -180.0, 180.0)
	return true


func get_aim_yaw() -> float:
	var pivot_name := "LauncherPivot" if weapon_type == "launcher" else "TurretPivot"
	var pivot := get_part(pivot_name) as Node3D
	return 0.0 if pivot == null else pivot.rotation_degrees.y


func set_represented_count(value: int) -> void:
	represented_count = maxi(0, value)
	if _count_label != null:
		_count_label.text = "×%d" % represented_count


func get_part(name_value: String) -> Node:
	if _model_root == null:
		return null
	return _model_root.find_child(name_value, true, false)


func get_model_root() -> Node3D:
	return _model_root


func get_launcher_pod_count() -> int:
	if _model_root == null:
		return 0
	var count := 0
	for child in _model_root.get_children():
		if str(child.name).begins_with("LauncherPivot"):
			for item in child.get_children():
				if str(item.name).begins_with("RocketPod_"):
					count += 1
	return count


func get_visual_signature() -> Dictionary:
	var turret := get_part("Turret")
	var hull := get_part("Hull")
	var signature := {
		"weapon_type": weapon_type,
		"family": family,
		"represented_count": represented_count,
	}
	if turret is MeshInstance3D and turret.mesh is BoxMesh:
		signature["turret_size"] = (turret.mesh as BoxMesh).size
	if hull is MeshInstance3D and hull.mesh is BoxMesh:
		signature["hull_size"] = (hull.mesh as BoxMesh).size
	return signature
