extends Node3D

const BATTLEFIELD_SIZE := 10000.0
const BATTLEFIELD_HALF := BATTLEFIELD_SIZE * 0.5
const TERRAIN_CHUNKS_PER_SIDE := 5
const TERRAIN_CHUNK_SIZE := BATTLEFIELD_SIZE / float(TERRAIN_CHUNKS_PER_SIDE)
const TERRAIN_GRID_RESOLUTION := 16
const TERRAIN_VISIBLE_CHUNK_RADIUS := 1
const BATTLE_GROUND_SHADER_PATH := "res://source/battle/shaders/BattleGround.gdshader"
const CAMERA_BACK_OFFSET_Z := 720.0
const ZOOM_NORMAL := 1100.0
const ZOOM_CLOSE := 550.0
const UNIT_SPEED := 150.0
const ATTACK_RANGE := 190.0
const ATTACK_DPS := 150.0
const ENEMY_HP := 600.0
const SELECT_RADIUS_PX := 58.0
const TAP_MAX_DRAG_PX := 18.0

@onready var camera: Camera3D = $Camera3D
@onready var unit_root: Node3D = $Units
@onready var enemy_root: Node3D = $Enemies
@onready var ground: MeshInstance3D = $Ground
@onready var title_label: Label = $HUD/TopBar/Row/Title
@onready var status_label: Label = $HUD/TopBar/Row/Status
@onready var zoom_button: Button = $HUD/TopBar/Row/ZoomButton

var _zoom_level := 1
var _units: Array = []
var _enemies: Array = []
var _selected: Array[int] = []
var _touches := {}
var _touch_drag := {}
var _mouse_down := false
var _mouse_drag := 0.0
var _terrain_chunks: Array[MeshInstance3D] = []
var _battle_ground_material: Material = null
var _rock_prop_material: StandardMaterial3D = null
var _scrub_prop_material: StandardMaterial3D = null
var _terrain_prop_count := 0


func _game_state_node() -> Node:
	return get_node_or_null("/root/GameState")


func _audio_focus_node() -> Node:
	return get_node_or_null("/root/AudioFocusManager")


func _ready() -> void:
	var game_state := _game_state_node()
	var active_battle: Dictionary = {}
	if game_state != null:
		active_battle = game_state.get("active_battle")
		if active_battle.is_empty():
			game_state.call(
				"begin_battle",
				str(game_state.get("selected_province_id")),
				str(game_state.get("selected_province_name"))
			)
			active_battle = game_state.get("active_battle")
	title_label.text = "DAM • %s" % str(active_battle.get("province_name", "BATTLE"))
	_setup_camera()
	_setup_ground()
	_spawn_friendly_units()
	_spawn_enemy_units()
	_bind_audio_controls()
	_update_zoom_ui()
	_update_status()


func _bind_audio_controls() -> void:
	for path in [
		"HUD/TopBar/Row/BackButton",
		"HUD/TopBar/Row/ZoomButton",
		"HUD/CommandBar/SelectAllButton",
		"HUD/CommandBar/StopButton",
	]:
		var control := get_node_or_null(path) as Control
		if control != null:
			var audio := _audio_focus_node()
			if audio != null:
				audio.call("bind_control", control, "ui")


func _focus_audio_at_screen(screen_position: Vector2) -> void:
	var friendly := _closest_friendly_on_screen(screen_position)
	if friendly >= 0:
		var audio := _audio_focus_node()
		if audio != null:
			audio.call("focus_object", "battle:friendly:%d" % friendly, "friendly_tank")
		return
	var enemy := _closest_enemy_on_screen(screen_position)
	if enemy >= 0:
		var audio := _audio_focus_node()
		if audio != null:
			audio.call("focus_object", "battle:enemy:%d" % enemy, "enemy_tank")
		return
	var audio := _audio_focus_node()
	if audio != null:
		audio.call("clear_focus")


func _setup_camera() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = ZOOM_NORMAL
	camera.position = Vector3(0.0, 850.0, 720.0)
	camera.look_at(Vector3.ZERO, Vector3.UP)


func terrain_valley_mask_at(x: float, z: float) -> float:
	var valley_center := sin(z * 0.00055) * 650.0 + cos(z * 0.00017) * 220.0
	var distance := absf(x - valley_center)
	return 1.0 - smoothstep(180.0, 700.0, distance)


