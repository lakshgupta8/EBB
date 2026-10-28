extends TestCase
## Sound placed in the world (audio Stage 03, STYLE.md 23.5 and 23.6): a tell takes a voice
## from the world, the world never takes one from a tell, and a far tell is still heard.


func _tells() -> int:
	var n := 0
	for p in Audio._pool2d:
		if p.playing and int(p.get_meta("pri")) == Audio.PRI_TELL:
			n += 1
	return n


func test_a_tell_takes_a_voice_and_is_never_taken() -> void:
	var cam := Camera2D.new()
	Audio.add_child(cam)  # the root is busy while the tests start
	cam.make_current()
	for p in Audio._pool2d:
		p.stop()
	for i in Audio.POOL_2D:
		Audio.play_at(Vector2(10, 0), "door", 0.0, 0.0, 0)
	var busy := 0
	for p in Audio._pool2d:
		busy += 1 if p.playing else 0
	assert_eq(busy, Audio.POOL_2D, "the world fills every placed voice")
	Audio.play_at(Vector2(2000, 0), "bell", 0.0, 0.0, 0)
	assert_eq(_tells(), 1, "a tell takes a voice from the world")
	var far: AudioStreamPlayer2D = null
	for p in Audio._pool2d:
		if int(p.get_meta("pri")) == Audio.PRI_TELL:
			far = p
	assert_true(far.max_distance >= 2000.0 * 1.8 - 1.0, "a far tell's fall-off stretches past it (%.0f)" % far.max_distance)
	for i in Audio.POOL_2D - 1:
		Audio.play_at(Vector2(0, 0), "bell", 0.0, 0.0, 0)
	assert_eq(_tells(), Audio.POOL_2D, "tells fill the voices")
	Audio.play_at(Vector2(0, 0), "door", 0.0, 0.0, 0)
	assert_eq(_tells(), Audio.POOL_2D, "the world never takes a tell's voice")
	for p in Audio._pool2d:
		p.stop()
	cam.queue_free()
