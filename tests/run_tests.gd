extends SceneTree
## Headless test runner. Usage:
##   godot --headless --path . -s tests/run_tests.gd
## Discovers tests/test_*.gd, runs every test_* method, exits 1 on failure.


func _init() -> void:
	var total_pass := 0
	var total_fail := 0
	var all_failures: PackedStringArray = []

	var files := DirAccess.get_files_at("res://tests/")
	files.sort()
	for f in files:
		if not (f.begins_with("test_") and f.ends_with(".gd")) or f == "test_case.gd":
			continue
		var script: GDScript = load("res://tests/" + f)
		var case = script.new()
		if not (case is TestCase):
			continue
		var result: Array = case.run_all()
		total_pass += result[0]
		total_fail += result[1]
		all_failures.append_array(case.failures)
		print("%-32s %d passed, %d failed" % [f, result[0], result[1]])

	print("")
	for msg in all_failures:
		printerr("FAIL " + msg)
	print("TOTAL: %d passed, %d failed" % [total_pass, total_fail])
	quit(1 if total_fail > 0 else 0)
