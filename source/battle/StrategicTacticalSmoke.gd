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
	if battle.get_unit_count() != 6:
		_fail(8, "Strategic/tactical smoke: expected six tactical tanks")
		return

	var original_size: float = battle.camera.size
	battle.toggle_zoom()
	await process_frame
	if battle.get_zoom_level() != 2:
		_fail(9, "Strategic/tactical smoke: zoom 2 failed")
		return
	if battle.camera.size >= original_size:
		_fail(10, "Strategic/tactical smoke: close zoom did not reduce camera size")
		return

	GameState.finish_battle({"result": "test"})
	if not GameState.active_battle.is_empty():
		_fail(11, "Strategic/tactical smoke: battle state did not clear")
		return

	print("Strategic/tactical smoke: persistent state + separate battlefield + 2-step camera OK")
	quit(0)
