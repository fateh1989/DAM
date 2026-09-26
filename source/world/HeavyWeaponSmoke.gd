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
		launcher.free()

		var artillery := VISUAL_SCRIPT.new()
		artillery.setup("artillery", family_name, 0, 30)
		if artillery.get_part("TurretPivot") == null or artillery.get_part("BarrelPivot") == null:
			artillery.free()
			return "artillery visual lacks turret and elevation pivot"
		artillery.free()

	return ""
