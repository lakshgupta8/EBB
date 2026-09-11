extends Node
## Game-feel helpers that need to outlive the thing that asked for them: hitstop.
## Screen shake lives on the camera and listens to EventBus.request_shake.

const STOP_SCALE := 0.05

var _stopping := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.request_hitstop.connect(hitstop)


func hitstop(duration: float) -> void:
	if _stopping or duration <= 0.0:
		return
	_stopping = true
	Engine.time_scale = STOP_SCALE
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_stopping = false


## Brief slow motion (riptide). Overrides hitstop if one is running.
func slowmo(scale: float, duration: float) -> void:
	_stopping = true
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_stopping = false
