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


func test_the_bed_follows_the_tide() -> void:
	var out := Audio.bed_gains(0.0)
	assert_true(out[0] == 1.0 and out[1] == 0.0 and out[2] == 0.0, "tide out: only the dry layer")
	var low := Audio.bed_gains(1.0)
	assert_true(low[1] == 1.0 and low[2] == 0.0, "over the low ground: the water in the channels, no flood")
	var high := Audio.bed_gains(2.5)
	assert_true(high[2] == 1.0 and high[0] < 0.3, "over the floor: the flood, the dry all but gone")


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


## The drowned breathe between blows and never over their own tell; the Choir holds its note
## (audio Stage 12).
func test_the_drowned_breathe_and_the_choir_holds_its_note() -> void:
	var e: Enemy = load("res://src/enemies/mooring.tscn").instantiate()
	Audio.add_child(e)
	var heard := func() -> int: return int(Audio.asked.get("breath_drowned", 0)) + int(Audio.asked.get("groan_drowned", 0))
	var before: int = heard.call()
	for i in 4:
		Audio._last_play.erase("breath_drowned")
		Audio._last_play.erase("groan_drowned")
		e._tick_idle(Enemy.IDLE_EVERY.y + 0.1)
	assert_eq(heard.call() - before, 4, "wandering, it breathes each time its breath comes round")
	e.state = &"windup"
	before = heard.call()
	for i in 4:
		e._tick_idle(Enemy.IDLE_EVERY.y + 0.1)
	assert_eq(heard.call(), before, "winding up, it holds its breath")
	e.free()
	var c: Enemy = load("res://src/enemies/choir.tscn").instantiate()
	Audio.add_child(c)
	assert_true(c._hum != null and c._hum.playing, "the Choir's note is held from the start")
	assert_true((c._hum.stream as AudioStreamOggVorbis).loop, "and never runs out")
	c.free()
