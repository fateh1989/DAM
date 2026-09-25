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


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.045, 0.045, 0.92), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.58, 0.72, 0.57, 0.95), false, 2.0)
	var inner := _inner_rect()
	draw_rect(inner, Color(0.08, 0.12, 0.10, 0.95), true)
	draw_rect(inner, Color(0.28, 0.42, 0.28, 0.9), false, 1.0)

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
		draw_circle(point, 5.0 if selected else 3.5, color)
		if selected:
			draw_arc(point, 7.5, 0.0, TAU, 18, Color(1.0, 0.92, 0.20, 1.0), 1.5)

	if _world.has_method("get_radar_camera_uv"):
		var center := _uv_to_point(_world.get_radar_camera_uv())
		var zoom_level := 1
		if _world.has_method("get_rts_zoom_level"):
			zoom_level = int(_world.get_rts_zoom_level())
		var indicator_size := Vector2(42.0, 30.0) if zoom_level <= 1 else Vector2(22.0, 16.0)
		draw_rect(Rect2(center - indicator_size * 0.5, indicator_size), Color(0.95, 0.95, 0.80, 0.95), false, 2.0)


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


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_dragging = true
			_move_camera_from_pointer(event.position)
		else:
			_dragging = false
		accept_event()
	elif event is InputEventScreenDrag and _dragging:
		_move_camera_from_pointer(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_move_camera_from_pointer(event.position)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_move_camera_from_pointer(event.position)
		accept_event()
