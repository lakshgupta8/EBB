class_name ClientView
extends Node2D
## The guest's whole game: no run, no enemies' brains. It builds the room the host names from
## its text, predicts the guest's own keeper (walk, dash, walls), and shows everything else as
## puppets fed by snapshots, with hits, deaths and room events arriving as reliable messages.

const MP_MENU := "res://src/multiplayer/mp_menu.tscn"
const TICK_MS := 1000.0 / 60.0

## A bot's hands: when set, it supplies each tick's PlayerInput instead of the devices.
var bot: Callable = Callable()
## The scene was told the session ended (bots listen; a player is sent back to the menu).
signal session_ended(reason: String)
var rooms_entered: int = 0
## A duel freezes both keepers during the countdown.
var frozen: bool = false
var pvp_states: int = 0
var _underruns_seen: int = 0
var pvp_match_over: bool = false
var pvp_wins: Vector2 = Vector2.ZERO
var snapshots: int = 0
var snaps: int = 0
var max_error: float = 0.0

var epoch: int = -1
var entities: Node2D
var puppets: Dictionary = {}  # net id -> Puppet
var room: Room
var local: CharacterBody2D
var history := InputHistory.new()

var _room_holder: Node2D
var _motor := PlayerMotor.State.new()
var _seq: int = 0
var _srv_t: float = -1.0   # the host's clock as best we know it, ms
var _last_tick: int = -1
var _hp: Dictionary = {}
var _tide: float = 0.0
var _hud: Label
var _toast: Label
var _toast_t: float = 0.0


func _ready() -> void:
	_room_holder = Node2D.new()
	add_child(_room_holder)
	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)
	local = _make_local()
	entities.add_child(local)
	var cam := GameCamera.new()
	add_child(cam)
	cam.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = UI.label("", 8, UI.PRIMARY)
	_hud.position = Vector2(8, 6)
	layer.add_child(_hud)
	_toast = UI.label("", 8, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_toast.position = Vector2(120, 40)
	_toast.size = Vector2(400, 12)
	layer.add_child(_toast)
	Net.message.connect(_on_message)
	Net.left.connect(_on_left)
	Net.send_reliable(NetProtocol.encode_resync())  # in case the room was announced before this scene was up
	_say("waiting for the host's room")


func _exit_tree() -> void:
	for pair in [[Net.message, _on_message], [Net.left, _on_left]]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])


func _make_local() -> CharacterBody2D:
	var b := CharacterBody2D.new()
	b.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	b.collision_layer = 2
	b.collision_mask = 1
	b.add_to_group("player")
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(8, 6)
	cs.shape = shape
	b.add_child(cs)
	var sp := AnimatedSprite2D.new()
	sp.name = "Sprite"
	sp.sprite_frames = SheetFrames.build(Puppet.SHEET, 24, Player.ANIMS)
	sp.position = Vector2(0, -9)
	sp.modulate = CoopHost.GUEST_TINT
	sp.play("idle")
	b.add_child(sp)
	return b


# --- the guest's own keeper: predict, send, reconcile ------------------------------------------

func _physics_process(delta: float) -> void:
	if room == null:
		return
	if _srv_t >= 0.0:
		_srv_t += delta * 1000.0
	var inp := _gather()
	var frame := {"seq": _seq & 0xFFFF, "move": inp.move, "aim": wrapf(inp.aim.angle(), 0.0, TAU), "buttons": inp.to_buttons()}
	_seq += 1
	history.push(frame)
	var speed := Player.SPEED * (0.7 if room.is_flooded_at(local.global_position) else 1.0)
	local.velocity = PlayerMotor.step(_motor, inp, speed, delta)
	local.move_and_slide()
	_animate_local(inp)
	Net.send_unreliable(NetProtocol.encode_inputs(history.last_three()))
	var render_t := int(_srv_t) - InterpBuffer.DELAY_MS
	var under := 0
	for p in puppets.values():
		p.apply(render_t)
		under += p.buffer.underruns
	var st := _stats()
	if st != null:
		for i in maxi(0, under - _underruns_seen):
			st.record_underrun()
	_underruns_seen = under
	_refresh_hud()


func _gather() -> PlayerInput:
	if frozen:
		return PlayerInput.new()
	if bot.is_valid():
		return bot.call(self)
	var i := PlayerInput.new()
	i.move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > 0.35:
		i.aim = stick.normalized()
	elif Game.gamepad and i.move != Vector2.ZERO:
		i.aim = i.move.normalized()
	else:
		var to := get_global_mouse_position() - local.global_position
		i.aim = to.normalized() if to.length() > 0.5 else Vector2.RIGHT
	i.attack_held = Input.is_action_pressed("attack")
	i.attack_pressed = Input.is_action_just_pressed("attack")
	i.special_pressed = Input.is_action_just_pressed("special")
	i.dash_pressed = Input.is_action_just_pressed("dash")
	i.use_pressed = Input.is_action_just_pressed("use_item")
	return i


