class_name InterpBuffer
extends RefCounted
## Timestamped samples of one remote entity. Rendering lags the newest sample by DELAY_MS so
## there is almost always a sample on each side; past the newest it extrapolates briefly, then holds.

const DELAY_MS := 100
const EXTRAP_CAP_MS := 100
const MAX_SAMPLES := 32

var underruns: int = 0
var _s: Array = []  # {t, pos, anim, hp}


func push(t_ms: int, pos: Vector2, anim: int, hp: int) -> void:
	if not _s.is_empty() and t_ms <= int(_s[-1].t):
		return  # late or duplicate: the newer sample already says more
	_s.append({"t": t_ms, "pos": pos, "anim": anim, "hp": hp})
	if _s.size() > MAX_SAMPLES:
		_s.pop_front()


func sample(render_t_ms: int) -> Dictionary:
	if _s.is_empty():
		return {"valid": false, "pos": Vector2.ZERO, "anim": 0, "hp": 0, "extrapolated": false}
	var last: Dictionary = _s[-1]
	if render_t_ms >= int(last.t):
		var ex := false
		var pos: Vector2 = last.pos
		if render_t_ms > int(last.t):
			ex = true
			underruns += 1
			if _s.size() >= 2:
				var prev: Dictionary = _s[-2]
				var vel: Vector2 = (last.pos - prev.pos) / float(int(last.t) - int(prev.t))
				pos = last.pos + vel * float(mini(render_t_ms - int(last.t), EXTRAP_CAP_MS))
		return {"valid": true, "pos": pos, "anim": last.anim, "hp": last.hp, "extrapolated": ex}
	if render_t_ms <= int(_s[0].t):
		var f: Dictionary = _s[0]
		return {"valid": true, "pos": f.pos, "anim": f.anim, "hp": f.hp, "extrapolated": false}
	for i in range(_s.size() - 1):
		var a: Dictionary = _s[i]
		var b: Dictionary = _s[i + 1]
		if render_t_ms >= int(a.t) and render_t_ms <= int(b.t):
			var k := float(render_t_ms - int(a.t)) / float(int(b.t) - int(a.t))
			return {"valid": true, "pos": a.pos.lerp(b.pos, k), "anim": a.anim, "hp": a.hp, "extrapolated": false}
	return {"valid": true, "pos": last.pos, "anim": last.anim, "hp": last.hp, "extrapolated": false}
