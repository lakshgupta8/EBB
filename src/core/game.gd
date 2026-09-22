extends Node
## Top-level game flow: Hub -> Run -> Results -> Hub. Owns the run seed.

const VERSION := "1.2.0"
const HUB_SCENE := "res://src/hub/hub.tscn"
const RUN_SCENE := "res://src/run/run.tscn"
const TITLE_SCENE := "res://src/title/title.tscn"

enum State { BOOT, HUB, RUN, RESULTS }

var state: State = State.BOOT
var run_seed: int = 0
## M8: the way down: "night" (from the shore), or daily / seeded / trial / neap / riptide.
var mode: String = "night"
var last_result: Dictionary = {}
## True while the last input came from a pad: prompts and aiming follow it.
var gamepad: bool = false
## A rested night lifted out of the profile, waiting for the run scene to pick it up.
var resume: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("EBB %s | Godot %s" % [VERSION, Engine.get_version_info().string])
	_set_cursor()
	get_tree().root.size_changed.connect(_set_cursor)


## The pointer: an 8 px Salt white arrow with an Ink outline, a small hook over anything
## clickable (art Stage 16, STYLE.md 15). The cursor is not on the canvas, so it is grown by
## the window's integer scale to stay the same size as the game's pixels.
func _set_cursor() -> void:
	var tex := load("res://assets/sprites/cursor.png") as Texture2D
	if tex == null:
		return
	var img := tex.get_image()
	var s := maxi(1, int(floor(minf(get_tree().root.size.x / 640.0, get_tree().root.size.y / 360.0))))
	var arrow := img.get_region(Rect2i(0, 0, 8, 8))
	var hook := img.get_region(Rect2i(8, 0, 8, 8))
	arrow.resize(8 * s, 8 * s, Image.INTERPOLATE_NEAREST)
	hook.resize(8 * s, 8 * s, Image.INTERPOLATE_NEAREST)
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(arrow), Input.CURSOR_ARROW, Vector2(0, 0))
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(hook), Input.CURSOR_POINTING_HAND, Vector2(2 * s, 1 * s))


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		toggle_fullscreen()
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton \
			or (event is InputEventMouseMotion and event.relative.length() > 3.0):
		gamepad = false


func toggle_fullscreen() -> void:
	Settings.set_value("fullscreen", not bool(Settings.value("fullscreen")))


func go_to_title() -> void:
	state = State.BOOT
	get_tree().call_deferred("change_scene_to_file", TITLE_SCENE)


## The weapon the next run starts with (chosen at Bram's forge, else the gaff).
func weapon_id() -> String:
	var w := str(SaveManager.data.get("weapon", Weapon.DEFAULT))
	return w if Weapon.ALL.has(w) else Weapon.DEFAULT


func go_to_hub() -> void:
	state = State.HUB
	get_tree().call_deferred("change_scene_to_file", HUB_SCENE)


func go_to_run(seed_override: int = 0, p_mode: String = "night") -> void:
	run_seed = seed_override if seed_override != 0 else randi()
	mode = p_mode
	state = State.RUN
	get_tree().call_deferred("change_scene_to_file", RUN_SCENE)


## A night rested at a cleared room is waiting at the shore.
func has_suspended() -> bool:
	var s = SaveManager.data.get("suspended", {})
	return s is Dictionary and not s.is_empty()


## Move the rested night from the profile into `resume`. It can only be continued once:
## whatever happens next is what happened.
func load_suspended() -> bool:
	if not has_suspended():
		return false
	resume = SaveManager.data["suspended"]
	SaveManager.data["suspended"] = {}
	SaveManager.save_profile()
	run_seed = int(resume.get("seed", 0))
	mode = str(resume.get("mode", "night"))
	return true


func continue_run() -> void:
	if not load_suspended():
		go_to_run()
		return
	state = State.RUN
	get_tree().call_deferred("change_scene_to_file", RUN_SCENE)


## The run scene takes the rested night (empty when this is a fresh descent).
func take_resume() -> Dictionary:
	var r := resume
	resume = {}
	return r


func run_finished(result: Dictionary) -> void:
	state = State.RESULTS
	last_result = result
	SaveManager.record_run(result)
	mode = "night"
	EventBus.run_ended.emit(result)
