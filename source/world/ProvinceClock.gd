extends Button

signal province_requested(index: int)

const CLOCK_SIZE := Vector2(72.0, 76.0)
const CLOCK_RADIUS := 29.0

var province_index := -1
var display_name := ""
var strength := 0.5
var readiness := 0.5
var attacking := false
var selected_province := false
var _steam_phase := 0.0
var _name_label: Label = null


func _ready() -> void:
	custom_minimum_size = CLOCK_SIZE
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	_ensure_name_label()
	pressed.connect(_on_pressed)
	queue_redraw()


func setup(index: int, province_name: String) -> void:
	province_index = index
	display_name = province_name
	custom_minimum_size = CLOCK_SIZE
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	_ensure_name_label()
	_name_label.text = display_name
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	queue_redraw()


func _ensure_name_label() -> void:
	if _name_label != null and is_instance_valid(_name_label):
		return
	_name_label = Label.new()
	_name_label.name = "ProvinceName"
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_name_label.offset_left = 7.0
	_name_label.offset_top = 17.0
	_name_label.offset_right = -7.0
	_name_label.offset_bottom = -13.0
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.add_theme_color_override("font_color", Color(0.12, 0.10, 0.07, 1.0))
	_name_label.add_theme_color_override("font_outline_color", Color(0.94, 0.90, 0.78, 0.92))
	_name_label.add_theme_constant_override("outline_size", 2)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_name_label)


func set_military_status(new_strength: float, new_readiness: float) -> void:
	strength = clampf(new_strength, 0.0, 1.0)
	readiness = clampf(new_readiness, 0.0, 1.0)
	queue_redraw()


func set_attacking_state(value: bool) -> void:
	attacking = value
	set_process(attacking)
	queue_redraw()


func _process(delta: float) -> void:
	if not attacking:
		return
	_steam_phase = fmod(_steam_phase + delta * 0.42, 1.0)
	queue_redraw()


func get_status_score() -> float:
	return clampf(strength * 0.55 + readiness * 0.45, 0.0, 1.0)


func get_status_color() -> Color:
	var score := get_status_score()
	if score >= 0.75:
		return Color(0.20, 0.66, 0.30, 1.0)
	if score >= 0.50:
		return Color(0.82, 0.68, 0.18, 1.0)
	if score >= 0.30:
		return Color(0.86, 0.42, 0.12, 1.0)
	return Color(0.72, 0.16, 0.13, 1.0)


func _on_pressed() -> void:
	province_requested.emit(province_index)


func _draw() -> void:
	var center := Vector2(size.x * 0.5, 37.0)
	draw_circle(center, CLOCK_RADIUS + 4.0, Color(0.25, 0.18, 0.08, 1.0))
	draw_circle(center, CLOCK_RADIUS + 1.5, Color(0.67, 0.50, 0.22, 1.0))
	draw_arc(center, CLOCK_RADIUS + 0.2, -PI * 0.75, -PI * 0.75 + PI * 1.5 * get_status_score(), 48, get_status_color(), 3.0)
	draw_circle(center, CLOCK_RADIUS - 2.0, Color(0.91, 0.87, 0.73, 1.0))
	_draw_station_ticks(center)
	_draw_status_hands(center)
	if attacking:
		_draw_attack_steam(center)


func _draw_station_ticks(center: Vector2) -> void:
	for tick in range(12):
		var angle := -PI * 0.5 + TAU * float(tick) / 12.0
		var outer := center + Vector2(cos(angle), sin(angle)) * (CLOCK_RADIUS - 4.0)
		var inner := center + Vector2(cos(angle), sin(angle)) * (CLOCK_RADIUS - (8.5 if tick % 3 == 0 else 6.5))
		draw_line(inner, outer, Color(0.16, 0.13, 0.08, 0.92), 1.6 if tick % 3 == 0 else 1.0)


func _draw_status_hands(center: Vector2) -> void:
	var strength_angle := -PI * 0.75 + clampf(strength, 0.0, 1.0) * PI * 1.5
	var readiness_angle := -PI * 0.75 + clampf(readiness, 0.0, 1.0) * PI * 1.5
	draw_line(center, center + Vector2(cos(strength_angle), sin(strength_angle)) * 20.0, Color(0.16, 0.12, 0.08, 1.0), 2.2)
	draw_line(center, center + Vector2(cos(readiness_angle), sin(readiness_angle)) * 16.0, Color(0.48, 0.10, 0.07, 1.0), 1.7)
	draw_circle(center, 2.5, Color(0.20, 0.15, 0.08, 1.0))


func _draw_attack_steam(center: Vector2) -> void:
	for puff_index in range(3):
		var phase := fmod(_steam_phase + float(puff_index) * 0.27, 1.0)
		var drift := sin((phase + float(puff_index)) * TAU) * 2.4
		var puff_center := center + Vector2(
			(float(puff_index) - 1.0) * 4.0 + drift,
			-CLOCK_RADIUS - 3.0 - phase * 13.0
		)
		var alpha := (1.0 - phase) * 0.52
		draw_circle(puff_center, 2.8 + phase * 3.2, Color(0.86, 0.84, 0.78, alpha))
