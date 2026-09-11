class_name TestCase
extends RefCounted
## Minimal test base. Subclasses define test_* methods and call the assert helpers.
## Kept dependency-free so it runs on a bare headless Godot.

var failures: PackedStringArray = []
var _current: String = ""


func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		failures.append("%s: expected true. %s" % [_current, msg])


func assert_eq(a: Variant, b: Variant, msg: String = "") -> void:
	if a != b:
		failures.append("%s: expected %s == %s. %s" % [_current, str(a), str(b), msg])


func assert_near(a: float, b: float, eps: float = 0.001, msg: String = "") -> void:
	if absf(a - b) > eps:
		failures.append("%s: expected %f ~= %f. %s" % [_current, a, b, msg])


func run_all() -> Array:
	# Returns [passed, failed]
	var passed := 0
	var failed := 0
	for m in get_method_list():
		if not m.name.begins_with("test_"):
			continue
		_current = m.name
		var before := failures.size()
		call(m.name)
		if failures.size() == before:
			passed += 1
		else:
			failed += 1
	return [passed, failed]
