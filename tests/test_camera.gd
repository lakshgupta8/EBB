extends TestCase
## The following camera (map Stage 02, STYLE.md 22): the view never leaves the room, a room no
## larger than the screen sits centred, and the large test room is a room the run can use.

const VIEW := Vector2(640, 360)


func test_one_screen_room_is_centred() -> void:
	var rect := Rect2(0, 0, 640, 368)
	for want in [Vector2(0, 0), Vector2(320, 184), Vector2(900, -50)]:
		var at := GameCamera.clamp_to_room(want, rect, VIEW)
		assert_eq(at.x, 320.0, "x centred for %s" % want)
		assert_true(at.y >= 180.0 and at.y <= 188.0, "y within the 8 px overhang for %s" % want)


func test_large_room_keeps_the_view_inside() -> void:
	var rect := Rect2(0, 0, 1280, 736)
	assert_eq(GameCamera.clamp_to_room(Vector2(10, 10), rect, VIEW), Vector2(320, 180), "top left corner")
	assert_eq(GameCamera.clamp_to_room(Vector2(5000, 5000), rect, VIEW), Vector2(960, 556), "bottom right corner")
	assert_eq(GameCamera.clamp_to_room(Vector2(640, 368), rect, VIEW), Vector2(640, 368), "free in the middle")


func test_corridor_follows_on_one_axis_only() -> void:
	var rect := Rect2(0, 0, 1280, 368)
	var at := GameCamera.clamp_to_room(Vector2(700, 30), rect, VIEW)
	assert_eq(at.x, 700.0, "follows along the corridor")
	assert_true(at.y >= 180.0 and at.y <= 188.0, "held across it")


func test_large_test_room() -> void:
	var t := RoomTemplate.load_file("res://data/rooms/test/flats_L_test.txt")
	assert_eq(t.width, 80, "two screens wide")
	assert_eq(t.height, 46, "two screens tall")
	assert_eq(t.doors.size(), 3, "three doors")
	assert_true(t.enemy_spawns.size() >= 8, "spawns across the pockets")
