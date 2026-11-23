class_name PvpRules
extends RefCounted
## Best of three. Falls are recorded as they happen and settled once per tick with `resolve`,
## so two keepers falling in the same tick is a draw (the round is played again), not a win.
## Index 0 is the host, 1 the guest.

const TO_WIN := 2

var wins: Array = [0, 0]
var round: int = 1
var match_over: bool = false

var _fell: Array = [false, false]


func fall(i: int) -> void:
	if not match_over:
		_fell[i] = true


## {kind: "none"} when nobody fell, else {kind: "win"|"draw", winner (-1 for a draw),
## match_over, wins}.
func resolve() -> Dictionary:
	if not (_fell[0] or _fell[1]):
		return {"kind": "none"}
	var f0: bool = _fell[0]
	var f1: bool = _fell[1]
	_fell = [false, false]
	if f0 and f1:
		return {"kind": "draw", "winner": -1, "match_over": false, "wins": wins.duplicate()}
	var w := 1 if f0 else 0
	wins[w] += 1
	round += 1
	if wins[w] >= TO_WIN:
		match_over = true
	return {"kind": "win", "winner": w, "match_over": match_over, "wins": wins.duplicate()}
