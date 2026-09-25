extends Node

const MIX_RATE := 22050.0
const FOCUS_COOLDOWN_MSEC := 180
const SIGNATURE_IDS := [
	"ui",
	"friendly_tank",
	"enemy_tank",
	"sheep",
	"industrial",
	"oil",
	"grain",
	"market",
	"electric",
	"water",
]

var _player: AudioStreamPlayer
var _ui_player: AudioStreamPlayer
var _buffers := {}
var _last_focus_key := ""
var _last_play_msec := -10000


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "FocusSignaturePlayer"
	add_child(_player)

	_ui_player = AudioStreamPlayer.new()
	_ui_player.name = "UISignaturePlayer"
	_ui_player.volume_db = -5.0
	add_child(_ui_player)

	for signature_id in SIGNATURE_IDS:
		_buffers[signature_id] = _build_buffer(signature_id)


func has_signature(signature_id: String) -> bool:
	return _buffers.has(signature_id)


func get_last_focus_key() -> String:
	return _last_focus_key


func is_control_bound(control: Control) -> bool:
	return control != null and bool(control.get_meta("dam_audio_bound", false))


func focus_object(focus_key: String, signature_id: String, force: bool = false) -> void:
	if focus_key.is_empty() or not _buffers.has(signature_id):
		return
	var now := Time.get_ticks_msec()
	if not force and focus_key == _last_focus_key:
		return
	if not force and now - _last_play_msec < FOCUS_COOLDOWN_MSEC:
		_last_focus_key = focus_key
		return

	_last_focus_key = focus_key
	_last_play_msec = now
	_play_buffer(_player, signature_id)
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(18)


func clear_focus() -> void:
	_last_focus_key = ""


func bind_control(control: Control, signature_id: String = "ui") -> void:
	if control == null or control.has_meta("dam_audio_bound"):
		return
	control.set_meta("dam_audio_bound", true)
	control.mouse_entered.connect(_on_control_hover.bind(control, signature_id))
	if control.has_signal("pressed"):
		control.connect("pressed", Callable(self, "_on_control_pressed").bind(control, signature_id))


func _on_control_hover(control: Control, signature_id: String) -> void:
	focus_object("ui:%s" % control.get_path(), signature_id)


func _on_control_pressed(control: Control, signature_id: String) -> void:
	focus_object("ui-press:%s:%d" % [control.get_path(), Time.get_ticks_msec()], signature_id, true)


func _play_buffer(player: AudioStreamPlayer, signature_id: String) -> void:
	var frames: PackedVector2Array = _buffers.get(signature_id, PackedVector2Array())
	if frames.is_empty():
		return
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = maxf(0.25, float(frames.size()) / MIX_RATE + 0.08)
	player.stream = stream
	player.play()
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback != null:
		playback.push_buffer(frames)


func _duration(signature_id: String) -> float:
	match signature_id:
		"ui":
			return 0.09
		"friendly_tank":
			return 0.24
		"enemy_tank":
			return 0.34
		"sheep":
			return 0.48
		"industrial":
			return 0.52
		"oil":
			return 0.42
		"grain":
			return 0.34
		"market":
			return 0.38
		"electric":
			return 0.28
		"water":
			return 0.42
		_:
			return 0.20


func _envelope(t: float, duration: float, attack: float = 0.02, release: float = 0.10) -> float:
	var a := minf(1.0, t / maxf(0.001, attack))
	var r := minf(1.0, (duration - t) / maxf(0.001, release))
	return clampf(minf(a, r), 0.0, 1.0)


func _build_buffer(signature_id: String) -> PackedVector2Array:
	var duration := _duration(signature_id)
	var sample_count := maxi(1, int(duration * MIX_RATE))
	var frames := PackedVector2Array()
	frames.resize(sample_count)
	for i in range(sample_count):
		var t := float(i) / MIX_RATE
		var sample := clampf(_sample(signature_id, t, duration), -0.92, 0.92)
		frames[i] = Vector2(sample, sample)
	return frames


