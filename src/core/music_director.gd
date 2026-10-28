class_name MusicDirector
extends Node
## A place's music that hears the night (audio Stage 05, STYLE.md 23.3). A score is sections
## (A, B, a breakdown, the boss's phases...) and each section is stems played in step: bed,
## melody, rhythm, danger, tide. The run says how the night is (`mood`): a fight brings in the
## rhythm and the danger over two bars, the tide past half its height brings in the tide stem,
## Tam at a quarter health or less closes a low-pass on the Music bus and pulls the melody back.
## Sections change on the next bar (`section`); a section with "next" runs on into it, one
## without loops. Stingers wait for the next beat.
##
## A score's spec (data/music.json, or given directly):
##   {"dir": "res://assets/audio/score/flats", "bpm": 66, "bar_beats": 4, "first": "a",
##    "sections": {"a": {"bars": 16, "next": "b"}, "b": {"bars": 16, "next": "a"}, "boss1": {"bars": 8}}}
## with files <dir>/<section>_<stem>.ogg; a stem a section does not have is silent there.

const SPEC_PATH := "res://data/music.json"
const STEMS := ["bed", "melody", "rhythm", "danger", "tide"]
const OFF := -60.0
const LOW_HP := 0.25
const TIDE_HIGH := 0.5
const LOWPASS_LOW := 900.0
const LOWPASS_OPEN := 20500.0

var specs: Dictionary = {}
var score_id: String = ""
var spec: Dictionary = {}
var section: String = ""
var bpm: float = 60.0
var bar_beats: int = 4
var fight: bool = false
var tide: float = 0.0     # 0..1 of the tide's height
var low: bool = false
var player: AudioStreamPlayer
var _stream: AudioStreamInteractive
var _syncs: Array = []    # one AudioStreamSynchronized per section, in clip order
var _vol: Dictionary = {}  # stem -> dB now
## The beat clock follows the audio, not the wall: a silent one-second loop started with the
## score, its laps counted (the section stream does not say where it is, and an audio driver's
## clock can run apart from the system's: headless Godot's runs 0.25 % fast).
var _clock: AudioStreamPlayer
var _laps: int = 0
var _last_pos: float = 0.0
var _cutoff: float = LOWPASS_OPEN


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if FileAccess.file_exists(SPEC_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(SPEC_PATH))
		if parsed is Dictionary:
			specs = parsed
	player = AudioStreamPlayer.new()
	player.bus = "Music"
	add_child(player)
	var silence := AudioStreamWAV.new()
	silence.format = AudioStreamWAV.FORMAT_16_BITS
	silence.mix_rate = 44100
	var zeros := PackedByteArray()
	zeros.resize(44100 * 2)  # a packed property hands back a copy: fill it, then set it
	silence.data = zeros
	silence.loop_mode = AudioStreamWAV.LOOP_FORWARD
	silence.loop_end = 44100
	_clock = AudioStreamPlayer.new()
	_clock.stream = silence
	_clock.volume_db = -80.0
	add_child(_clock)


func has_score(id: String) -> bool:
	return specs.has(id)


## The stems' levels for a mood, in dB (OFF is silent). Pure, so a test can walk it.
static func targets(is_fight: bool, tide_frac: float, is_low: bool) -> Dictionary:
	return {
		"bed": 0.0,
		"melody": -6.0 if is_low else 0.0,
		"rhythm": 0.0 if is_fight else OFF,
		"danger": 0.0 if is_fight else OFF,
		"tide": 0.0 if tide_frac > TIDE_HIGH else OFF,
	}


