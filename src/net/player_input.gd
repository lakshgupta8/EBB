class_name PlayerInput
extends RefCounted
## One tick of a keeper's intent: from the devices for the local keeper, from a network
## frame for the guest. `*_pressed` are one-tick edges, `attack_held` is a level.

var move := Vector2.ZERO
var aim := Vector2.RIGHT
var attack_held := false
var attack_pressed := false
var special_pressed := false
var dash_pressed := false
var use_pressed := false


static func from_buttons(p_move: Vector2, aim_angle: float, buttons: int) -> PlayerInput:
	var i := PlayerInput.new()
	i.move = p_move
	i.aim = Vector2.from_angle(aim_angle)
	i.attack_pressed = buttons & NetProtocol.BTN_ATTACK != 0
	i.special_pressed = buttons & NetProtocol.BTN_SPECIAL != 0
	i.dash_pressed = buttons & NetProtocol.BTN_DASH != 0
	i.use_pressed = buttons & NetProtocol.BTN_USE != 0
	i.attack_held = buttons & NetProtocol.BTN_HELD != 0
	return i


func to_buttons() -> int:
	var b := 0
	if attack_pressed: b |= NetProtocol.BTN_ATTACK
	if special_pressed: b |= NetProtocol.BTN_SPECIAL
	if dash_pressed: b |= NetProtocol.BTN_DASH
	if use_pressed: b |= NetProtocol.BTN_USE
	if attack_held: b |= NetProtocol.BTN_HELD
	return b


func consume_edges() -> void:
	attack_pressed = false
	special_pressed = false
	dash_pressed = false
	use_pressed = false
