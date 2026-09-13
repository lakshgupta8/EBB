extends Node
## Game-feel helpers that need to outlive the thing that asked for them: hitstop.
## Screen shake lives on the camera and listens to EventBus.request_shake.

const STOP_SCALE := 0.05

## The clock's normal speed. Bots run the night faster (sim_run --fast=N) by raising this
## together with the physics rate, so every hitstop and slowmo scales from it.
var base: float = 1.0
var _stopping := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.request_hitstop.connect(hitstop)


func hitstop(duration: float) -> void:
	if _stopping or duration <= 0.0:
		return
	_stopping = true
	Engine.time_scale = STOP_SCALE * base
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = base
	_stopping = false


## Brief slow motion (riptide). Overrides hitstop if one is running. Reduced motion skips it.
func slowmo(scale: float, duration: float) -> void:
	if Settings.reduced_motion():
		return
	_stopping = true
	Engine.time_scale = scale * base
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = base
	_stopping = false
