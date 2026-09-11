class_name Hitbox
extends Area2D
## Deals hits while active. Masks the opposing hurtbox layer. Each activation hits a
## given hurtbox at most once. Polls overlaps in physics so enabling mid-overlap works.

signal landed(target: Hurtbox, info: DamageInfo)

@export var damage: int = 1
@export var knockback: float = 60.0
@export var hitstop: float = 0.06
@export var pull: bool = false  # knockback toward the source instead of away
@export var tags: PackedStringArray = []

var source: Node2D  # whose hit this is; direction is measured from here
var damage_mult: float = 1.0  # stat multipliers
var crit: bool = false        # tags the hit as a crit (FX, feedback)
var active: bool = false
var _already_hit: Array[Hurtbox] = []


func _ready() -> void:
	monitorable = false
	monitoring = false
	if source == null:
		source = get_parent() as Node2D


func activate() -> void:
	_already_hit.clear()
	active = true
	monitoring = true


func deactivate() -> void:
	active = false
	monitoring = false


func _physics_process(_delta: float) -> void:
	if not active:
		return
	for area in get_overlapping_areas():
		var hb := area as Hurtbox
		if hb == null or hb in _already_hit:
			continue
		var origin: Vector2 = source.global_position if source else global_position
		var dir := hb.global_position - origin
		if pull:
			dir = -dir
		var info := DamageInfo.make(int(round(damage * damage_mult)), source, dir, knockback)
		info.hitstop = hitstop
		info.tags = tags.duplicate()
		if crit:
			info.tags.append("crit")
		if hb.receive(info):
			_already_hit.append(hb)
			landed.emit(hb, info)
			EventBus.damage_dealt.emit(hb.get_parent(), info)
