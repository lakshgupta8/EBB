extends Enemy
## Polyp Swarm (the Reef, map Stage 11h): a clutch of polyps grown out of the living coral. It
## does not walk. It opens its crowns and puffs a fan of stinging spores; close on it and it
## goes down into its coral and comes up on another living patch further off (anywhere open if
## the room has none). While under it cannot be hurt, so catch it with its crowns open.

const SHEET := preload("res://assets/sprites/polyp_swarm.png")
const SPORE := preload("res://assets/sprites/polyp_spore.png")
const NOTICE := 800.0
const CAST_EVERY := 2.4
const WINDUP := 0.55
const SPORES := 3
const FAN := 0.42            # radians between spores
const SPORE_SPEED := 95.0
const SPORE_DAMAGE := 5
const CROWD := 46.0          # this close for CROWD_TIME and it goes under
const CROWD_TIME := 0.6
const SINK_TIME := 0.5
const RISE_TIME := 0.4
const SINK_COOLDOWN := 3.0
const NEW_PLACE := Vector2(90.0, 210.0)  # how far from the keeper it comes up

var _cast_t: float = 0.0
var _crowd_t: float = 0.0
var _sink_cool: float = 0.0


func _setup_animations() -> void:
	sprite.sprite_frames = SheetFrames.build(SHEET, 24, anims(
		{"idle": "idle", "under": "walk", "windup": "windup", "puff": "attack", "hurt": "hurt"}, {"idle": 3, "under": 8}))
	_cast_t = randf_range(0.6, 1.8)
	var glow := Atmosphere.light(self, Atmosphere.COLD, 1.0, 0.35, Vector2(0, -8))
	Atmosphere.breathe(glow, 0.6, 1.0, 2.2)


func _enter_state(s: StringName) -> void:
	match s:
		&"idle", &"watch":
			play("idle")
			velocity = Vector2.ZERO
		&"windup":
			play("windup")
		&"puff":
			play("puff")
			_puff()
		&"sink":
			play("under")
			health.invulnerable = true
			FX.burst(global_position, Color(0.75, 0.6, 0.9, 0.8), 5, 30.0)
		&"rise":
			play("under")
			sprite.frame = 2
			_move_to_new_place()
			FX.burst(global_position, Color(0.75, 0.6, 0.9, 0.8), 5, 30.0)


func _exit_state(s: StringName) -> void:
	if s == &"rise":
		health.invulnerable = false
		_sink_cool = SINK_COOLDOWN


func _tick(delta: float) -> void:
	velocity = Vector2.ZERO
	_sink_cool = maxf(0.0, _sink_cool - delta)
	var d := to_player()
	var dist := d.length() if d != Vector2.ZERO else INF
	match state:
		&"idle":
			if dist < NOTICE:
				change_state(&"watch")
		&"watch":
			face(d.x)
			_crowd_t = _crowd_t + delta if dist < CROWD else 0.0
			if _crowd_t >= CROWD_TIME and _sink_cool <= 0.0:
				_crowd_t = 0.0
				change_state(&"sink")
				return
			_cast_t += delta
			if _cast_t >= CAST_EVERY and dist < 240.0:
				_cast_t = 0.0
				change_state(&"windup")
		&"windup":
			face(d.x)
			if state_t >= WINDUP - STRIKE_CUE_LEAD:
				strike_cue()
			if state_t >= WINDUP:
				change_state(&"puff")
		&"puff":
			if state_t >= 0.3:
				change_state(&"watch")
		&"sink":
			if state_t >= SINK_TIME:
				change_state(&"rise")
		&"rise":
			if state_t >= RISE_TIME:
				change_state(&"watch")


func _puff() -> void:
	var d := to_player()
	var aim := d.normalized() if d != Vector2.ZERO else Vector2.RIGHT
	for i in SPORES:
		var dir := aim.rotated((i - (SPORES - 1) / 2.0) * FAN)
		var p := Projectile.spawn(get_parent(), global_position + Vector2(0, -12) + dir * 6.0,
			dir * SPORE_SPEED, SPORE_DAMAGE, SPORE, self, 64, 2.4)
		p.knockback = 40.0
	FX.burst(global_position + Vector2(0, -12), Color(0.7, 0.85, 0.95), 6, 35.0)
	Audio.play("lantern", 0.15, -9.0)


## Up again on living coral (the Reef's first patch) at a fair distance from the keeper; any
## open floor will do in a room without it. Never in a wall, never on top of the keeper.
func _move_to_new_place() -> void:
	if room == null:
		return
	var t := room.template
	var me := player.global_position if player else global_position
	var best: Array[Vector2i] = []
	var open: Array[Vector2i] = []
	for y in range(1, t.height - 1):
		for x in range(1, t.width - 1):
			if t.is_solid(x, y) or t.char_at(x, y) == "D":
				continue
			var c := Vector2i(x, y)
			var dist := room.cell_to_world(c).distance_to(me)
			if dist < NEW_PLACE.x or dist > NEW_PLACE.y:
				continue
			open.append(c)
			if int(room.patches.get(c, -1)) == 0:
				best.append(c)
	var pool := best if best.size() > 0 else open
	if pool.is_empty():
		return
	global_position = room.cell_to_world(pool[randi() % pool.size()])


func _on_hurt_extra(_info: DamageInfo) -> void:
	if state == &"watch" or state == &"idle":
		play("hurt")
		stunned = 0.1
