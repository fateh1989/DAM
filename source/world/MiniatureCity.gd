extends Node3D

var governorate_index := -1
var city_name_ar := ""
var style_id := "central"
var lod_level := 2

var _body_root: Node3D = null
var _street_root: Node3D = null
var _industrial_root: Node3D = null
var _building_nodes: Array[MeshInstance3D] = []
var _industrial_nodes: Array[Node3D] = []
var _street_nodes: Array[MeshInstance3D] = []
var _label: Label3D = null

const CITY_RADIUS := 0.46
const CORE_CLEAR_RADIUS := 0.095
const RING_RADII := [0.16, 0.27, 0.385]
const RING_COUNTS := [8, 14, 18]


func setup(index: int, name_ar: String, requested_style: String = "central") -> void:
	governorate_index = index
	city_name_ar = name_ar
	style_id = requested_style
	_rebuild()


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.94
	return mat


func _palette() -> Dictionary:
	match style_id:
		"damascene":
			return {"wall":Color(0.72,0.65,0.52,1),"roof":Color(0.30,0.24,0.20,1),"accent":Color(0.20,0.18,0.17,1),"road":Color(0.18,0.17,0.15,1),"base":Color(0.43,0.39,0.29,1)}
		"aleppine":
			return {"wall":Color(0.66,0.58,0.44,1),"roof":Color(0.42,0.33,0.25,1),"accent":Color(0.52,0.44,0.33,1),"road":Color(0.20,0.19,0.17,1),"base":Color(0.42,0.38,0.30,1)}
		"coastal":
			return {"wall":Color(0.77,0.74,0.64,1),"roof":Color(0.48,0.31,0.24,1),"accent":Color(0.32,0.45,0.34,1),"road":Color(0.22,0.22,0.20,1),"base":Color(0.39,0.45,0.33,1)}
		"eastern":
			return {"wall":Color(0.69,0.58,0.39,1),"roof":Color(0.45,0.34,0.22,1),"accent":Color(0.56,0.45,0.29,1),"road":Color(0.22,0.20,0.17,1),"base":Color(0.49,0.41,0.26,1)}
		"southern":
			return {"wall":Color(0.47,0.45,0.42,1),"roof":Color(0.28,0.27,0.26,1),"accent":Color(0.58,0.53,0.44,1),"road":Color(0.17,0.17,0.17,1),"base":Color(0.35,0.34,0.31,1)}
		_:
			return {"wall":Color(0.63,0.55,0.42,1),"roof":Color(0.38,0.29,0.22,1),"accent":Color(0.48,0.42,0.31,1),"road":Color(0.19,0.18,0.16,1),"base":Color(0.40,0.37,0.27,1)}


func get_style_id() -> String:
	return style_id


func _hash01(seed: int, salt: float) -> float:
	var value := sin(float(seed) * 12.9898 + salt * 78.233) * 43758.5453
	return value - floor(value)


