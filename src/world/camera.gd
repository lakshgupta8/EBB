class_name GameCamera
extends Camera2D
## Trauma-based screen shake. Ask for shake through EventBus.request_shake(strength 0..1).

const MAX_OFFSET := 6.0
const DECAY := 2.2

var _trauma: float = 0.0
var _noise := FastNoiseLite.new()
var _t: float = 0.0


func _ready() -> void:
	_noise.seed = 7
	_noise.frequency = 1.0
	EventBus.request_shake.connect(add_trauma)


func add_trauma(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)


func _process(delta: float) -> void:
	if _trauma <= 0.0:
		offset = Vector2.ZERO
		return
	_t += delta * 60.0
	_trauma = maxf(0.0, _trauma - DECAY * delta)
	var s := _trauma * _trauma
	offset = Vector2(
		_noise.get_noise_2d(_t, 0.0) * MAX_OFFSET * s,
		_noise.get_noise_2d(0.0, _t) * MAX_OFFSET * s,
	).round()
