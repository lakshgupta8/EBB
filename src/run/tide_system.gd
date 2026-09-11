class_name TideSystem
extends RefCounted
## The run clock. Level rises slowly with time and jumps on each new room. Tiles with
## height < level are flooded; height + 1 < level is deep. Pure logic, testable.

## Tuning target: a 10-minute biome-1 run (9 rooms) reaches ~2.0 at the boss, so sand
## is shallow by mid-run and only turns deep if you dawdle through the boss.
const RATE := 0.0015       # per second  (600 s -> 0.9)
const ROOM_STEP := 0.16    # per room entered (9 rooms -> 1.44): sand is shallow by room 7
const MAX_LEVEL := 4.0
const DEEP_DAMAGE := 1     # per tick to the player
const DEEP_TICK := 0.5     # seconds

var level: float = 0.0
var rate_mult: float = 1.0  # tidemarks / ledger can slow it
var pause_t: float = 0.0    # Still Water: seconds the tide holds


func advance(delta: float) -> void:
	if pause_t > 0.0:
		var held := minf(delta, pause_t)
		pause_t -= held
		delta -= held
		if delta <= 0.0:
			return
	level = minf(MAX_LEVEL, level + RATE * rate_mult * delta)


func pause(seconds: float) -> void:
	pause_t = maxf(pause_t, seconds)


func room_entered() -> void:
	level = minf(MAX_LEVEL, level + ROOM_STEP * rate_mult)


func is_flooded(h: int) -> bool:
	return level > h


func is_deep(h: int) -> bool:
	return level > h + 1.0


## 0..1 for HUD.
func fraction() -> float:
	return level / MAX_LEVEL