func _animate_local(inp: PlayerInput) -> void:
	var sp: AnimatedSprite2D = local.get_node("Sprite")
	var nm := "dash" if _motor.dash_t > 0.0 else ("walk" if inp.move != Vector2.ZERO else "idle")
	if String(sp.animation) != nm:
		sp.play(nm)


## Replay the inputs the host has not seen onto where it says we were. Walking is replayed;
## during a dash we trust the local body unless the two are far apart.
func _reconcile(e: Dictionary, ack: int) -> void:
	if local == null or room == null:
		return
	var step := func(pos: Vector2, f: Dictionary) -> Vector2:
		return pos + PlayerMotor.walk_velocity(f.move, Player.SPEED) / 60.0
	var r := Prediction.reconcile(e.pos, ack, history, local.global_position, step)
	var st := _stats()
	max_error = maxf(max_error, float(r.error))
	if bool(r.snapped):
		snaps += 1
	if st != null and float(r.error) > 0.0:
		st.record_correction(float(r.error))
	if bool(r.snapped) or _motor.dash_t <= 0.0:
		local.global_position = r.pos


# --- messages ------------------------------------------------------------------------------------

func _on_message(type: int, bytes: PackedByteArray) -> void:
	match type:
		NetProtocol.Msg.ROOM_ENTER:
			var d := NetProtocol.decode_room_enter(bytes)
			if not d.is_empty():
				handle_room_enter(d)
		NetProtocol.Msg.SNAPSHOT:
			var d := NetProtocol.decode_snapshot(bytes)
			if not d.is_empty():
				handle_snapshot(d)
		NetProtocol.Msg.SPAWN:
			var d := NetProtocol.decode_spawn(bytes)
			if not d.is_empty():
				handle_spawn(d)
		NetProtocol.Msg.DESPAWN:
			var d := NetProtocol.decode_despawn(bytes)
			if not d.is_empty():
				handle_despawn(d)
		NetProtocol.Msg.EVENT:
			var d := NetProtocol.decode_event(bytes)
			if not d.is_empty():
				handle_event(d)


func _on_left(reason: String) -> void:
	session_ended.emit(reason)
	if not bot.is_valid():
		get_tree().call_deferred("change_scene_to_file", MP_MENU)


func handle_room_enter(d: Dictionary) -> void:
	if int(d.epoch) == epoch and room != null:
		return  # a repeat of the room we are already in (the answer to our RESYNC)
	rooms_entered += 1
	epoch = int(d.epoch)
	_clear_puppets()
	if room != null:
		room.queue_free()
	room = Room.new()
	_room_holder.add_child(room)
	var t := RoomTemplate.parse(str(d.text), str(d.name))
	var biome := clampi(int(d.biome), 0, Run.BIOMES.size() - 1)
	room.build(t, int(d.room_seed), int(Run.BIOMES[biome].theme))
	local.global_position = room.cell_to_world(t.player_spawn) + Vector2(14, 6)
	local.velocity = Vector2.ZERO
	history = InputHistory.new()
	_srv_t = -1.0
	_last_tick = -1
	_toast.text = ""


func handle_snapshot(d: Dictionary) -> void:
	if int(d.epoch) != epoch:
		return  # from the room before this one
	snapshots += 1
	var tick := int(d.tick)
	var latest := float(tick) * TICK_MS
	if _srv_t < 0.0 or absf(latest - _srv_t) > 500.0:
		_srv_t = latest
	else:
		_srv_t += (latest - _srv_t) * 0.1
	var st := _stats()
	if st != null:
		st.record_snapshot()
		if _last_tick >= 0 and tick > _last_tick + 3:
			st.record_lost((tick - _last_tick) / 3 - 1)
	if tick < _last_tick:
		return
	_last_tick = tick
	for e in d.entities:
		var id := int(e.id)
		_hp[id] = int(e.hp)
		if id == NetReplicator.TIDE_ID:
			_tide = float(e.hp) / 100.0
			if room != null:
				room.set_tide(_tide)
		elif id == NetReplicator.GUEST_ID:
			_reconcile(e, int(d.ack))
		else:
			if id == NetReplicator.HOST_ID and not puppets.has(id):
				_add_puppet(id, NetReplicator.Kind.PLAYER_HOST, "", e.pos)
			var p: Puppet = puppets.get(id)
			if p != null:
				p.buffer.push(int(latest), e.pos, int(e.anim), int(e.hp))


func handle_spawn(d: Dictionary) -> void:
	var id := int(d.id)
	if not puppets.has(id):
		_add_puppet(id, int(d.kind), str(d.scene_key), d.pos)


