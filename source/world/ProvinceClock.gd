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
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.add_theme_color_override("font_color", Color(0.12, 0.10, 0.07, 1.0))
	add_child(_name_label)


func _on_pressed() -> void:
	province_requested.emit(province_index)


func _draw() -> void:
	var center := Vector2(size.x * 0.5, 37.0)
	draw_circle(center, CLOCK_RADIUS + 4.0, Color(0.25, 0.18, 0.08, 1.0))
	draw_circle(center, CLOCK_RADIUS + 1.5, Color(0.67, 0.50, 0.22, 1.0))
	draw_circle(center, CLOCK_RADIUS - 2.0, Color(0.91, 0.87, 0.73, 1.0))
