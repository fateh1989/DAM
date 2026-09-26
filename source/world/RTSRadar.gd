extends Control

var _world: Node = null
var _dragging := false

const INNER_MARGIN := 8.0


func _ready() -> void:
	_world = get_parent().get_parent()
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


func _inner_rect() -> Rect2:
	return Rect2(
		Vector2(INNER_MARGIN, INNER_MARGIN),
		Vector2(maxf(1.0, size.x - INNER_MARGIN * 2.0), maxf(1.0, size.y - INNER_MARGIN * 2.0))
	)


func _uv_to_point(uv: Vector2) -> Vector2:
	var inner := _inner_rect()
	return inner.position + Vector2(
		clampf(uv.x, 0.0, 1.0) * inner.size.x,
		clampf(uv.y, 0.0, 1.0) * inner.size.y
	)


func _point_to_uv(point: Vector2) -> Vector2:
	var inner := _inner_rect()
	return Vector2(
		clampf((point.x - inner.position.x) / inner.size.x, 0.0, 1.0),
		clampf((point.y - inner.position.y) / inner.size.y, 0.0, 1.0)
	)


func _uv_rect_to_rect(uv_rect: Rect2) -> Rect2:
	var inner := _inner_rect()
	return Rect2(
		inner.position + Vector2(uv_rect.position.x * inner.size.x, uv_rect.position.y * inner.size.y),
		Vector2(uv_rect.size.x * inner.size.x, uv_rect.size.y * inner.size.y)
	)


func get_camera_indicator_rect() -> Rect2:
	if _world == null or not is_instance_valid(_world):
		return Rect2()
	if _world.has_method("get_radar_camera_rect_uv"):
		var uv_rect: Rect2 = _world.call("get_radar_camera_rect_uv")
		return _uv_rect_to_rect(uv_rect)
	if _world.has_method("get_radar_camera_uv"):
		var center := _uv_to_point(_world.call("get_radar_camera_uv"))
		return Rect2(center - Vector2(21.0, 15.0), Vector2(42.0, 30.0))
	return Rect2()


func get_blip_style(item: Dictionary) -> Dictionary:
	var selected := bool(item.get("selected", false))
	var primary := bool(item.get("primary", false))
	var unit_type := str(item.get("unit_type", "tank"))
	var base_radius := 3.5
	if unit_type == "artillery":
		base_radius = 4.0
	elif unit_type == "rocket_launcher":
		base_radius = 4.4
	return {
		"radius": 6.5 if primary else (5.2 if selected else base_radius),
		"ring_radius": 9.0 if primary else 7.5,
		"ring_width": 2.2 if primary else 1.5,
	}


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.018, 0.030, 0.025, 0.96), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.40, 0.82, 0.42, 0.96), false, 2.0)
	var inner := _inner_rect()
	draw_rect(inner, Color(0.045, 0.075, 0.055, 0.97), true)
	draw_rect(inner, Color(0.20, 0.48, 0.22, 0.92), false, 1.0)

	if _world == null or not is_instance_valid(_world):
		return
	if not _world.has_method("get_radar_units"):
		return

	var units: Array = _world.get_radar_units()
	for raw_item in units:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = raw_item
		var point := _uv_to_point(item.get("uv", Vector2.ZERO))
		var color: Color = item.get("color", Color.WHITE)
		var selected := bool(item.get("selected", false))
		var style := get_blip_style(item)
		draw_circle(point, float(style.get("radius", 3.5)), color)
		if selected:
			draw_arc(
				point,
				float(style.get("ring_radius", 7.5)),
				0.0,
				TAU,
				18,
				Color(0.25, 1.0, 0.34, 1.0),
				float(style.get("ring_width", 1.5))
			)

	var indicator := get_camera_indicator_rect()
	if indicator.size.x > 0.0 and indicator.size.y > 0.0:
		draw_rect(indicator, Color(0.92, 0.98, 0.90, 0.98), false, 2.0)


func apply_action_uv(uv: Vector2) -> void:
	if _world == null or not is_instance_valid(_world):
		return
	var mode := "camera"
	if _world.has_method("get_radar_action_mode"):
		mode = str(_world.call("get_radar_action_mode"))
	if mode == "select" and _world.has_method("select_nearest_unit_uv"):
		_world.call("select_nearest_unit_uv", uv)
		return
	if mode == "move" and _world.has_method("issue_selected_group_move_uv"):
		var selected_count := 0
		if _world.has_method("get_selected_unit_count"):
			selected_count = int(_world.call("get_selected_unit_count"))
		if selected_count > 0:
			_world.call("issue_selected_group_move_uv", uv)
			return
	if _world.has_method("radar_center_on_uv"):
		_world.call("radar_center_on_uv", uv)


func _move_camera_from_pointer(local_position: Vector2) -> void:
	apply_action_uv(_point_to_uv(local_position))


func is_continuous_pointer_mode(mode: String) -> bool:
	return mode == "camera"


func _current_pointer_mode() -> String:
	if _world != null and is_instance_valid(_world) and _world.has_method("get_radar_action_mode"):
		return str(_world.call("get_radar_action_mode"))
	return "camera"


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			var mode := _current_pointer_mode()
			_dragging = is_continuous_pointer_mode(mode)
			_move_camera_from_pointer(event.position)
		else:
			_dragging = false
		accept_event()
	elif event is InputEventScreenDrag and _dragging:
		_move_camera_from_pointer(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var mode := _current_pointer_mode()
			_dragging = is_continuous_pointer_mode(mode)
			_move_camera_from_pointer(event.position)
		else:
			_dragging = false
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_move_camera_from_pointer(event.position)
		accept_event()
