extends TestCase
## PlayerInput (one tick of intent) and PlayerMotor (the walk and dash maths the host's
## ally keeper and the guest's predictor share).

const DT := 1.0 / 60.0


func test_input_buttons_round_trip() -> void:
	var bits := NetProtocol.BTN_ATTACK | NetProtocol.BTN_DASH | NetProtocol.BTN_HELD
	var i := PlayerInput.from_buttons(Vector2(1, 0), 0.0, bits)
	assert_true(i.attack_pressed)
	assert_true(i.dash_pressed)
	assert_true(i.attack_held)
	assert_true(not i.special_pressed)
	assert_eq(i.to_buttons(), bits)
	i.consume_edges()
	assert_true(not i.attack_pressed and not i.dash_pressed, "edges are one-tick")
	assert_true(i.attack_held, "held survives")
	assert_eq(i.to_buttons(), NetProtocol.BTN_HELD)


func test_walk_speed() -> void:
	assert_eq(PlayerMotor.walk_velocity(Vector2(1, 0), Player.SPEED), Vector2(Player.SPEED, 0))


func test_dash_direction_falls_back_to_facing() -> void:
	assert_eq(PlayerMotor.dash_direction(Vector2.ZERO, Vector2.LEFT), Vector2.LEFT)
	assert_near(PlayerMotor.dash_direction(Vector2(3, 0), Vector2.LEFT).x, 1.0)


func test_dash_distance_and_charge() -> void:
	var st := PlayerMotor.State.new()
	var inp := PlayerInput.from_buttons(Vector2(1, 0), 0.0, NetProtocol.BTN_DASH)
	PlayerMotor.step(st, inp, Player.SPEED, DT)
	assert_eq(st.charges, Player.DASH_CHARGES - 1, "a dash costs a charge")
	inp.consume_edges()
	var total := 0.0
	for i in 20:
		var v := PlayerMotor.step(st, inp, Player.SPEED, DT)
		if st.dash_t > 0.0 or v.length() > Player.SPEED + 1.0:
			total += v.x * DT
	assert_true(absf(total - Player.DASH_DISTANCE) <= 6.0, "dashed %f px" % total)


func test_no_dash_without_charges() -> void:
	var st := PlayerMotor.State.new()
	st.charges = 0
	var inp := PlayerInput.from_buttons(Vector2(1, 0), 0.0, NetProtocol.BTN_DASH)
	PlayerMotor.step(st, inp, Player.SPEED, DT)
	assert_eq(st.dash_t, 0.0)
	assert_eq(st.charges, 0)


func test_charges_recharge() -> void:
	var st := PlayerMotor.State.new()
	st.charges = Player.DASH_CHARGES - 1
	var idle := PlayerInput.new()
	for i in int(Player.DASH_RECHARGE / DT) + 2:
		PlayerMotor.step(st, idle, Player.SPEED, DT)
	assert_eq(st.charges, Player.DASH_CHARGES)


func test_player_reads_net_input_not_devices() -> void:
	var p := Player.new()
	p.net_input = PlayerInput.from_buttons(Vector2(0, 1), PI / 2.0, NetProtocol.BTN_ATTACK)
	var i := p._intent()
	assert_eq(i, p.net_input)
	assert_near(i.move.y, 1.0, 0.01)
	assert_near(p.aim.y, 1.0, 0.05, "aim follows the wire")
	p.free()
