class_name HarpoonGun
extends Weapon
## Bram's second work. Slow, long, and it never lets go.
##   LMB           fire a piercing bolt (three in the gun, then a reload). Hold to keep firing.
##   dash + LMB    a snap shot straight out of the dash, no gap.
##   RMB           tethered harpoon: the first enemy it finds is tied to you for a while.
##                 Every dash you make drags it along with you. Bosses barely budge.

const MAG := 3
const RELOAD := 1.1
const SHOT_GAP := 0.28
const BOLT_SPEED := 520.0
const BOLT_DAMAGE := 8
const BOLT_RANGE := 7.0 * 16.0
const BOLT_KNOCKBACK := 70.0
const BOLT_TEX := preload("res://assets/sprites/harpoon_bolt.png")
const TETHER_RANGE := 6.0 * 16.0
const TETHER_TIME := 4.0
const TETHER_COOLDOWN := 5.0
const TETHER_MISS_COOLDOWN := 1.5
const TETHER_DAMAGE := 4
const TETHER_DRAG := 48.0

var ammo: int = MAG
var _reload_t: float = 0.0
var _gap_t: float = 0.0
var _held: bool = false
var _tether_cd: float = 0.0
var _tether_cd_total: float = TETHER_COOLDOWN
var _tethered: Enemy
var _tether_t: float = 0.0
var _player: Player

@onready var pivot: Node2D = $Pivot
@onready var sprite: Sprite2D = $Pivot/Sprite
@onready var line: Line2D = $Line


func _ready() -> void:
	id = "harpoon"
	_player = get_parent() as Player
	line.visible = false


func move_mult() -> float:
	return 0.6 if _gap_t > 0.0 else 1.0


func special_ready() -> bool:
	return _tether_cd <= 0.0


func special_cooldown_fraction() -> float:
	return clampf(1.0 - _tether_cd / _tether_cd_total, 0.0, 1.0)


func ammo_text() -> String:
	if _reload_t > 0.0:
		return "reloading"
	return "%d/%d" % [ammo, MAG]


func try_attack() -> void:
	if _reload_t > 0.0:
		return
	if ammo <= 0:
		_start_reload()
	elif _gap_t <= 0.0:
		_fire(false)


func set_held(held: bool) -> void:
	_held = held


func try_lunge() -> void:
	if _reload_t <= 0.0 and ammo > 0:
		_fire(true)


func try_special() -> void:
	if special_ready():
		_throw_tether()


## The tethered enemy comes along for every dash.
func on_dash(dir: Vector2) -> void:
	if _tethered == null or not is_instance_valid(_tethered) or not _tethered.health.is_alive():
		return
	var give := 1.0 - _tethered.knockback_resist * 0.8
	_tethered.pull_to(_tethered.global_position + dir * TETHER_DRAG * give, 0.15)
	FX.burst(_tethered.global_position, Color(0.8, 0.9, 1.0, 0.8), 5, 40.0)
	Audio.play("hook", 0.2, -6.0)


func _process(delta: float) -> void:
	pivot.rotation = _player.aim.angle()
	sprite.flip_v = _player.aim.x < 0.0
	_gap_t = maxf(0.0, _gap_t - delta)
	_tether_cd = maxf(0.0, _tether_cd - delta)
	if _reload_t > 0.0:
		_reload_t -= delta
		if _reload_t <= 0.0:
			ammo = MAG
			Audio.play("reload", 0.05, -4.0)
			FX.text(_player.global_position + Vector2(0, -18), "LOADED", Color(0.85, 0.9, 1.0))
	elif _held and ammo > 0 and _gap_t <= 0.0:
		_fire(false)
	elif _held and ammo <= 0:
		_start_reload()
	_tick_tether(delta)


func _start_reload() -> void:
	if _reload_t > 0.0:
		return
	_reload_t = RELOAD
	Audio.play("reload", 0.1, -8.0)


