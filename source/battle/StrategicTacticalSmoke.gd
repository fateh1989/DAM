extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _fail(code: int, message: String) -> void:
	push_error(message)
	quit(code)


func _ensure_service(node_name: String, script_path: String) -> Node:
	var service := root.get_node_or_null(node_name)
	if service != null:
		return service
	var script = load(script_path)
	if script == null:
		return null
	service = Node.new()
	service.name = node_name
	service.set_script(script)
	root.add_child(service)
	return service


func _run() -> void:
	print("SMOKE checkpoint 1: services")
	var game_state := _ensure_service("GameState", "res://source/state/GameState.gd")
	var audio := _ensure_service("AudioFocusManager", "res://source/audio/AudioFocusManager.gd")
	await process_frame
	print("SMOKE checkpoint 2: services ready")

	if game_state == null or not bool(game_state.call("ensure_started")):
		_fail(2, "Strategic/tactical smoke: GameState failed")
		return
	if audio == null:
		_fail(17, "Strategic/tactical smoke: AudioFocusManager failed")
		return

	for signature_id in ["ui", "friendly_tank", "enemy_tank", "sheep", "industrial", "oil", "grain", "market", "electric", "water"]:
		if not bool(audio.call("has_signature", signature_id)):
			_fail(18, "Strategic/tactical smoke: missing audio signature " + signature_id)
			return

	var snapshot: Dictionary = game_state.call("get_country_snapshot", "syria")
	if snapshot.is_empty():
		_fail(3, "Strategic/tactical smoke: persistent army missing")
		return

	if not bool(game_state.call("begin_battle", "aleppo", "حلب")):
		_fail(4, "Strategic/tactical smoke: battle did not start")
		return

	print("SMOKE checkpoint 3: state ready")
	var packed := load("res://source/battle/TacticalBattle.tscn")
	if packed == null:
		_fail(5, "Strategic/tactical smoke: tactical scene load failed")
		return

	var battle = packed.instantiate()
	root.add_child(battle)
	print("SMOKE checkpoint 4: battle added")
	await process_frame
	print("SMOKE checkpoint 5: first frame")

	var select_all_button := battle.get_node_or_null("HUD/CommandBar/SelectAllButton") as Control
	var stop_button := battle.get_node_or_null("HUD/CommandBar/StopButton") as Control
	if not bool(audio.call("is_control_bound", select_all_button)) or not bool(audio.call("is_control_bound", stop_button)):
		_fail(32, "Strategic/tactical smoke: mobile battle controls are missing audio focus binding")
		return
	audio.call("focus_object", "smoke:friendly-tank", "friendly_tank", true)
	if str(audio.call("get_last_focus_key")) != "smoke:friendly-tank":
		_fail(33, "Strategic/tactical smoke: touch/hover audio focus did not register")
		return

	var battle_context: Dictionary = battle.get_battle_context()
	if str(battle_context.get("province_id", "")) != "aleppo":
		_fail(19, "Strategic/tactical smoke: tactical battle lost province id")
		return
	if str(battle_context.get("province_name", "")) != "حلب":
		_fail(20, "Strategic/tactical smoke: tactical battle lost province name")
		return

	if battle.camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		_fail(6, "Strategic/tactical smoke: camera is not orthogonal")
		return
	if battle.get_zoom_level() != 1:
		_fail(7, "Strategic/tactical smoke: initial zoom must be 1")
		return
	if absf(battle.get_zoom_target_size() - 1100.0) > 0.01:
		_fail(21, "Strategic/tactical smoke: normal zoom target mismatch")
		return
	if battle.get_unit_count() != 6 or battle.get_enemy_count() != 6:
		_fail(8, "Strategic/tactical smoke: expected 6 friendly and 6 enemy tanks")
		return
	var friendly_positions: Array[Vector3] = battle.get_friendly_positions()
	var enemy_positions: Array[Vector3] = battle.get_enemy_positions()
	if friendly_positions.size() != 6 or enemy_positions.size() != 6:
		_fail(23, "Strategic/tactical smoke: spawn position counts mismatch")
		return
	for position in friendly_positions:
		if position.z <= 0.0:
			_fail(24, "Strategic/tactical smoke: friendly spawn crossed battle line")
			return
	for position in enemy_positions:
		if position.z >= 0.0:
			_fail(25, "Strategic/tactical smoke: enemy spawn crossed battle line")
			return
	if battle.get_node_or_null("HUD/BattleRadar") == null:
		_fail(9, "Strategic/tactical smoke: battle radar missing")
		return
	if battle.get_radar_blips().size() != 12:
		_fail(10, "Strategic/tactical smoke: radar blips mismatch")
		return

	var original_size: float = battle.camera.size
	battle.toggle_zoom()
	await process_frame
	if battle.get_zoom_level() != 2:
		_fail(11, "Strategic/tactical smoke: zoom 2 failed")
		return
	if absf(battle.get_zoom_target_size() - 550.0) > 0.01:
		_fail(22, "Strategic/tactical smoke: close zoom target mismatch")
		return
	if battle.camera.size >= original_size:
		_fail(12, "Strategic/tactical smoke: close zoom did not reduce camera size")
		return

	print("SMOKE checkpoint 6: camera/radar basic checks")
	var selected_indices: Array[int] = [0, 1]
	battle.select_units(selected_indices)
	if battle.get_selected_count() != 2:
		_fail(13, "Strategic/tactical smoke: multi-select failed")
		return
	var before_move: Vector3 = battle.get_friendly_positions()[0]
	battle.issue_group_move(Vector3(-50.0, 0.0, 80.0))
	for _move_step in range(5):
		battle._process(0.1)
	var after_move: Vector3 = battle.get_friendly_positions()[0]
	if before_move.distance_to(after_move) < 1.0:
		_fail(26, "Strategic/tactical smoke: selected group did not move")
		return
	var enemy_health_before: float = battle.get_enemy_health(0)
	battle.issue_attack_order(0)
	for _i in range(100):
		battle._process(0.1)
	var enemy_health_after: float = battle.get_enemy_health(0)
	if enemy_health_after >= enemy_health_before:
		_fail(27, "Strategic/tactical smoke: attack order did not reduce enemy health")
		return
	if battle.get_alive_enemy_count() >= 6:
		_fail(14, "Strategic/tactical smoke: selected units did not damage enemy")
		return

	print("SMOKE checkpoint 7: combat simulated")
	var before_uv: Vector2 = battle.get_radar_camera_uv()
	battle.radar_center_on_uv(Vector2(0.6, 0.6))
	var after_uv: Vector2 = battle.get_radar_camera_uv()
	if before_uv.distance_to(after_uv) < 0.0001:
		_fail(15, "Strategic/tactical smoke: radar camera jump failed")
		return
	battle.radar_center_on_uv(Vector2(2.0, -1.0))
	var clamped_uv: Vector2 = battle.get_radar_camera_uv()
	if clamped_uv.x < 0.0 or clamped_uv.x > 1.0 or clamped_uv.y < 0.0 or clamped_uv.y > 1.0:
		_fail(28, "Strategic/tactical smoke: radar recenter escaped battlefield bounds")
		return

	print("SMOKE checkpoint 8: radar moved")
	battle._on_select_all_pressed()
	if battle.get_selected_count() != 6:
		_fail(29, "Strategic/tactical smoke: SELECT ALL did not select every friendly unit")
		return
	battle.issue_group_move(Vector3(260.0, 0.0, 180.0))
	if battle.are_selected_units_stopped():
		_fail(30, "Strategic/tactical smoke: group move did not arm movement before STOP")
		return
	battle._on_stop_pressed()
	if not battle.are_selected_units_stopped():
		_fail(31, "Strategic/tactical smoke: STOP did not clear movement and attack orders")
		return

	game_state.call("finish_battle", {"result": "test"})
	var active_battle: Dictionary = game_state.get("active_battle")
	if not active_battle.is_empty():
		_fail(16, "Strategic/tactical smoke: battle state did not clear")
		return

	print("Strategic/tactical smoke: state + battle + 2-step camera + radar + combat + audio OK")
	quit(0)
