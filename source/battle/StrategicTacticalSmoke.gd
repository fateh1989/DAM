extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _fail(code: int, message: String) -> void:
	push_error(message)
	quit(code)


func _run() -> void:
	if not GameState.ensure_started():
		_fail(2, "Strategic/tactical smoke: GameState failed")
		return

	for signature_id in ["ui", "friendly_tank", "enemy_tank", "sheep", "industrial", "oil", "grain", "market", "electric", "water"]:
		if not AudioFocusManager.has_signature(signature_id):
			_fail(17, "Strategic/tactical smoke: missing audio signature " + signature_id)
			return

	var snapshot := GameState.get_country_snapshot("syria")
	if snapshot.is_empty():
		_fail(3, "Strategic/tactical smoke: persistent army missing")
		return

	if not GameState.begin_battle("aleppo", "حلب"):
		_fail(4, "Strategic/tactical smoke: battle did not start")
		return

	var packed := load("res://source/battle/TacticalBattle.tscn")
	if packed == null:
		_fail(5, "Strategic/tactical smoke: tactical scene load failed")
		return

	var battle = packed.instantiate()
	root.add_child(battle)
	await process_frame

	if battle.camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		_fail(6, "Strategic/tactical smoke: camera is not orthogonal")
		return
	if battle.get_zoom_level() != 1:
		_fail(7, "Strategic/tactical smoke: initial zoom must be 1")
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
	if battle.camera.size >= original_size:
		_fail(12, "Strategic/tactical smoke: close zoom did not reduce camera size")
		return

	battle.select_units([0, 1])
	if battle.get_selected_count() != 2:
		_fail(13, "Strategic/tactical smoke: multi-select failed")
		return
	battle.issue_attack_order(0)
	for _i in range(100):
		battle._process(0.1)
	if battle.get_alive_enemy_count() >= 6:
		_fail(14, "Strategic/tactical smoke: selected units did not damage enemy")
		return

	var before_uv: Vector2 = battle.get_radar_camera_uv()
	battle.radar_center_on_uv(Vector2(0.6, 0.6))
	var after_uv: Vector2 = battle.get_radar_camera_uv()
	if before_uv.distance_to(after_uv) < 0.0001:
		_fail(15, "Strategic/tactical smoke: radar camera jump failed")
		return

	GameState.finish_battle({"result": "test"})
	if not GameState.active_battle.is_empty():
		_fail(16, "Strategic/tactical smoke: battle state did not clear")
		return

	print("Strategic/tactical smoke: battle split + 2-step camera + radar + multi-select + combat OK")
	quit(0)