## Build the score's stream: a clip per section, each its stems in step.
static func build(s: Dictionary) -> Array:
	var stream := AudioStreamInteractive.new()
	var syncs: Array = []
	var names: Array = s.sections.keys()
	stream.clip_count = names.size()
	var dir: String = s.dir
	for i in names.size():
		var name: String = names[i]
		var sec: Dictionary = s.sections[name]
		var sync := AudioStreamSynchronized.new()
		sync.stream_count = STEMS.size()
		var loops: bool = not sec.has("next")
		for k in STEMS.size():
			var path := "%s/%s_%s.ogg" % [dir, name, STEMS[k]]
			if not ResourceLoader.exists(path):
				continue
			var ogg := (load(path) as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
			ogg.loop = loops
			ogg.bpm = float(s.bpm)
			ogg.bar_beats = int(s.get("bar_beats", 4))
			ogg.beat_count = int(sec.bars) * ogg.bar_beats
			sync.set_sync_stream(k, ogg)
			sync.set_sync_stream_volume(k, OFF)
		stream.set_clip_name(i, name)
		stream.set_clip_stream(i, sync)
		syncs.append(sync)
	for i in names.size():
		var sec: Dictionary = s.sections[names[i]]
		if sec.has("next"):
			stream.set_clip_auto_advance(i, AudioStreamInteractive.AUTO_ADVANCE_ENABLED)
			stream.set_clip_auto_advance_next_clip(i, names.find(sec.next))
	stream.initial_clip = maxi(0, names.find(s.get("first", names[0])))
	# Any section to any other on the next bar line, crossing over one beat.
	stream.add_transition(AudioStreamInteractive.CLIP_ANY, AudioStreamInteractive.CLIP_ANY,
		AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BAR, AudioStreamInteractive.TRANSITION_TO_TIME_START,
		AudioStreamInteractive.FADE_CROSS, 1.0)
	return [stream, syncs]


## Play a score from data/music.json (or `given`), its stems set for the mood at once.
func play(id: String, db: float = 0.0, given: Dictionary = {}) -> void:
	var s: Dictionary = given if not given.is_empty() else specs.get(id, {})
	if s.is_empty() or (id == score_id and player.playing):
		return
	var built := build(s)
	_stream = built[0]
	_syncs = built[1]
	spec = s
	score_id = id
	bpm = float(s.bpm)
	bar_beats = int(s.get("bar_beats", 4))
	section = str(s.get("first", s.sections.keys()[0]))
	_vol = targets(fight, tide, low)
	_apply_volumes()
	player.stream = _stream
	player.volume_db = db
	player.play()
	_clock.play()
	_laps = 0
	_last_pos = 0.0


func stop() -> void:
	score_id = ""
	section = ""
	_clock.stop()
	if player.playing:
		var tw := player.create_tween()
		tw.tween_property(player, "volume_db", -40.0, 1.5)
		tw.tween_callback(player.stop)


## How the night is now; the stems follow over two bars.
func mood(is_fight: bool, tide_frac: float, hp_frac: float) -> void:
	fight = is_fight
	tide = tide_frac
	low = hp_frac <= LOW_HP


## Change section on the next bar line (a boss's phase, the kill...).
func switch(name: String) -> void:
	if score_id == "" or not spec.sections.has(name) or name == section:
		return
	var pb := player.get_stream_playback() as AudioStreamPlaybackInteractive
	if pb == null:
		return
	pb.switch_to_clip_by_name(name)
	section = name


## Seconds of audio since the score began.
func seconds() -> float:
	if not _clock.playing:
		return 0.0
	var pos := _clock.get_playback_position()
	if pos < _last_pos:
		_laps += 1
	_last_pos = pos
	return _laps + pos + AudioServer.get_time_since_last_mix()


## Beats since the score began (for stingers on the beat).
func beats() -> float:
	return seconds() * bpm / 60.0


## A clip on the next beat (or now, with no score playing).
func stinger(name: String, db: float = 0.0) -> void:
	if score_id == "":
		Audio.play(name, 0.0, db)
		return
	var b := beats()
	var wait := (ceilf(b) - b) * 60.0 / bpm
	get_tree().create_timer(wait, true, false, true).timeout.connect(func(): Audio.play(name, 0.0, db))


## The clip now playing, by name ("" when none).
func current() -> String:
	var pb := player.get_stream_playback() as AudioStreamPlaybackInteractive if player.playing else null
	if pb == null:
		return ""
	var i := pb.get_current_clip_index()
	return _stream.get_clip_name(i) if i >= 0 else ""


func _process(delta: float) -> void:
	if score_id == "":
		return
	seconds()  # count the clock's laps every frame
	# From silent to full in two bars.
	var rate := -OFF / (2.0 * bar_beats * 60.0 / bpm)
	var want := targets(fight, tide, low)
	for k in want:
		_vol[k] = move_toward(float(_vol.get(k, OFF)), want[k], rate * delta)
	_apply_volumes()
	var cut := LOWPASS_LOW if low else LOWPASS_OPEN
	_cutoff = lerpf(_cutoff, cut, 1.0 - exp(-delta * 3.0))
	var bus := AudioServer.get_bus_index("Music")
	if bus != -1 and AudioServer.get_bus_effect_count(bus) > 1:
		(AudioServer.get_bus_effect(bus, 1) as AudioEffectLowPassFilter).cutoff_hz = _cutoff


func _apply_volumes() -> void:
	for sync in _syncs:
		for k in STEMS.size():
			if sync.get_sync_stream(k) != null:
				sync.set_sync_stream_volume(k, float(_vol.get(STEMS[k], OFF)))
