extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _fail(code: int, message: String) -> void:
	push_error(message)
	quit(code)


func _run() -> void:
	var packed := load("res://source/world/MiddleEastTerrain.tscn")
	if packed == null:
		_fail(2, "Strategic geography smoke: scene load failed")
		return

	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame

	if scene._geo_overlay_data.is_empty():
		_fail(3, "Strategic geography smoke: Syria overlay data missing")
		return
	if scene._geo_overlay_data.get("boundaries", []).size() < 1:
		_fail(4, "Strategic geography smoke: no administrative boundaries")
		return
	if scene._geo_overlay_data.get("labels", []).size() < 10:
		_fail(5, "Strategic geography smoke: too few labels")
		return
	if scene.get_node_or_null("HUD/RTSRadar") == null:
		_fail(6, "Strategic geography smoke: strategic radar missing")
		return
	if scene.mode_button.text != "START BATTLE":
		_fail(7, "Strategic geography smoke: battle entry button missing")
		return

	var battle_scene := load("res://source/battle/TacticalBattle.tscn")
	if battle_scene == null:
		_fail(8, "Strategic geography smoke: tactical battle scene missing")
		return

	var army: Dictionary = scene.get_country_army_snapshot("syria")
	if army.is_empty():
		_fail(9, "Strategic geography smoke: persistent army not connected")
		return

	print("Strategic geography smoke: Syria data + radar + battle entry + persistent army OK")
	quit(0)
