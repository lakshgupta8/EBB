extends Node
## Top-level game state. Owns the Hub -> Run -> Results flow and the run RNG.

const VERSION := "0.0.1"

enum State { BOOT, HUB, RUN, RESULTS }

var state: State = State.BOOT
var rng := RandomNumberGenerator.new()
var run_seed: int = 0


func _ready() -> void:
	print("EBB %s | Godot %s" % [VERSION, Engine.get_version_info().string])


func start_run(seed_override: int = 0) -> void:
	run_seed = seed_override if seed_override != 0 else randi()
	rng.seed = run_seed
	state = State.RUN
	EventBus.run_started.emit(run_seed)


func end_run(result: Dictionary) -> void:
	state = State.RESULTS
	EventBus.run_ended.emit(result)
