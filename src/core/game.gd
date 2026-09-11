extends Node
## Top-level game flow: Hub -> Run -> Results -> Hub. Owns the run seed.

const VERSION := "1.0.0"
const HUB_SCENE := "res://src/hub/hub.tscn"
const RUN_SCENE := "res://src/run/run.tscn"
const TITLE_SCENE := "res://src/title/title.tscn"

enum State { BOOT, HUB, RUN, RESULTS }

var state: State = State.BOOT
var run_seed: int = 0
var last_result: Dictionary = {}
## True while the last input came from a pad: prompts and aiming follow it.
var gamepad: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("EBB %s | Godot %s" % [VERSION, Engine.get_version_info().string])


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


func go_to_run(seed_override: int = 0) -> void:
	run_seed = seed_override if seed_override != 0 else randi()
	state = State.RUN
	get_tree().call_deferred("change_scene_to_file", RUN_SCENE)


func run_finished(result: Dictionary) -> void:
	state = State.RESULTS
	last_result = result
	SaveManager.record_run(result)
	EventBus.run_ended.emit(result)