func terrain_height_at(x: float, z: float) -> float:
	var broad := sin(x * 0.00105) * 42.0 + cos(z * 0.00120) * 34.0
	var diagonal := sin((x + z) * 0.00072 + 1.3) * 24.0
	var ridge := sin(x * 0.00195 - z * 0.00061) * 16.0
	var erosion := sin(x * 0.0051 + sin(z * 0.0017) * 2.1) * 6.0 + cos(z * 0.0047 - x * 0.0008) * 4.0
	var valley_depth := terrain_valley_mask_at(x, z) * 58.0
	return broad + diagonal + ridge + erosion - valley_depth


func _build_terrain_chunk_mesh(center_x: float, center_z: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cell := TERRAIN_CHUNK_SIZE / float(TERRAIN_GRID_RESOLUTION)
	var half := TERRAIN_CHUNK_SIZE * 0.5
	for row in range(TERRAIN_GRID_RESOLUTION):
		for column in range(TERRAIN_GRID_RESOLUTION):
			var x0 := -half + float(column) * cell
			var x1 := x0 + cell
			var z0 := -half + float(row) * cell
			var z1 := z0 + cell
			var p00 := Vector3(x0, terrain_height_at(center_x + x0, center_z + z0), z0)
			var p10 := Vector3(x1, terrain_height_at(center_x + x1, center_z + z0), z0)
			var p01 := Vector3(x0, terrain_height_at(center_x + x0, center_z + z1), z1)
			var p11 := Vector3(x1, terrain_height_at(center_x + x1, center_z + z1), z1)
			var u0 := float(column) / float(TERRAIN_GRID_RESOLUTION)
			var u1 := float(column + 1) / float(TERRAIN_GRID_RESOLUTION)
			var v0 := float(row) / float(TERRAIN_GRID_RESOLUTION)
			var v1 := float(row + 1) / float(TERRAIN_GRID_RESOLUTION)
			st.set_uv(Vector2(u0, v0)); st.add_vertex(p00)
			st.set_uv(Vector2(u0, v1)); st.add_vertex(p01)
			st.set_uv(Vector2(u1, v0)); st.add_vertex(p10)
			st.set_uv(Vector2(u1, v0)); st.add_vertex(p10)
			st.set_uv(Vector2(u0, v1)); st.add_vertex(p01)
			st.set_uv(Vector2(u1, v1)); st.add_vertex(p11)
	st.generate_normals()
	return st.commit()


func _terrain_hash(index: int, salt: float) -> float:
	var value := sin(float(index) * 12.9898 + salt * 78.233) * 43758.5453
	return value - floor(value)


func _ensure_terrain_prop_materials() -> void:
	if _rock_prop_material == null:
		_rock_prop_material = StandardMaterial3D.new()
		_rock_prop_material.albedo_color = Color(0.31, 0.30, 0.27, 1.0)
		_rock_prop_material.roughness = 1.0
	if _scrub_prop_material == null:
		_scrub_prop_material = StandardMaterial3D.new()
		_scrub_prop_material.albedo_color = Color(0.24, 0.31, 0.14, 1.0)
		_scrub_prop_material.roughness = 1.0


func _populate_terrain_chunk(chunk: MeshInstance3D, column: int, row: int, center_x: float, center_z: float) -> void:
	_ensure_terrain_prop_materials()
	var chunk_index := row * TERRAIN_CHUNKS_PER_SIDE + column
	for prop_index in range(2):
		var seed := chunk_index * 7 + prop_index * 13
		var world_x := center_x + (_terrain_hash(seed, 1.7) - 0.5) * TERRAIN_CHUNK_SIZE * 0.72
		var world_z := center_z + (_terrain_hash(seed, 5.3) - 0.5) * TERRAIN_CHUNK_SIZE * 0.72
		var node := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		if (chunk_index + prop_index) % 2 == 0:
			var radius := 24.0 + _terrain_hash(seed, 9.1) * 22.0
			mesh.radius = radius
			mesh.height = radius * 1.15
			mesh.radial_segments = 6
			mesh.rings = 4
			node.material_override = _rock_prop_material
			node.name = "Rock_%02d_%02d" % [chunk_index, prop_index]
		else:
			var radius := 19.0 + _terrain_hash(seed, 3.9) * 15.0
			mesh.radius = radius
			mesh.height = radius * 1.35
			mesh.radial_segments = 7
			mesh.rings = 4
			node.material_override = _scrub_prop_material
			node.name = "Scrub_%02d_%02d" % [chunk_index, prop_index]
		node.mesh = mesh
		node.position = Vector3(
			world_x - center_x,
			terrain_height_at(world_x, world_z) + float(mesh.height) * 0.28,
			world_z - center_z
		)
		chunk.add_child(node)
		_terrain_prop_count += 1


func _create_battle_ground_material() -> Material:
	var shader := load(BATTLE_GROUND_SHADER_PATH) as Shader
	if shader == null:
		var fallback := StandardMaterial3D.new()
		fallback.albedo_color = Color(0.34, 0.34, 0.20, 1.0)
		fallback.roughness = 1.0
		return fallback
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _setup_ground() -> void:
	ground.mesh = null
	ground.material_override = null
	for child in ground.get_children():
		child.free()
	_terrain_chunks.clear()
	_terrain_prop_count = 0

	_battle_ground_material = _create_battle_ground_material()
	var material := _battle_ground_material

	for row in range(TERRAIN_CHUNKS_PER_SIDE):
		for column in range(TERRAIN_CHUNKS_PER_SIDE):
			var chunk := MeshInstance3D.new()
			chunk.name = "TerrainChunk_%02d_%02d" % [column, row]
			var center_x := -BATTLEFIELD_HALF + TERRAIN_CHUNK_SIZE * (float(column) + 0.5)
			var center_z := -BATTLEFIELD_HALF + TERRAIN_CHUNK_SIZE * (float(row) + 0.5)
			chunk.mesh = _build_terrain_chunk_mesh(center_x, center_z)
			chunk.material_override = material
			chunk.position = Vector3(center_x, 0.0, center_z)
			ground.add_child(chunk)
			_terrain_chunks.append(chunk)
			_populate_terrain_chunk(chunk, column, row, center_x, center_z)
	_sync_terrain_chunk_visibility()


func _sync_terrain_chunk_visibility() -> void:
	var target := Vector2(camera.position.x, camera.position.z - CAMERA_BACK_OFFSET_Z)
	var half_view := _camera_target_half_extents()
	var margin := TERRAIN_CHUNK_SIZE * 0.75
	var chunk_half := TERRAIN_CHUNK_SIZE * 0.5
	for chunk in _terrain_chunks:
		if not is_instance_valid(chunk):
			continue
		var delta := Vector2(chunk.position.x, chunk.position.z) - target
		chunk.visible = (
			absf(delta.x) <= half_view.x + chunk_half + margin
			and absf(delta.y) <= half_view.y + chunk_half + margin
		)


func terrain_coverage_ok_for_camera_size(test_size: float) -> bool:
	var previous_size := camera.size
	set_camera_size_safely(test_size)
	var covered := is_camera_ground_covered()
	set_camera_size_safely(previous_size)
	return covered


func is_camera_ground_covered() -> bool:
	var target := Vector2(camera.position.x, camera.position.z - CAMERA_BACK_OFFSET_Z)
	var half_view := _camera_target_half_extents() * 0.92
	var samples := [
		target,
		target + Vector2(-half_view.x, -half_view.y),
		target + Vector2(half_view.x, -half_view.y),
		target + Vector2(-half_view.x, half_view.y),
		target + Vector2(half_view.x, half_view.y),
		target + Vector2(-half_view.x, 0.0),
		target + Vector2(half_view.x, 0.0),
		target + Vector2(0.0, -half_view.y),
		target + Vector2(0.0, half_view.y),
	]
	for point in samples:
		if absf(point.x) > BATTLEFIELD_HALF or absf(point.y) > BATTLEFIELD_HALF:
			continue
		var column := clampi(int(floor((point.x + BATTLEFIELD_HALF) / TERRAIN_CHUNK_SIZE)), 0, TERRAIN_CHUNKS_PER_SIDE - 1)
		var row := clampi(int(floor((point.y + BATTLEFIELD_HALF) / TERRAIN_CHUNK_SIZE)), 0, TERRAIN_CHUNKS_PER_SIDE - 1)
		var index := row * TERRAIN_CHUNKS_PER_SIDE + column
		if index < 0 or index >= _terrain_chunks.size() or not _terrain_chunks[index].visible:
			return false
	return true


func get_terrain_integrity_signature() -> Dictionary:
	return {
		"battlefield_size": BATTLEFIELD_SIZE,
		"chunk_count": _terrain_chunks.size(),
		"prop_count": _terrain_prop_count,
		"height_a": terrain_height_at(-1400.0, -900.0),
		"height_b": terrain_height_at(1700.0, 1300.0),
		"height_c": terrain_height_at(220.0, 0.0),
	}


func get_visible_ground_chunk_count() -> int:
	var count := 0
	for chunk in _terrain_chunks:
		if is_instance_valid(chunk) and chunk.visible:
			count += 1
	return count


func get_ground_chunk_count() -> int:
	return _terrain_chunks.size()


func get_battle_ground_material() -> Material:
	return _battle_ground_material


func get_terrain_prop_count() -> int:
	return _terrain_prop_count


func _tank_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material


func _create_tank(name_text: String, position: Vector3, body_color: Color, turret_color: Color, selectable: bool) -> Node3D:
	var root := Node3D.new()
	root.name = name_text
	root.position = position

	var hull_mesh := BoxMesh.new()
	hull_mesh.size = Vector3(70, 28, 110)
	var hull := MeshInstance3D.new()
	hull.mesh = hull_mesh
	hull.position.y = 18
	hull.material_override = _tank_material(body_color)
	root.add_child(hull)

	var turret_mesh := CylinderMesh.new()
	turret_mesh.top_radius = 24
	turret_mesh.bottom_radius = 28
	turret_mesh.height = 20
	var turret := MeshInstance3D.new()
	turret.mesh = turret_mesh
	turret.position.y = 42
	turret.material_override = _tank_material(turret_color)
	root.add_child(turret)

	var barrel_mesh := BoxMesh.new()
	barrel_mesh.size = Vector3(8, 8, 70)
	var barrel := MeshInstance3D.new()
	barrel.mesh = barrel_mesh
	barrel.position = Vector3(0, 44, -55)
	barrel.material_override = _tank_material(turret_color.lightened(0.08))
	root.add_child(barrel)

	if selectable:
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

	return root


func _unit_ground_y(x: float, z: float) -> float:
	return terrain_height_at(x, z) + 10.0


func _snap_position_to_ground(position: Vector3) -> Vector3:
	position.y = _unit_ground_y(position.x, position.z)
	return position


func _spawn_friendly_units() -> void:
	var positions := [
		Vector3(-260, 10, 260), Vector3(-100, 10, 260), Vector3(60, 10, 260),
		Vector3(-260, 10, 410), Vector3(-100, 10, 410), Vector3(60, 10, 410),
	]
	for i in range(positions.size()):
		positions[i] = _snap_position_to_ground(positions[i])
		var root := _create_tank(
			"Friendly_%02d" % (i + 1),
			positions[i],
			Color(0.20, 0.48, 0.23, 1.0),
			Color(0.27, 0.58, 0.30, 1.0),
			true
		)
		unit_root.add_child(root)
		_units.append({
			"node": root,
			"target": positions[i],
			"moving": false,
			"attack_target": -1,
			"alive": true,
		})


func _spawn_enemy_units() -> void:
	var positions := [
		Vector3(-250, 10, -280), Vector3(-90, 10, -280), Vector3(70, 10, -280),
		Vector3(-250, 10, -430), Vector3(-90, 10, -430), Vector3(70, 10, -430),
	]
	for i in range(positions.size()):
		positions[i] = _snap_position_to_ground(positions[i])
		var root := _create_tank(
			"Enemy_%02d" % (i + 1),
			positions[i],
			Color(0.52, 0.16, 0.12, 1.0),
			Color(0.68, 0.20, 0.14, 1.0),
			false
		)
		enemy_root.add_child(root)
		_enemies.append({
			"node": root,
			"hp": ENEMY_HP,
			"alive": true,
		})


func _update_zoom_ui() -> void:
	zoom_button.text = "ZOOM %dX" % _zoom_level


func _update_status() -> void:
	var friendly_alive := 0
	for unit in _units:
		if bool(unit.get("alive", true)):
			friendly_alive += 1
	var enemy_alive := get_alive_enemy_count()
	if enemy_alive == 0:
		status_label.text = "VICTORY • %d FRIENDLY" % friendly_alive
	else:
		status_label.text = "FRIENDLY %d • ENEMY %d" % [friendly_alive, enemy_alive]


func toggle_zoom() -> void:
	_zoom_level = 2 if _zoom_level == 1 else 1
	var target := ZOOM_CLOSE if _zoom_level == 2 else ZOOM_NORMAL
	var tween := create_tween()
	tween.tween_property(camera, "size", target, 0.20).set_trans(Tween.TRANS_SINE)
	_update_zoom_ui()


func get_zoom_level() -> int:
	return _zoom_level


func get_zoom_target_size() -> float:
	return ZOOM_CLOSE if _zoom_level == 2 else ZOOM_NORMAL


func get_unit_count() -> int:
	return _units.size()


func get_enemy_count() -> int:
	return _enemies.size()


func get_friendly_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for unit in _units:
		positions.append((unit["node"] as Node3D).position)
	return positions


func get_enemy_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for enemy in _enemies:
		positions.append((enemy["node"] as Node3D).position)
	return positions


func get_enemy_health(index: int) -> float:
	if index < 0 or index >= _enemies.size():
		return -1.0
	return float(_enemies[index].get("hp", 0.0))


func get_alive_enemy_count() -> int:
	var count := 0
	for enemy in _enemies:
		if bool(enemy.get("alive", false)):
			count += 1
	return count


func get_alive_friendly_count() -> int:
	var count := 0
	for unit in _units:
		if bool(unit.get("alive", true)):
			count += 1
	return count


func get_selected_count() -> int:
	return _selected.size()


func get_battle_context() -> Dictionary:
	var game_state := _game_state_node()
	if game_state == null:
		return {}
	var active_battle: Dictionary = game_state.get("active_battle")
	return active_battle.duplicate(true)


func get_radar_blips() -> Array:
	var result: Array = []
	for i in range(_units.size()):
		var unit: Dictionary = _units[i]
		if not bool(unit.get("alive", true)):
			continue
		var node: Node3D = unit["node"]
		result.append({
			"uv": _world_to_uv(node.position),
			"friendly": true,
			"selected": i in _selected,
		})
	for enemy in _enemies:
		if not bool(enemy.get("alive", false)):
			continue
		var node: Node3D = enemy["node"]
		result.append({
			"uv": _world_to_uv(node.position),
			"friendly": false,
			"selected": false,
		})
	return result


func _world_to_uv(position: Vector3) -> Vector2:
	return Vector2(
		clampf(position.x / BATTLEFIELD_SIZE + 0.5, 0.0, 1.0),
		clampf(position.z / BATTLEFIELD_SIZE + 0.5, 0.0, 1.0)
	)


func get_radar_camera_uv() -> Vector2:
	return _world_to_uv(Vector3(camera.position.x, 0.0, camera.position.z - CAMERA_BACK_OFFSET_Z))


func get_radar_camera_rect_uv() -> Rect2:
	var center := get_radar_camera_uv()
	var half_view := _camera_target_half_extents()
	var half_uv := Vector2(
		clampf(half_view.x / BATTLEFIELD_SIZE, 0.0, 0.5),
		clampf(half_view.y / BATTLEFIELD_SIZE, 0.0, 0.5)
	)
	var minimum := Vector2(
		clampf(center.x - half_uv.x, 0.0, 1.0),
		clampf(center.y - half_uv.y, 0.0, 1.0)
	)
	var maximum := Vector2(
		clampf(center.x + half_uv.x, 0.0, 1.0),
		clampf(center.y + half_uv.y, 0.0, 1.0)
	)
	return Rect2(minimum, maximum - minimum)


func radar_center_on_uv(uv: Vector2) -> void:
	uv.x = clampf(uv.x, 0.0, 1.0)
	uv.y = clampf(uv.y, 0.0, 1.0)
	camera.position.x = (uv.x - 0.5) * BATTLEFIELD_SIZE
	camera.position.z = (uv.y - 0.5) * BATTLEFIELD_SIZE + CAMERA_BACK_OFFSET_Z
	_clamp_camera_to_battlefield()
	_sync_terrain_chunk_visibility()


func get_battlefield_size() -> float:
	return BATTLEFIELD_SIZE


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


func select_units(indices: Array[int]) -> void:
	_selected.clear()
	for index in indices:
		if index < 0 or index >= _units.size():
			continue
		if not bool(_units[index].get("alive", true)):
			continue
		if index not in _selected:
			_selected.append(index)
	_refresh_selection_visuals()


func clear_selection() -> void:
	_selected.clear()
	_refresh_selection_visuals()


func select_all_units() -> void:
	var indices: Array[int] = []
	for i in range(_units.size()):
		if bool(_units[i].get("alive", true)):
			indices.append(i)
	select_units(indices)


func _refresh_selection_visuals() -> void:
	for i in range(_units.size()):
		var ring := (_units[i]["node"] as Node3D).get_node_or_null("Selection")
		if ring != null:
			ring.visible = i in _selected


func _closest_friendly_on_screen(screen_position: Vector2) -> int:
	var closest := -1
	var closest_distance := SELECT_RADIUS_PX
	for i in range(_units.size()):
		var unit: Dictionary = _units[i]
		if not bool(unit.get("alive", true)):
			continue
		var node: Node3D = unit["node"]
		if camera.is_position_behind(node.global_position):
			continue
		var d := camera.unproject_position(node.global_position).distance_to(screen_position)
		if d < closest_distance:
			closest_distance = d
			closest = i
	return closest


func _closest_enemy_on_screen(screen_position: Vector2) -> int:
	var closest := -1
	var closest_distance := SELECT_RADIUS_PX
	for i in range(_enemies.size()):
		var enemy: Dictionary = _enemies[i]
		if not bool(enemy.get("alive", false)):
			continue
		var node: Node3D = enemy["node"]
		if camera.is_position_behind(node.global_position):
			continue
		var d := camera.unproject_position(node.global_position).distance_to(screen_position)
		if d < closest_distance:
			closest_distance = d
			closest = i
	return closest


func _handle_tap(screen_position: Vector2) -> void:
	var friendly := _closest_friendly_on_screen(screen_position)
	if friendly >= 0:
		_toggle_selection(friendly)
		return

	var enemy := _closest_enemy_on_screen(screen_position)
	if enemy >= 0 and not _selected.is_empty():
		issue_attack_order(enemy)
		return

	if _selected.is_empty():
		return
	var hit = _screen_to_ground(screen_position)
	if hit == null:
		return
	_issue_group_move(hit)


func issue_attack_order(enemy_index: int) -> void:
	if enemy_index < 0 or enemy_index >= _enemies.size():
		return
	if not bool(_enemies[enemy_index].get("alive", false)):
		return
	for index in _selected:
		if index < 0 or index >= _units.size():
			continue
		var unit: Dictionary = _units[index]
		if not bool(unit.get("alive", true)):
			continue
		unit["attack_target"] = enemy_index
		unit["moving"] = false
		_units[index] = unit


func issue_group_move(center: Vector3) -> void:
	_issue_group_move(center)


func _issue_group_move(center: Vector3) -> void:
	var movable: Array[int] = []
	for index in _selected:
		if index >= 0 and index < _units.size() and bool(_units[index].get("alive", true)):
			movable.append(index)
	if movable.is_empty():
		return
	var spacing := 95.0
	var columns := maxi(1, int(ceil(sqrt(float(movable.size())))))
	for order_index in range(movable.size()):
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
		target = _snap_position_to_ground(target)
		var index := movable[order_index]
		var unit: Dictionary = _units[index]
		unit["target"] = target
		unit["moving"] = true
		unit["attack_target"] = -1
		_units[index] = unit


func set_camera_size_safely(new_size: float) -> void:
	camera.size = clampf(new_size, 420.0, BATTLEFIELD_SIZE * 0.72)
	_clamp_camera_to_battlefield()
	_sync_terrain_chunk_visibility()


func _camera_target_half_extents() -> Vector2:
	var viewport := get_viewport().get_visible_rect().size
	var aspect := maxf(0.25, viewport.x / maxf(1.0, viewport.y))
	return Vector2(camera.size * aspect * 0.5, camera.size * 0.5)


func _clamp_camera_to_battlefield() -> void:
	var half_view := _camera_target_half_extents()
	var max_x := maxf(0.0, BATTLEFIELD_HALF - half_view.x)
	var max_z := maxf(0.0, BATTLEFIELD_HALF - half_view.y)
	camera.position.x = clampf(camera.position.x, -max_x, max_x)
	var target_z := camera.position.z - CAMERA_BACK_OFFSET_Z
	target_z = clampf(target_z, -max_z, max_z)
	camera.position.z = target_z + CAMERA_BACK_OFFSET_Z


func _pan_camera(relative: Vector2) -> void:
	var scale_factor := camera.size / maxf(1.0, float(get_viewport().get_visible_rect().size.y))
	camera.position += Vector3(-relative.x * scale_factor, 0.0, -relative.y * scale_factor)
	_clamp_camera_to_battlefield()
	_sync_terrain_chunk_visibility()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_focus_audio_at_screen(event.position)
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
		else:
			if _mouse_down and _mouse_drag <= TAP_MAX_DRAG_PX:
				_handle_tap(event.position)
			_mouse_down = false
	elif event is InputEventMouseMotion and _mouse_down:
		_mouse_drag += event.relative.length()
		_pan_camera(event.relative)
	elif event is InputEventMouseMotion:
		_focus_audio_at_screen(event.position)


func _process(delta: float) -> void:
	for i in range(_units.size()):
		var unit: Dictionary = _units[i]
		if not bool(unit.get("alive", true)):
			continue

		var attack_target := int(unit.get("attack_target", -1))
		if attack_target >= 0 and attack_target < _enemies.size():
			var enemy: Dictionary = _enemies[attack_target]
			if not bool(enemy.get("alive", false)):
				unit["attack_target"] = -1
				_units[i] = unit
				continue
			var node: Node3D = unit["node"]
			var enemy_node: Node3D = enemy["node"]
			var delta_vec := enemy_node.position - node.position
			delta_vec.y = 0.0
			var distance := delta_vec.length()
			if distance > ATTACK_RANGE:
				node.position += delta_vec.normalized() * minf(UNIT_SPEED * delta, distance - ATTACK_RANGE)
				node.position = _snap_position_to_ground(node.position)
			else:
				enemy["hp"] = float(enemy.get("hp", ENEMY_HP)) - ATTACK_DPS * delta
				if float(enemy["hp"]) <= 0.0:
					enemy["alive"] = false
					enemy_node.visible = false
					unit["attack_target"] = -1
				_enemies[attack_target] = enemy
				_units[i] = unit
				_update_status()
			continue

		if not bool(unit.get("moving", false)):
			continue
		var node: Node3D = unit["node"]
		var target: Vector3 = unit["target"]
		var delta_vec := target - node.position
		delta_vec.y = 0.0
		var distance := delta_vec.length()
		var step := UNIT_SPEED * delta
		if distance <= step:
			node.position = _snap_position_to_ground(target)
			unit["moving"] = false
		else:
			node.position += delta_vec.normalized() * step
			node.position = _snap_position_to_ground(node.position)
		_units[i] = unit


func _on_zoom_pressed() -> void:
	toggle_zoom()


func _on_select_all_pressed() -> void:
	select_all_units()


func are_selected_units_stopped() -> bool:
	for index in _selected:
		if index < 0 or index >= _units.size():
			continue
		var unit: Dictionary = _units[index]
		if bool(unit.get("moving", false)) or int(unit.get("attack_target", -1)) >= 0:
			return false
	return true


func stop_selected_units() -> void:
	for index in _selected:
		if index < 0 or index >= _units.size():
			continue
		var unit: Dictionary = _units[index]
		unit["moving"] = false
		unit["attack_target"] = -1
		unit["target"] = (_units[index]["node"] as Node3D).position
		_units[index] = unit


func _on_stop_pressed() -> void:
	stop_selected_units()


func _on_back_pressed() -> void:
	var game_state := _game_state_node()
	if game_state != null:
		game_state.call("finish_battle", {
			"result": "retreat" if get_alive_enemy_count() > 0 else "victory",
			"friendly_survivors": get_alive_friendly_count(),
			"enemy_survivors": get_alive_enemy_count(),
		})
	get_tree().change_scene_to_file("res://source/world/MiddleEastTerrain.tscn")