func _add_box(parent: Node3D, position_value: Vector3, size_value: Vector3, mat: Material, node_name: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size_value
	var item := MeshInstance3D.new()
	item.name = node_name
	item.mesh = mesh
	item.position = position_value
	item.material_override = mat
	parent.add_child(item)
	return item


func _ensure_roots() -> void:
	_body_root = Node3D.new()
	_body_root.name = "Body"
	add_child(_body_root)
	_street_root = Node3D.new()
	_street_root.name = "Streets"
	add_child(_street_root)
	_industrial_root = Node3D.new()
	_industrial_root.name = "Industrial"
	add_child(_industrial_root)


func _build_base(palette: Dictionary) -> void:
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = CITY_RADIUS
	base_mesh.bottom_radius = CITY_RADIUS
	base_mesh.height = 0.012
	base_mesh.radial_segments = 32
	var base := MeshInstance3D.new()
	base.name = "CityFootprint"
	base.mesh = base_mesh
	base.position.y = 0.006
	base.material_override = _material(palette["base"])
	_body_root.add_child(base)


func _is_street_gap(angle: float) -> bool:
	var normalized := fposmod(angle, TAU)
	for axis in [0.0, PI * 0.5, PI, PI * 1.5]:
		var delta := absf(wrapf(normalized - float(axis), -PI, PI))
		if delta < 0.10:
			return true
	return false


func _build_radial_streets(palette: Dictionary) -> void:
	var road_mat := _material(palette["road"])
	var segment_length := 0.31
	var center_offset := CORE_CLEAR_RADIUS + segment_length * 0.5
	for direction_index in range(4):
		var angle := float(direction_index) * PI * 0.5
		var p := Vector3(cos(angle) * center_offset, 0.014, sin(angle) * center_offset)
		var road := _add_box(_street_root, p, Vector3(segment_length, 0.008, 0.026), road_mat, "RadialRoad_%02d" % direction_index)
		road.rotation.y = -angle
		_street_nodes.append(road)


func _build_residential_rings(palette: Dictionary) -> void:
	var wall_mat := _material(palette["wall"])
	var roof_mat := _material(palette["roof"])
	for ring_index in range(RING_RADII.size()):
		var radius: float = float(RING_RADII[ring_index])
		var count: int = int(RING_COUNTS[ring_index])
		for slot in range(count):
			var seed := governorate_index * 97 + ring_index * 31 + slot
			var angle := TAU * float(slot) / float(count) + (_hash01(seed, 1.3) - 0.5) * 0.12
			if _is_street_gap(angle):
				continue
			var radial_jitter := (_hash01(seed, 2.9) - 0.5) * 0.025
			var r := radius + radial_jitter
			var width := 0.048 + _hash01(seed, 4.1) * 0.028
			var depth := 0.046 + _hash01(seed, 5.7) * 0.030
			var height := 0.050 + _hash01(seed, 7.3) * 0.075
			var p := Vector3(cos(angle) * r, height * 0.5 + 0.012, sin(angle) * r)
			var building := _add_box(_body_root, p, Vector3(width, height, depth), wall_mat, "Building_%02d_%02d" % [ring_index, slot])
			building.rotation.y = -angle + PI * 0.5
			_building_nodes.append(building)
			var roof_height := 0.010
			var roof := _add_box(_body_root, p + Vector3(0, height * 0.5 + roof_height * 0.5, 0), Vector3(width * 1.04, roof_height, depth * 1.04), roof_mat, "Roof_%02d_%02d" % [ring_index, slot])
			roof.rotation.y = building.rotation.y


func _build_industrial_edge(palette: Dictionary) -> void:
	var wall_mat := _material(palette["accent"])
	var roof_mat := _material(palette["roof"])
	for industrial_index in range(4):
		var angle := PI * 0.25 + float(industrial_index) * PI * 0.5
		var radius := 0.405
		var p := Vector3(cos(angle) * radius, 0.042, sin(angle) * radius)
		var root := Node3D.new()
		root.name = "Industrial_%02d" % industrial_index
		root.position = p
		root.rotation.y = -angle + PI * 0.5
		_industrial_root.add_child(root)
		_add_box(root, Vector3.ZERO, Vector3(0.095, 0.075, 0.060), wall_mat, "Warehouse")
		_add_box(root, Vector3(0, 0.043, 0), Vector3(0.101, 0.012, 0.066), roof_mat, "Roof")
		if industrial_index % 2 == 0:
			var chimney_mesh := CylinderMesh.new()
			chimney_mesh.top_radius = 0.009
			chimney_mesh.bottom_radius = 0.012
			chimney_mesh.height = 0.11
			chimney_mesh.radial_segments = 7
			var chimney := MeshInstance3D.new()
			chimney.name = "Chimney"
			chimney.mesh = chimney_mesh
			chimney.position = Vector3(0.030, 0.078, 0.012)
			chimney.material_override = roof_mat
			root.add_child(chimney)
		_industrial_nodes.append(root)


func _build_label() -> void:
	_label = Label3D.new()
	_label.name = "CityLabel"
	_label.text = city_name_ar
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 28
	_label.pixel_size = 0.0018
	_label.outline_size = 4
	_label.modulate = Color(0.96, 0.91, 0.78, 1.0)
	_label.outline_modulate = Color(0.04, 0.04, 0.03, 0.95)
	_label.position = Vector3(0, 0.22, 0)
	_label.visible = false
	add_child(_label)


func _rebuild() -> void:
	for child in get_children():
		child.free()
	_building_nodes.clear()
	_industrial_nodes.clear()
	_street_nodes.clear()
	_ensure_roots()
	var palette := _palette()
	_build_base(palette)
	_build_radial_streets(palette)
	_build_residential_rings(palette)
	_build_industrial_edge(palette)
	_build_label()


func get_building_count() -> int:
	return _building_nodes.size()


func get_city_radius() -> float:
	return CITY_RADIUS


func get_core_clear_radius() -> float:
	return CORE_CLEAR_RADIUS


func get_street_count() -> int:
	return _street_nodes.size()


func get_industrial_count() -> int:
	return _industrial_nodes.size()


func set_label_visible(value: bool) -> void:
	if _label != null:
		_label.visible = value


func set_lod(level: int) -> void:
	lod_level = clampi(level, 0, 2)
	if _body_root != null:
		_body_root.visible = lod_level > 0
		_body_root.scale = Vector3.ONE * (0.86 if lod_level == 1 else 1.0)
	if _street_root != null:
		_street_root.visible = lod_level >= 2
	if _industrial_root != null:
		_industrial_root.visible = lod_level >= 2
