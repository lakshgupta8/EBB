class_name PlayerMotor
extends RefCounted
## The walk-and-dash maths, shared by `Player` (host, local and ally keepers) and the guest's
## predictor so both sides agree to the pixel. Pure: `step` returns the velocity and the
## caller moves the body (move_and_slide), so it is testable without a physics frame.

class State:
	var dash_t: float = 0.0
	var dash_dir: Vector2 = Vector2.ZERO
	var charges: int = Player.DASH_CHARGES
	var max_charges: int = Player.DASH_CHARGES
	var recharge_t: float = 0.0
	var facing: Vector2 = Vector2.RIGHT


static func walk_velocity(move: Vector2, speed: float) -> Vector2:
	return move * speed


static func dash_velocity(dir: Vector2, dist_mult: float = 1.0) -> Vector2:
	return dir * (Player.DASH_DISTANCE * dist_mult / Player.DASH_TIME)


static func dash_direction(move: Vector2, facing: Vector2) -> Vector2:
	return move.normalized() if move != Vector2.ZERO else facing


## One physics tick for a predicted keeper: walk, start a dash, run a dash, recharge.
static func step(st: State, inp: PlayerInput, speed: float, delta: float, dist_mult: float = 1.0) -> Vector2:
	var v: Vector2
	if st.dash_t > 0.0:
		st.dash_t -= delta
		v = dash_velocity(st.dash_dir, dist_mult)
	else:
		v = walk_velocity(inp.move, speed)
		if inp.move != Vector2.ZERO:
			st.facing = inp.move.normalized()
		if inp.dash_pressed and st.charges > 0:
			st.charges -= 1
			st.dash_t = Player.DASH_TIME
			st.dash_dir = dash_direction(inp.move, st.facing)
	if st.charges >= st.max_charges:
		st.recharge_t = 0.0
	else:
		st.recharge_t += delta
		if st.recharge_t >= Player.DASH_RECHARGE:
			st.recharge_t -= Player.DASH_RECHARGE
			st.charges += 1
	return v
