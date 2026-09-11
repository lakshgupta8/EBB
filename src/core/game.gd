extends Node
## Top-level game flow: Hub -> Run -> Results -> Hub. Owns the run seed.

const VERSION := "0.2.0"
const HUB_SCENE := "res://src/hub/hub.tscn"
const RUN_SCENE := "res://src/run/run.tscn"

enum State { BOOT, HUB, RUN, RESULTS }

var state: State = State.BOOT
var run_seed: int = 0
var last_result: Dictionary = {}


func _ready() -> void:
	print("EBB %s | Godot %s" % [VERSION, Engine.get_version_info().string])


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
