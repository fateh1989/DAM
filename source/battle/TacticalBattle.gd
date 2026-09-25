extends Node3D

const BATTLEFIELD_SIZE := 2000.0
const ZOOM_NORMAL := 1100.0
const ZOOM_CLOSE := 550.0
const UNIT_SPEED := 150.0
const SELECT_RADIUS_PX := 58.0
const TAP_MAX_DRAG_PX := 18.0

@onready var camera: Camera3D = $Camera3D
@onready var unit_root: Node3D = $Units
@onready var ground: MeshInstance3D = $Ground
@onready var title_label: Label = $HUD/TopBar/Row/Title
@onready var zoom_button: Button = $HUD/TopBar/Row/ZoomButton

var _zoom_level := 1
var _units: Array = []
var _selected: Array[int] = []
var _touches := {}
var _touch_drag := {}
var _mouse_down := false
var _mouse_drag := 0.0
var _mouse_start := Vector2.ZERO


func _ready() -> void:
	if GameState.active_battle.is_empty():
		GameState.begin_battle(GameState.selected_province_id, GameState.selected_province_name)
	title_label.text = "DAM • BATTLE • %s" % str(GameState.active_battle.get("province_name", ""))
	_setup_camera()
	_setup_ground()
	_spawn_units()
	_update_zoom_ui()


func _setup_camera() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = ZOOM_NORMAL
	camera.position = Vector3(0.0, 850.0, 720.0)
	camera.look_at(Vector3.ZERO, Vector3.UP)


func _setup_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(BATTLEFIELD_SIZE, BATTLEFIELD_SIZE)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.24, 0.29, 0.17, 1.0)
	material.roughness = 1.0
	ground.material_override = material


func _tank_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material


func _spawn_units() -> void:
	var positions := [
		Vector3(-260, 10, 120), Vector3(-100, 10, 120), Vector3(60, 10, 120),
		Vector3(-260, 10, 300), Vector3(-100, 10, 300), Vector3(60, 10, 300),
	]
	for i in range(positions.size()):
		var root := Node3D.new()
		root.name = "Tank_%02d" % (i + 1)
		root.position = positions[i]
		unit_root.add_child(root)

		var hull_mesh := BoxMesh.new()
		hull_mesh.size = Vector3(70, 28, 110)
		var hull := MeshInstance3D.new()
		hull.mesh = hull_mesh
		hull.position.y = 18
		hull.material_override = _tank_material(Color(0.20, 0.48, 0.23, 1.0))
		root.add_child(hull)

		var turret_mesh := CylinderMesh.new()
		turret_mesh.top_radius = 24
		turret_mesh.bottom_radius = 28
		turret_mesh.height = 20
		var turret := MeshInstance3D.new()
		turret.mesh = turret_mesh
		turret.position.y = 42
		turret.material_override = _tank_material(Color(0.27, 0.58, 0.30, 1.0))
		root.add_child(turret)

		var barrel_mesh := BoxMesh.new()
		barrel_mesh.size = Vector3(8, 8, 70)
		var barrel := MeshInstance3D.new()
		barrel.mesh = barrel_mesh
		barrel.position = Vector3(0, 44, -55)
		barrel.material_override = _tank_material(Color(0.30, 0.62, 0.32, 1.0))
		root.add_child(barrel)

		var ring_mesh := CylinderMesh.new()
		ring_mesh.top_radius = 48
		ring_mesh.bottom_radius = 48
		ring_mesh.height = 2
		var ring := MeshInstance3D.new()
		ring.name = "Selection"
		ring.mesh = ring_mesh
		ring.position.y = 2
		ring.material_override = _tank_material(Color(1.0, 0.86, 0.12, 0.82))
		ring.visible = false
		root.add_child(ring)

		_units.append({
			"node": root,
			"target": positions[i],
			"moving": false,
		})


func _update_zoom_ui() -> void:
	zoom_button.text = "ZOOM %dX" % _zoom_level


func toggle_zoom() -> void:
	_zoom_level = 2 if _zoom_level == 1 else 1
	var target := ZOOM_CLOSE if _zoom_level == 2 else ZOOM_NORMAL
	var tween := create_tween()
	tween.tween_property(camera, "size", target, 0.20).set_trans(Tween.TRANS_SINE)
	_update_zoom_ui()


