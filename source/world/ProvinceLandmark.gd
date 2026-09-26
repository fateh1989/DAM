extends Node3D

var governorate_index := -1
var landmark_name_ar := ""
var landmark_name_en := ""
var archetype := "monument"
var selected_landmark := false
var lod_level := 1
var damage_state := "intact"
var _body_root: Node3D
var _label: Label3D
var _highlight: MeshInstance3D


func setup(index: int, name_ar: String, name_en: String, kind: String) -> void:
	governorate_index = index
	landmark_name_ar = name_ar
	landmark_name_en = name_en
	archetype = kind
	_build()


func _ready() -> void:
	if _body_root == null:
		_build()


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	return mat


func _add_box(pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color)
	_body_root.add_child(node)
	return node


func _add_sphere(pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color)
	_body_root.add_child(node)
	return node


func _add_cylinder(pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color)
	_body_root.add_child(node)
	return node


func _clear_body() -> void:
	if _body_root != null and is_instance_valid(_body_root):
		_body_root.free()
	_body_root = Node3D.new()
	_body_root.name = "Body"
	add_child(_body_root)


func _build() -> void:
	_clear_body()
	var stone := Color(0.58, 0.49, 0.34, 1.0)
	var dark_stone := Color(0.38, 0.33, 0.26, 1.0)
	var wood := Color(0.28, 0.19, 0.10, 1.0)
	match archetype:
		"city":
			var city_stone := Color(0.52, 0.48, 0.38, 1.0)
			var city_dark := Color(0.34, 0.35, 0.32, 1.0)
			var city_light := Color(0.68, 0.62, 0.48, 1.0)
			var plaza := _add_box(Vector3(0, 0.009, 0), Vector3(0.34, 0.018, 0.28), Color(0.30, 0.29, 0.25, 1.0))
			plaza.name = "CityPlaza"
			var road_ns := _add_box(Vector3(0.0, 0.020, 0.0), Vector3(0.030, 0.006, 0.25), Color(0.16, 0.17, 0.16, 1.0))
			road_ns.name = "CityRoadNS"
			var road_ew := _add_box(Vector3(0.0, 0.020, 0.0), Vector3(0.30, 0.006, 0.028), Color(0.16, 0.17, 0.16, 1.0))
			road_ew.name = "CityRoadEW"
			var center := _add_box(Vector3(0.0, 0.090, -0.015), Vector3(0.075, 0.18, 0.070), city_light)
			center.name = "CityCenter"
			var b1 := _add_box(Vector3(-0.105, 0.050, -0.070), Vector3(0.080, 0.10, 0.070), city_stone)
			b1.name = "CityBlock_01"
			var b2 := _add_box(Vector3(0.105, 0.065, -0.065), Vector3(0.082, 0.13, 0.072), city_dark)
			b2.name = "CityBlock_02"
			var b3 := _add_box(Vector3(-0.110, 0.065, 0.060), Vector3(0.075, 0.13, 0.075), city_dark)
			b3.name = "CityBlock_03"
			var b4 := _add_box(Vector3(0.105, 0.047, 0.070), Vector3(0.088, 0.094, 0.072), city_stone)
			b4.name = "CityBlock_04"
			var b5 := _add_box(Vector3(-0.020, 0.038, 0.105), Vector3(0.095, 0.076, 0.055), city_stone)
			b5.name = "CityBlock_05"
			var industrial := _add_box(Vector3(0.115, 0.037, 0.105), Vector3(0.085, 0.074, 0.050), Color(0.40, 0.41, 0.38, 1.0))
			industrial.name = "CityIndustrialHall"
			var tower := _add_cylinder(Vector3(0.120, 0.105, 0.015), 0.018, 0.21, city_light)
			tower.name = "CityTower"
		"citadel", "castle":
			_add_box(Vector3(0, 0.035, 0), Vector3(0.22, 0.07, 0.18), stone)
			for x in [-0.085, 0.085]:
				for z in [-0.065, 0.065]:
					_add_cylinder(Vector3(x, 0.075, z), 0.028, 0.15, dark_stone)
		"mosque":
			_add_box(Vector3(0, 0.03, 0), Vector3(0.20, 0.06, 0.14), stone)
			_add_cylinder(Vector3(0.075, 0.11, -0.04), 0.014, 0.22, dark_stone)
			_add_cylinder(Vector3(-0.045, 0.075, 0.0), 0.04, 0.09, stone)
			_add_sphere(Vector3(-0.045, 0.118, 0.0), 0.045, stone)
		"noria":
			_add_box(Vector3(0, 0.01, 0), Vector3(0.20, 0.02, 0.08), stone)
			var wheel := _add_cylinder(Vector3(0, 0.085, 0), 0.075, 0.018, wood)
			wheel.rotation_degrees = Vector3(90, 0, 0)
			for spoke_index in range(8):
				var spoke := _add_box(Vector3(0, 0.085, 0), Vector3(0.14, 0.008, 0.008), wood)
				spoke.rotation_degrees = Vector3(0, 0, float(spoke_index) * 22.5)
		"bridge":
			_add_box(Vector3(0, 0.025, 0), Vector3(0.30, 0.025, 0.055), stone)
			_add_box(Vector3(-0.09, 0.09, 0), Vector3(0.035, 0.18, 0.05), dark_stone)
			_add_box(Vector3(0.09, 0.09, 0), Vector3(0.035, 0.18, 0.05), dark_stone)
			_add_box(Vector3(0, 0.155, 0), Vector3(0.22, 0.012, 0.018), dark_stone)
		"village":
			_add_box(Vector3(-0.055, 0.035, 0), Vector3(0.09, 0.07, 0.08), stone)
			_add_box(Vector3(0.045, 0.060, -0.02), Vector3(0.08, 0.12, 0.07), dark_stone)
			_add_box(Vector3(0.015, 0.025, 0.07), Vector3(0.10, 0.05, 0.07), stone)
		"gate":
			_add_box(Vector3(-0.07, 0.075, 0), Vector3(0.045, 0.15, 0.055), dark_stone)
			_add_box(Vector3(0.07, 0.075, 0), Vector3(0.045, 0.15, 0.055), dark_stone)
			_add_box(Vector3(0, 0.135, 0), Vector3(0.18, 0.035, 0.055), stone)
		"ruins", "theatre":
			for x in [-0.075, -0.025, 0.025, 0.075]:
				_add_cylinder(Vector3(x, 0.065, 0), 0.012, 0.13, stone)
			_add_box(Vector3(0, 0.135, 0), Vector3(0.19, 0.025, 0.04), dark_stone)
		_:
			_add_box(Vector3(0, 0.06, 0), Vector3(0.12, 0.12, 0.12), stone)

	if archetype == "city":
		if damage_state == "damaged":
			for i in range(_body_root.get_child_count()):
				var part := _body_root.get_child(i) as Node3D
				if part != null and i > 0:
					part.scale.y *= 0.72 if i % 2 == 0 else 0.88
					part.rotation_degrees.z = -7.0 if i % 3 == 0 else 3.0
		elif damage_state == "rubble":
			for i in range(_body_root.get_child_count()):
				var part := _body_root.get_child(i) as Node3D
				if part != null and i > 0:
					part.scale.y *= 0.24
					part.rotation_degrees.z = float((i % 3) - 1) * 13.0
		elif damage_state == "rebuilt":
			_body_root.scale = Vector3.ONE * 1.04

	if _label == null or not is_instance_valid(_label):
		_label = Label3D.new()
		_label.name = "LandmarkLabel"
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.font_size = 28
		_label.pixel_size = 0.0018
		_label.outline_size = 4
		_label.modulate = Color(0.96, 0.88, 0.67, 1.0)
		_label.outline_modulate = Color(0.05, 0.05, 0.04, 0.95)
		add_child(_label)
	_label.text = landmark_name_ar
	_label.position = Vector3(0, 0.23, 0)
	_label.visible = false

	if _highlight == null or not is_instance_valid(_highlight):
		var ring_mesh := CylinderMesh.new()
		ring_mesh.top_radius = 0.14
		ring_mesh.bottom_radius = 0.14
		ring_mesh.height = 0.006
		ring_mesh.radial_segments = 24
		_highlight = MeshInstance3D.new()
		_highlight.name = "Highlight"
		_highlight.mesh = ring_mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.72, 0.18, 0.28)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_highlight.material_override = mat
		add_child(_highlight)
	_highlight.position = Vector3(0, 0.004, 0)
	_highlight.visible = selected_landmark


func set_damage_state(value: String) -> bool:
	if value not in ["intact", "damaged", "rubble", "rebuilt"]:
		return false
	damage_state = value
	if archetype == "city":
		_build()
	return true


func set_label_visible(value: bool) -> void:
	if _label != null:
		_label.visible = value


func set_selected(value: bool) -> void:
	selected_landmark = value
	if _highlight != null:
		_highlight.visible = value


func set_lod(level: int) -> void:
	lod_level = clampi(level, 0, 2)
	if _body_root != null:
		_body_root.visible = lod_level > 0
		if archetype == "city":
			_body_root.scale = Vector3.ONE * (1.08 if lod_level == 1 else 1.32)
		else:
			_body_root.scale = Vector3.ONE * (0.82 if lod_level == 1 else 1.0)
