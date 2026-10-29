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


func test_the_mood_sets_the_stems() -> void:
	var calm := MusicDirector.targets(false, 0.2, false)
	assert_eq(calm.bed, 0.0, "the bed always plays")
	assert_eq(calm.rhythm, MusicDirector.OFF, "exploring: no rhythm")
	var fight := MusicDirector.targets(true, 0.2, false)
	assert_true(fight.rhythm == 0.0 and fight.danger == 0.0, "a fight: rhythm and danger")
	assert_eq(MusicDirector.targets(false, 0.6, false).tide, 0.0, "the tide past half: its stem")
	assert_eq(MusicDirector.targets(true, 0.0, true).melody, -6.0, "Tam low: the melody back")


func test_a_score_is_sections_of_stems() -> void:
	var built := MusicDirector.build({"dir": "res://tests/music/test", "bpm": 120, "bar_beats": 4, "first": "b",
		"sections": {"a": {"bars": 2, "next": "b"}, "b": {"bars": 2}}})
	var stream: AudioStreamInteractive = built[0]
	assert_eq(stream.clip_count, 2)
	assert_eq(stream.initial_clip, 1, "it starts where it is told")
	assert_eq(stream.get_clip_auto_advance_next_clip(0), 1, "a runs on into b")
	var sync: AudioStreamSynchronized = built[1][0]
	var ogg := sync.get_sync_stream(MusicDirector.STEMS.find("rhythm")) as AudioStreamOggVorbis
	assert_true(ogg != null and ogg.beat_count == 8 and not ogg.loop, "a section's stem knows its bars, and runs on rather than loops")
	assert_true((built[1][1].get_sync_stream(0) as AudioStreamOggVorbis).loop, "a section with no next loops")


func test_an_echo_brought_home_is_heard_on_the_rock() -> void:
	var t := MusicDirector.targets(false, 0.0, false, {"bram": true, "wren": false})
	assert_eq(t.bram, 0.0, "an echo home: its layer plays")
	assert_eq(t.wren, MusicDirector.OFF, "an echo still out there: silent")
	assert_eq(t.bed, 0.0, "the rock's bed as ever")