func handle_despawn(d: Dictionary) -> void:
	var p: Puppet = puppets.get(int(d.id))
	if p == null:
		return
	puppets.erase(int(d.id))
	_dispose(p)


func handle_event(d: Dictionary) -> void:
	var pos: Vector2 = d.pos
	match int(d.kind):
		NetProtocol.Ev.HIT:
			var p: Puppet = puppets.get(int(d.a))
			if p != null:
				p.flash()
			elif int(d.a) == NetReplicator.GUEST_ID and local != null:
				(local.get_node("Sprite") as AnimatedSprite2D).modulate = Color(2, 2, 2)
				get_tree().create_timer(0.1).timeout.connect(func():
					if is_instance_valid(local):
						(local.get_node("Sprite") as AnimatedSprite2D).modulate = CoopHost.GUEST_TINT)
			FX.text(pos + Vector2(0, -14), str(int(d.b)), Color(1.0, 0.95, 0.85))
		NetProtocol.Ev.DEATH:
			FX.burst(pos, Color(0.85, 0.8, 0.75), 10, 50.0)
		NetProtocol.Ev.TELEGRAPH:
			var p: Puppet = puppets.get(int(d.a))
			if p != null:
				p.flash()
				FX.ring(pos + Vector2(0, -8), Palette.SALT_RED, 0.5)
				var tell = Enemy.VOICES.get(p.scene_key.get_file(), {}).get("tells", {}).get(&"windup", "")
				if str(tell) != "":
					Audio.play(str(tell))
		NetProtocol.Ev.BOSS_PHASE:
			var p: Puppet = puppets.get(int(d.a))
			if p != null:
				p.flash()
				FX.ring(pos + Vector2(0, -12), Palette.WARM_YELLOW, 2.0)
				FX.flash_screen(Color(1.0, 0.9, 0.7, 0.35), 0.4)
		NetProtocol.Ev.DOWNED:
			_say("a keeper has fallen")
		NetProtocol.Ev.REVIVED:
			_say("a keeper stands again")
		NetProtocol.Ev.ROUND_RESULT:
			_say("the night is won" if int(d.a) == 1 else "the night is over")
			get_tree().create_timer(4.0).timeout.connect(func():
				if not bot.is_valid() and Net.state != NetSession.State.IDLE:
					Net.return_to_lobby()
					get_tree().change_scene_to_file(MP_MENU))
		NetProtocol.Ev.PVP_STATE:
			_on_pvp_state(int(d.a), int(d.b), pos)
		NetProtocol.Ev.CLEARED:
			if room != null:
				room.open_doors()
			_say("the doors are open")


## A duel's phases (PvpArena.Phase): the host says when to count down, fight, and who won.
func _on_pvp_state(phase: int, b: int, wins: Vector2) -> void:
	pvp_wins = wins
	pvp_states += 1
	match phase:
		PvpArena.Phase.COUNTDOWN:
			frozen = true
			_say("round %d: get ready" % b)
		PvpArena.Phase.FIGHT:
			frozen = false
			_say("FIGHT")
		PvpArena.Phase.ROUND_OVER:
			frozen = true
			_say("a draw" if b == 2 else ("you take the round" if b == 1 else "they take the round"))
		PvpArena.Phase.MATCH_OVER:
			frozen = true
			pvp_match_over = true
			_say("you win the duel" if b == 1 else "they win the duel")
			get_tree().create_timer(4.0).timeout.connect(func():
				if not bot.is_valid() and Net.state != NetSession.State.IDLE:
					Net.return_to_lobby()
					get_tree().change_scene_to_file(MP_MENU))


# --- helpers -------------------------------------------------------------------------------------

func _add_puppet(id: int, kind: int, scene_key: String, at: Vector2) -> void:
	var p := Puppet.make(id, kind, scene_key, at)
	entities.add_child(p)
	puppets[id] = p


func _dispose(p: Node) -> void:
	if p.is_inside_tree():
		p.queue_free()
	else:
		p.free()


func _clear_puppets() -> void:
	for p in puppets.values():
		_dispose(p)
	puppets.clear()


func _stats() -> NetStats:
	return Net.transport.stats if Net.transport != null else null


func _say(text: String) -> void:
	if _toast != null:
		_toast.text = text
		_toast_t = 2.5


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0 and _toast != null:
			_toast.text = ""


func _refresh_hud() -> void:
	if _hud != null:
		_hud.text = "you %d   keeper %d   tide %d%%   link %d ms" % [int(_hp.get(NetReplicator.GUEST_ID, 0)),
				int(_hp.get(NetReplicator.HOST_ID, 0)), int(_tide / maxf(TideSystem.MAX_LEVEL, 1.0) * 100.0), int(Net.rtt_ms)]
