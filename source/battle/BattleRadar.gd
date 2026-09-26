extends Control

const MARGIN := 8.0
var _battle: Node = null
var _dragging := false


func _ready() -> void:
	_battle = get_parent().get_parent()
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


func _inner_rect() -> Rect2:
	return Rect2(
		Vector2(MARGIN, MARGIN),
		Vector2(maxf(1.0, size.x - MARGIN * 2.0), maxf(1.0, size.y - MARGIN * 2.0))
	)


func _uv_to_point(uv: Vector2) -> Vector2:
	var rect := _inner_rect()
	return rect.position + Vector2(uv.x * rect.size.x, uv.y * rect.size.y)


func _point_to_uv(point: Vector2) -> Vector2:
	var rect := _inner_rect()
	return Vector2(
		clampf((point.x - rect.position.x) / rect.size.x, 0.0, 1.0),
		clampf((point.y - rect.position.y) / rect.size.y, 0.0, 1.0)
	)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.04, 0.03, 0.94), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.74, 0.74, 0.50, 0.95), false, 2.0)
	var inner := _inner_rect()
	draw_rect(inner, Color(0.11, 0.15, 0.08, 0.98), true)

	if _battle == null or not is_instance_valid(_battle):
		return
	if not _battle.has_method("get_radar_blips"):
		return

	for raw in _battle.get_radar_blips():
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = raw
		var point := _uv_to_point(item.get("uv", Vector2.ZERO))
		var friendly := bool(item.get("friendly", false))
		var selected := bool(item.get("selected", false))
		var color := Color(0.18, 0.92, 0.25, 1.0) if friendly else Color(0.95, 0.18, 0.12, 1.0)
		draw_circle(point, 5.0 if selected else 3.5, color)
		if selected:
			draw_arc(point, 7.5, 0.0, TAU, 16, Color(1.0, 0.90, 0.20, 1.0), 1.5)

	if _battle.has_method("get_radar_camera_rect_uv"):
		var camera_rect: Rect2 = _battle.get_radar_camera_rect_uv()
		var top_left := _uv_to_point(camera_rect.position)
		var bottom_right := _uv_to_point(camera_rect.position + camera_rect.size)
		draw_rect(Rect2(top_left, bottom_right - top_left), Color(1.0, 1.0, 0.82, 0.95), false, 2.0)
	elif _battle.has_method("get_radar_camera_uv"):
		var center := _uv_to_point(_battle.get_radar_camera_uv())
		draw_rect(Rect2(center - Vector2(22, 16), Vector2(44, 32)), Color(1.0, 1.0, 0.82, 0.95), false, 2.0)


func _move_camera(local_position: Vector2) -> void:
	if _battle != null and is_instance_valid(_battle) and _battle.has_method("radar_center_on_uv"):
		_battle.radar_center_on_uv(_point_to_uv(local_position))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_dragging = event.pressed
		if event.pressed:
			_move_camera(event.position)
		accept_event()
	elif event is InputEventScreenDrag and _dragging:
		_move_camera(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_move_camera(event.position)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_move_camera(event.position)
		accept_event()
