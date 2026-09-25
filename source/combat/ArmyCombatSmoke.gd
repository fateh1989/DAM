extends SceneTree

const ArmyCombatCoreScript = preload("res://source/combat/ArmyCombatCore.gd")


func _initialize() -> void:
	call_deferred("_run")


func _fail(code: int, message: String) -> void:
	push_error(message)
	quit(code)


func _run() -> void:
	var core = ArmyCombatCoreScript.new()
	if not core.load_catalogs():
		_fail(2, "Army combat smoke: catalogs failed to load")
		return
	if core.unit_specs.size() < 6:
		_fail(3, "Army combat smoke: unit catalog is incomplete")
		return
	if core.weapon_specs.size() < 8:
		_fail(4, "Army combat smoke: weapon catalog is incomplete")
		return

	if not core.create_country(
		"test_country",
		"اختبار",
		5000,
		{"tank": 2, "infantry_squad": 3, "fighter": 1}
	):
		_fail(5, "Army combat smoke: country creation failed")
		return

	var purchase: Dictionary = core.purchase("test_country", "tank", 1)
	if not bool(purchase.get("ok", false)):
		_fail(6, "Army combat smoke: purchase failed")
		return
	if int(purchase.get("treasury", -1)) != 3800:
		_fail(7, "Army combat smoke: treasury accounting is wrong")
		return

	var deploy: Dictionary = core.deploy("test_country", "tank", 2)
	if not bool(deploy.get("ok", false)):
		_fail(8, "Army combat smoke: deployment failed")
		return

	var attacker: Dictionary = core.create_unit_state("tank", "test_country")
	var target: Dictionary = core.create_unit_state("tank", "enemy")
	var fighter: Dictionary = core.create_unit_state("fighter", "enemy")
	if attacker.is_empty() or target.is_empty() or fighter.is_empty():
		_fail(9, "Army combat smoke: unit state creation failed")
		return

	var invalid_air_shot: Dictionary = core.resolve_shot(attacker, fighter, "tank_cannon")
	if bool(invalid_air_shot.get("ok", false)):
		_fail(10, "Army combat smoke: ground cannon targeted aircraft")
		return

	var shot_count := 0
	while bool(target.get("alive", true)) and shot_count < 10:
		var shot: Dictionary = core.resolve_shot(attacker, target, "tank_cannon")
		if not bool(shot.get("ok", false)):
			_fail(11, "Army combat smoke: tank shot resolution failed")
			return
		target = shot.get("target", {})
		shot_count += 1

	if bool(target.get("alive", true)):
		_fail(12, "Army combat smoke: damage never destroyed target")
		return

	var loss: Dictionary = core.record_loss("test_country", "tank", 1)
	if not bool(loss.get("ok", false)):
		_fail(13, "Army combat smoke: loss accounting failed")
		return

	var snapshot: Dictionary = core.get_country_snapshot("test_country")
	if int(snapshot["inventory"]["tank"]) != 1:
		_fail(14, "Army combat smoke: inventory accounting is wrong")
		return
	if int(snapshot["deployed"]["tank"]) != 1:
		_fail(15, "Army combat smoke: deployed accounting is wrong")
		return
	if int(snapshot["destroyed"]["tank"]) != 1:
		_fail(16, "Army combat smoke: destroyed accounting is wrong")
		return

	print("Army combat smoke: country inventory + purchase + deploy + weapons + damage + losses OK")
	quit(0)