func _fire(snap: bool) -> void:
	ammo -= 1
	_gap_t = SHOT_GAP
	var m: Dictionary = _player.mods
	var crit: bool = _player.consume_riptide() or randf() < float(m.crit_chance)
	var mult := arm_mult(_player, false, snap, crit, true)
	var dir := _player.aim
	var muzzle := _player.global_position + Vector2(0, -6) + dir * 14.0
	var p := Projectile.spawn(get_parent().get_parent() if get_parent().get_parent() else get_parent(), muzzle, dir * BOLT_SPEED,
		int(round(BOLT_DAMAGE * mult)), BOLT_TEX, _player, 128, BOLT_RANGE / BOLT_SPEED)
	p.rotation = dir.angle()
	p.pierce = true
	p.knockback = BOLT_KNOCKBACK
	p.tags = PackedStringArray(["ranged", "harpoon", "lunge"] if snap else ["ranged", "harpoon"])
	if crit:
		p.tags.append("crit")
	p.on_hit = _on_bolt_hit
	# Recoil.
	sprite.position = Vector2(-2, 0)
	var tw := create_tween()
	tw.tween_property(sprite, "position", Vector2(2, 0), 0.12)
	FX.burst(muzzle, Color(0.9, 0.9, 1.0, 0.8), 3, 30.0)
	Audio.play("harpoon", 0.12)
	EventBus.request_shake.emit(0.12)
	if ammo <= 0:
		_start_reload()


func _on_bolt_hit(target: Hurtbox, info: DamageInfo) -> void:
	FX.spark(target.global_position)
	_player.add_glow(Player.GLOW_PER_HIT * 0.9)
	var crit := info.tags.has("crit")
	EventBus.request_hitstop.emit(0.05 if not crit else 0.09)
	if crit:
		FX.text(target.global_position, "CRIT", Color(1.0, 0.95, 0.6))
		Audio.play("crit", 0.05)
	else:
		Audio.play("hit", 0.2, -3.0)


# --- tether ----------------------------------------------------------------------
func _throw_tether() -> void:
	var origin := _player.global_position
	var dir := _player.aim
	var space := get_world_2d().direct_space_state
	var end := origin + dir * TETHER_RANGE
	var ray := PhysicsRayQueryParameters2D.create(origin, end, 1)
	var wall := space.intersect_ray(ray)
	if wall:
		end = wall.position
	var seg := SegmentShape2D.new()
	seg.a = origin
	seg.b = end
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = seg
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = 1 << 7
	var best := INF
	var target: Enemy = null
	for r in space.intersect_shape(q, 8):
		var hb := r.collider as Hurtbox
		if hb == null:
			continue
		var e := hb.get_parent() as Enemy
		if e == null:
			continue
		var d := origin.distance_to(hb.global_position)
		if d < best:
			best = d
			target = e
	Audio.play("hook", 0.1)
	FX.burst(origin + dir * 12.0, Color(0.85, 0.9, 1.0, 0.8), 4, 30.0)
	if target == null:
		_tether_cd_total = TETHER_MISS_COOLDOWN
		_tether_cd = _tether_cd_total
		return
	_tether_cd_total = TETHER_COOLDOWN
	_tether_cd = _tether_cd_total
	_tethered = target
	_tether_t = TETHER_TIME
	target.tether(TETHER_TIME)
	var info := DamageInfo.make(int(round(TETHER_DAMAGE * float(_player.mods.damage) * float(_player.mods.ranged_mult))), _player, target.global_position - origin, 0.0)
	info.tags = PackedStringArray(["ranged", "harpoon", "tether"])
	info.hitstop = 0.0
	if target.hurtbox.receive(info):
		EventBus.damage_dealt.emit(target, info)
	FX.text(target.global_position, "TETHERED", Color(0.8, 0.9, 1.0))
	line.visible = true


func _tick_tether(delta: float) -> void:
	if _tethered == null:
		return
	_tether_t -= delta
	if _tether_t <= 0.0 or not is_instance_valid(_tethered) or not _tethered.health.is_alive():
		_tethered = null
		line.visible = false
		return
	line.clear_points()
	line.add_point(to_local(_player.global_position + Vector2(0, -6)))
	line.add_point(to_local(_tethered.global_position + Vector2(0, -6)))
