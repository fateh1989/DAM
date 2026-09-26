extends RefCounted

const ROSTER_SCRIPT := preload("res://source/world/HeavyWeaponRoster.gd")
const VISUAL_SCRIPT := preload("res://source/world/HeavyWeaponVisual.gd")

func run(scene: Node) -> String:
	var roster = ROSTER_SCRIPT.new()
	roster.setup(14)
	if roster.province_count() != 14:
		return "heavy weapon roster does not cover fourteen governorates"
	for i in range(14):
		if roster.get_count(i, "tank") != 50:
			return "governorate tank count is not fifty"
		if roster.get_count(i, "launcher") != 20:
			return "governorate launcher count is not twenty"
		if roster.get_count(i, "artillery") != 30:
			return "governorate artillery count is not thirty"
		if roster.get_province_total(i) != 100:
			return "governorate heavy weapon total is not one hundred"
	if roster.get_total_by_type("tank") != 700:
		return "country tank total is not seven hundred"
	if roster.get_total_by_type("launcher") != 280:
		return "country launcher total is not two hundred eighty"
	if roster.get_total_by_type("artillery") != 420:
		return "country artillery total is not four hundred twenty"
	if roster.get_grand_total() != 1400:
		return "country heavy weapon total is not fourteen hundred"

	var west_tank := VISUAL_SCRIPT.new()
	west_tank.setup("tank", "west", 0, 50)
	var east_tank := VISUAL_SCRIPT.new()
	east_tank.setup("tank", "east", 0, 50)
	var west_sig: Dictionary = west_tank.call("get_visual_signature")
	var east_sig: Dictionary = east_tank.call("get_visual_signature")
	if west_sig.get("hull_size", Vector3.ZERO) == east_sig.get("hull_size", Vector3.ZERO):
		west_tank.free()
		east_tank.free()
		return "west and east tanks do not have different hull proportions"
	west_tank.free()
	east_tank.free()

	for family_name in ["west", "east"]:
		var tank := VISUAL_SCRIPT.new()
		tank.setup("tank", family_name, 0, 50)
		if tank.get_part("TurretPivot") == null or tank.get_part("Barrel") == null:
			tank.free()
			return "tank visual lacks independent turret and barrel structure"
		if tank.get_part("Track_L") == null or tank.get_part("Track_R") == null:
			tank.free()
			return "tank visual lacks left and right tracks"
		tank.free()

		var launcher := VISUAL_SCRIPT.new()
		launcher.setup("launcher", family_name, 0, 20)
		if launcher.get_part("LauncherPivot") == null or launcher.get_part("RocketPod_00") == null:
			launcher.free()
			return "launcher visual lacks rotating launcher structure"
		var expected_pods := 2 if family_name == "west" else 3
		if int(launcher.call("get_launcher_pod_count")) != expected_pods:
			launcher.free()
			return "launcher family pod layout is incorrect"
		launcher.free()

		var artillery := VISUAL_SCRIPT.new()
		artillery.setup("artillery", family_name, 0, 30)
		if artillery.get_part("TurretPivot") == null or artillery.get_part("BarrelPivot") == null:
			artillery.free()
			return "artillery visual lacks turret and elevation pivot"
		if family_name == "west" and artillery.get_part("RearAmmoBox") == null:
			artillery.free()
			return "western artillery lacks rear ammunition housing"
		if family_name == "east" and artillery.get_part("CommanderCupola") == null:
			artillery.free()
			return "eastern artillery lacks compact cupola silhouette"
		artillery.free()

	return ""
