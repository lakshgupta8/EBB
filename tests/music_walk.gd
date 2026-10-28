extends Node
## Walks the music director through every state of a night on the test score (audio Stage 05):
## exploring, the sections running on, a fight, the tide high, Tam low, a boss's two phases, the
## kill and back. Checks the stems follow the mood, the sections change on bar lines, and a
## stinger lands on a beat. Plays in real time (about 40 s).
##   godot --headless --path . tests/music_walk.tscn

const SPEC := {
	"dir": "res://tests/music/test", "bpm": 120, "bar_beats": 4, "first": "a",
	"sections": {"a": {"bars": 2, "next": "b"}, "b": {"bars": 2, "next": "a"}, "boss1": {"bars": 2},
		"boss2": {"bars": 2}, "kill": {"bars": 1, "next": "a"}},
}
const BAR := 2.0  # seconds: 4 beats at 120

var fails: int = 0
var _d: MusicDirector
var _changes: Array = []  # [seconds since start, clip]
var _last: String = ""


func _ready() -> void:
	_d = Audio.director
	_d.play("test", 0.0, SPEC)
	_d.mood(false, 0.0, 1.0)
	await _wait(0.3)
	_check(_d.current() == "a", "the score starts in a (%s)" % _d.current())
	_check(_vol("rhythm") <= MusicDirector.OFF and _vol("bed") == 0.0, "exploring: the bed, no rhythm")
	await _wait(4.4)
	_check("b" in _seen(), "a runs on into b after its two bars (%s)" % str(_changes))

	_d.mood(true, 0.0, 1.0)
	await _wait(1.0)
	_check(_vol("rhythm") > MusicDirector.OFF and _vol("rhythm") < 0.0, "a fight brings the rhythm in gradually (%.1f dB after a second)" % _vol("rhythm"))
	await _wait(3.5)
	_check(_vol("rhythm") == 0.0 and _vol("danger") == 0.0, "after two bars the rhythm and the danger are full")
	_check(_vol("tide") <= MusicDirector.OFF, "the tide stem waits for the tide")
	_d.mood(true, 0.8, 1.0)
	await _wait(4.5)
	_check(_vol("tide") == 0.0, "the tide past half brings its stem in")
	_d.mood(true, 0.8, 0.2)
	await _wait(2.0)
	_check(_vol("melody") == -6.0, "Tam low pulls the melody back 6 dB")
	_check(_d._cutoff < 1500.0, "and closes the low-pass (%.0f Hz)" % _d._cutoff)
	_d.mood(false, 0.2, 1.0)
	await _wait(4.5)
	_check(_vol("rhythm") <= MusicDirector.OFF and _d._cutoff > 15000.0, "the clear: back to the bed, the low-pass open")

	for name in ["boss1", "boss2", "kill"]:
		await _wait(randf_range(0.3, 1.6))  # asked off the bar
		_d.switch(name)
		await _wait(BAR + 0.5)
		_check(name in _seen() or (name == "kill" and "a" in _seen()), "%s plays when asked" % name)
	await _wait(BAR + 0.5)
	_check(_last == "a", "the kill runs on into a (%s)" % _last)
	# Every change is on a bar line, by the audio's clock (a frame and a mix buffer apart: 60 ms).
	for c in _changes.slice(1):
		var off: float = fmod(float(c[0]), BAR)
		off = minf(off, BAR - off)
		_check(off < 0.06, "%s began on a bar line (%.3f s off)" % [c[1], off])

	var fired := []
	var t_ask := _d.beats()
	_d.stinger("ui", -30.0)
	Audio._last_play.erase("ui")
	var before := int(Audio.asked.get("ui", 0))
	while int(Audio.asked.get("ui", 0)) == before:
		await get_tree().process_frame
	fired.append(_d.beats())
	var frac: float = fmod(float(fired[0]), 1.0)
	_check(minf(frac, 1.0 - frac) < 0.06 and fired[0] > t_ask, "a stinger waits for the next beat (%.3f -> %.3f beats)" % [t_ask, fired[0]])

	_d.stop()
	print("music_walk: %s" % ("OK" if fails == 0 else "%d FAILED" % fails))
	get_tree().quit(0 if fails == 0 else 1)


func _process(_delta: float) -> void:
	if _d == null or _d.score_id == "":
		return
	var c := _d.current()
	if c != _last and c != "":
		_changes.append([_d.seconds(), c])
		_last = c


func _seen() -> Array:
	return _changes.map(func(c): return c[1])


func _vol(stem: String) -> float:
	return float(_d._vol.get(stem, MusicDirector.OFF))


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _check(ok: bool, what: String) -> void:
	print("music_walk: %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails += 1