func _sample(signature_id: String, t: float, duration: float) -> float:
	var tau := TAU
	match signature_id:
		"ui":
			return _envelope(t, duration, 0.005, 0.04) * (
				0.60 * sin(tau * 760.0 * t)
				+ 0.25 * sin(tau * 1180.0 * t)
			) * exp(-18.0 * t)

		"friendly_tank":
			return _envelope(t, duration, 0.005, 0.08) * (
				0.50 * sin(tau * 145.0 * t)
				+ 0.24 * sin(tau * 290.0 * t)
				+ 0.18 * sin(tau * 900.0 * t) * exp(-16.0 * t)
			)

		"enemy_tank":
			var pulse := 1.0 if sin(tau * 7.0 * t) > 0.0 else 0.35
			var freq := 560.0 - 220.0 * (t / duration)
			return _envelope(t, duration, 0.01, 0.08) * pulse * (
				0.55 * sin(tau * freq * t)
				+ 0.18 * sin(tau * freq * 2.03 * t)
			)

		"sheep":
			var vibrato := 1.0 + 0.075 * sin(tau * 9.0 * t)
			var freq := (390.0 + 130.0 * sin(PI * t / duration)) * vibrato
			var tremolo := 0.72 + 0.28 * sin(tau * 7.0 * t)
			return _envelope(t, duration, 0.03, 0.12) * tremolo * (
				0.48 * sin(tau * freq * t)
				+ 0.28 * sin(tau * freq * 1.9 * t)
				+ 0.12 * sin(tau * freq * 3.1 * t)
			)

		"industrial":
			var clank := exp(-70.0 * absf(t - 0.28)) * sin(tau * 720.0 * t)
			return _envelope(t, duration, 0.02, 0.10) * (
				0.38 * sin(tau * 92.0 * t)
				+ 0.23 * sin(tau * 184.0 * t)
				+ 0.16 * sin(tau * 276.0 * t)
				+ 0.25 * clank
			)

		"oil":
			var thump := sin(tau * 78.0 * t) * (0.65 + 0.35 * sin(tau * 3.8 * t))
			var mech := 0.20 * sin(tau * 310.0 * t) * maxf(0.0, sin(tau * 5.0 * t))
			return _envelope(t, duration, 0.01, 0.10) * (0.55 * thump + mech)

		"grain":
			var pseudo_noise := sin(tau * 1733.0 * t) * sin(tau * 947.0 * t)
			var swish := sin(tau * (420.0 + 120.0 * sin(tau * 2.0 * t)) * t)
			return _envelope(t, duration, 0.03, 0.10) * (0.22 * pseudo_noise + 0.20 * swish)

		"market":
			var bell := sin(tau * 720.0 * t) * exp(-5.0 * t)
			bell += 0.35 * sin(tau * 1040.0 * t) * exp(-8.0 * t)
			var second := 0.0
			if t > 0.18:
				second = 0.35 * sin(tau * 570.0 * (t - 0.18)) * exp(-10.0 * (t - 0.18))
			return _envelope(t, duration, 0.005, 0.08) * (0.52 * bell + second)

		"electric":
			return _envelope(t, duration, 0.01, 0.06) * (
				0.38 * sin(tau * 120.0 * t)
				+ 0.24 * sin(tau * 240.0 * t)
				+ 0.14 * sin(tau * 360.0 * t)
			)

		"water":
			var wash := sin(tau * 713.0 * t) * sin(tau * 281.0 * t)
			return _envelope(t, duration, 0.03, 0.12) * (
				0.22 * wash
				+ 0.18 * sin(tau * 190.0 * t)
				+ 0.12 * sin(tau * 260.0 * t)
			)

		_:
			return _envelope(t, duration) * 0.3 * sin(tau * 440.0 * t)
