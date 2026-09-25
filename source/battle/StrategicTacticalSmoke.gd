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
	battle.issue_attack_order(0)
	for _i in range(100):
		battle._process(0.1)
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

	print("SMOKE checkpoint 8: radar moved")
	game_state.call("finish_battle", {"result": "test"})
	var active_battle: Dictionary = game_state.get("active_battle")
	if not active_battle.is_empty():
		_fail(16, "Strategic/tactical smoke: battle state did not clear")
		return

	print("Strategic/tactical smoke: state + battle + 2-step camera + radar + combat + audio OK")
	quit(0)