func get_zoom_level() -> int:
	return _zoom_level


func get_unit_count() -> int:
	return _units.size()


func _screen_to_ground(screen_position: Vector2):
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	return Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)


func _toggle_selection(index: int) -> void:
	if index in _selected:
		_selected.erase(index)
	else:
		_selected.append(index)
	for i in range(_units.size()):
		var ring := (_units[i]["node"] as Node3D).get_node_or_null("Selection")
		if ring != null:
			ring.visible = i in _selected


func _handle_tap(screen_position: Vector2) -> void:
	var closest := -1
	var closest_distance := SELECT_RADIUS_PX
	for i in range(_units.size()):
		var node: Node3D = _units[i]["node"]
		if camera.is_position_behind(node.global_position):
			continue
		var d := camera.unproject_position(node.global_position).distance_to(screen_position)
		if d < closest_distance:
			closest_distance = d
			closest = i
	if closest >= 0:
		_toggle_selection(closest)
		return

	if _selected.is_empty():
		return
	var hit = _screen_to_ground(screen_position)
	if hit == null:
		return
	_issue_group_move(hit)


func _issue_group_move(center: Vector3) -> void:
	var spacing := 95.0
	var columns := maxi(1, int(ceil(sqrt(float(_selected.size())))))
	for order_index in range(_selected.size()):
		var row := int(order_index / columns)
		var column := order_index % columns
		var offset := Vector3(
			(float(column) - float(columns - 1) * 0.5) * spacing,
			0.0,
			(float(row) - float(columns - 1) * 0.5) * spacing
		)
		var target := center + offset
		target.x = clampf(target.x, -BATTLEFIELD_SIZE * 0.48, BATTLEFIELD_SIZE * 0.48)
		target.z = clampf(target.z, -BATTLEFIELD_SIZE * 0.48, BATTLEFIELD_SIZE * 0.48)
		var index := _selected[order_index]
		var unit: Dictionary = _units[index]
		unit["target"] = target
		unit["moving"] = true
		_units[index] = unit


func _pan_camera(relative: Vector2) -> void:
	var scale_factor := camera.size / maxf(1.0, float(get_viewport().get_visible_rect().size.y))
	camera.position += Vector3(-relative.x * scale_factor, 0.0, -relative.y * scale_factor)
	camera.position.x = clampf(camera.position.x, -700.0, 700.0)
	camera.position.z = clampf(camera.position.z, 150.0, 1450.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			_touch_drag[event.index] = 0.0
		else:
			var was_single := _touches.size() == 1
			var drag := float(_touch_drag.get(event.index, 9999.0))
			if was_single and drag <= TAP_MAX_DRAG_PX:
				_handle_tap(event.position)
			_touches.erase(event.index)
			_touch_drag.erase(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_touch_drag[event.index] = float(_touch_drag.get(event.index, 0.0)) + event.relative.length()
		if _touches.size() <= 1:
			_pan_camera(event.relative)
		_touches[event.index] = event.position
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_down = true
			_mouse_drag = 0.0
			_mouse_start = event.position
		else:
			if _mouse_down and _mouse_drag <= TAP_MAX_DRAG_PX:
				_handle_tap(event.position)
			_mouse_down = false
	elif event is InputEventMouseMotion and _mouse_down:
		_mouse_drag += event.relative.length()
		_pan_camera(event.relative)


func _process(delta: float) -> void:
	for i in range(_units.size()):
		var unit: Dictionary = _units[i]
		if not bool(unit.get("moving", false)):
			continue
		var node: Node3D = unit["node"]
		var target: Vector3 = unit["target"]
		var delta_vec := target - node.position
		delta_vec.y = 0.0
		var distance := delta_vec.length()
		var step := UNIT_SPEED * delta
		if distance <= step:
			node.position = target
			unit["moving"] = false
		else:
			node.position += delta_vec.normalized() * step
		_units[i] = unit


func _on_zoom_pressed() -> void:
	toggle_zoom()


func _on_back_pressed() -> void:
	GameState.finish_battle({"result": "retreat", "survivors": _units.size()})
	get_tree().change_scene_to_file("res://source/world/MiddleEastTerrain.tscn")
