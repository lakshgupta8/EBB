class_name Scenery
extends RefCounted
## The layers beyond the gameplay one (art Stage 12; STYLE.md 8, 11, 20): the void beyond the
## walls, the far scenery standing in it, and the foreground silhouettes on the south rim.
## Placement only; room.gd draws what this returns.

const BEYOND := preload("res://assets/sprites/beyond.png")
const SCENERY := preload("res://assets/sprites/scenery.png")
const FOREGROUND := preload("res://assets/sprites/foreground.png")
const CELL := 48
const FG_W := 16
const FG_H := 24
## The void's texture, one row of beyond.png per look: sea dashes (the rock stands in the
## night sea), rubble beyond the Streets, near nothing in the Hall. Three variants per row.
enum Void { SEA, RUBBLE, DEEP }
const VOID_COLS := 3
## The void shifts with Tam, this many px per px of Tam's offset from the room centre, so the
## rim walls read as nearer than what stands beyond them. Small: the view stays top-down.
const PARALLAX := 0.03
## Far scenery pieces (scenery.png, 48 px cells, anchored bottom centre): [w, h, looks].
## Mirrors tools/gen_scenery.py.
const PIECES := [
	[24, 28, [Tiles.Look.FLATS, Tiles.Look.HUB, Tiles.Look.HARBOUR]],  # 0 rock stack
	[40, 24, [Tiles.Look.FLATS, Tiles.Look.HARBOUR]],                  # 1 wreck ribs
	[48, 12, [Tiles.Look.FLATS]],                                      # 2 dune
	[48, 32, [Tiles.Look.HUB]],                                        # 3 village roofs
	[24, 44, [Tiles.Look.HUB]],                                        # 4 chapel
	[32, 14, [Tiles.Look.FLATS, Tiles.Look.HUB, Tiles.Look.HARBOUR]],  # 5 low rock
	[48, 32, [Tiles.Look.STREETS]],                                    # 6 roofline
	[32, 32, [Tiles.Look.STREETS]],                                    # 7 broken arch
	[24, 48, [Tiles.Look.STREETS]],                                    # 8 leaning tower
	[48, 20, [Tiles.Look.STREETS]],                                    # 9 ruin wall
	[16, 48, [Tiles.Look.DEEP]],                                       # 10 column
	[16, 28, [Tiles.Look.DEEP]],                                       # 11 broken column
	[8, 48, [Tiles.Look.DEEP]],                                        # 12 hanging chain
	[48, 40, [Tiles.Look.DEEP]],                                       # 13 great arch
]
## Foreground pieces (foreground.png, 16x24, anchored bottom centre): looks.
const FORE := [
	[Tiles.Look.FLATS, Tiles.Look.HUB, Tiles.Look.HARBOUR],  # 0 mooring post and rope
	[Tiles.Look.FLATS, Tiles.Look.HUB],                      # 1 kelp rising
	[Tiles.Look.FLATS, Tiles.Look.HARBOUR],                  # 2 wreck rib
	[Tiles.Look.STREETS],                                    # 3 broken beam
	[Tiles.Look.STREETS],                                    # 4 signpost
	[Tiles.Look.STREETS],                                    # 5 dead lamp
	[Tiles.Look.DEEP],                                       # 6 chain end
	[Tiles.Look.DEEP],                                       # 7 candle stand
	[Tiles.Look.DEEP],                                       # 8 column stump
]
## Foreground pieces per room, and the clear cells kept between them and round every door.
const FORE_MIN := 2
const FORE_MAX := 3
const FORE_GAP := 4
const DOOR_CLEAR := 2


static func void_row(look: int) -> int:
	match look:
		Tiles.Look.STREETS: return Void.RUBBLE
		Tiles.Look.DEEP: return Void.DEEP
		_: return Void.SEA


## Which of the three variants a void cell shows: two in five are empty, so no lattice forms.
static func void_variant(cell: Vector2i) -> int:
	var h := absi(hash(cell)) % 100
	return 0 if h < 40 else 1 if h < 72 else 2


## Wall cells with nothing but wall around them: the world stops there.
static func beyond_cells(t: RoomTemplate) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in t.height:
		for x in t.width:
			if t.is_beyond(x, y):
				out.append(Vector2i(x, y))
	return out


static func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = list[i]
		list[i] = list[j]
		list[j] = tmp


## Far scenery on the beyond cells. Every connected patch of void gets something if anything
## fits (an empty patch reads as a pit, not as the world going on): one piece per ~14 cells,
## up to four per patch, never overlapping, a cell apart, every covered cell beyond.
## Returns [{kind, pos (bottom centre, px), cells}].
static func place_scenery(t: RoomTemplate, look: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var beyond: Dictionary = {}
	for c in beyond_cells(t):
		beyond[c] = true
	if beyond.is_empty():
		return out
	var kinds: Array[int] = []
	for i in PIECES.size():
		if look in PIECES[i][2]:
			kinds.append(i)
	if kinds.is_empty():
		return out
	var taken: Dictionary = {}
	for region in _regions(beyond):
		var cap := clampi(region.size() / 14, 1, 4)
		var cells: Array = region.duplicate()
		_shuffle(cells, rng)
		var placed := 0
		for anchor: Vector2i in cells:
			if placed >= cap:
				break
			var order := kinds.duplicate()
			_shuffle(order, rng)
			for kind in order:
				var covered := _footprint(anchor, kind)
				var ok := true
				for c in covered:
					if not beyond.has(c) or taken.has(c):
						ok = false
						break
				if not ok:
					continue
				for c in covered:
					for dy in range(-1, 2):
						for dx in range(-1, 2):
							taken[c + Vector2i(dx, dy)] = true
				out.append({"kind": kind, "pos": Vector2(anchor.x * Tiles.SIZE + Tiles.SIZE / 2, (anchor.y + 1) * Tiles.SIZE), "cells": covered})
				placed += 1
				break
	return out


## The beyond cells grouped into patches (4-connected).
static func _regions(beyond: Dictionary) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for start: Vector2i in beyond:
		if seen.has(start):
			continue
		var region: Array[Vector2i] = [start]
		seen[start] = true
		var qi := 0
		while qi < region.size():
			var c: Vector2i = region[qi]
			qi += 1
			for off: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
				var n: Vector2i = c + off
				if beyond.has(n) and not seen.has(n):
					seen[n] = true
					region.append(n)
		out.append(region)
	return out


## The cells a piece covers when its bottom centre sits on the bottom centre of `anchor`.
static func _footprint(anchor: Vector2i, kind: int) -> Array[Vector2i]:
	var w: int = PIECES[kind][0]
	var h: int = PIECES[kind][1]
	var x0 := anchor.x * Tiles.SIZE + Tiles.SIZE / 2 - w / 2
	var y0 := (anchor.y + 1) * Tiles.SIZE - h
	var out: Array[Vector2i] = []
	@warning_ignore("integer_division")
	for cy in range(floori(float(y0) / Tiles.SIZE), anchor.y + 1):
		for cx in range(floori(float(x0) / Tiles.SIZE), floori(float(x0 + w - 1) / Tiles.SIZE) + 1):
			out.append(Vector2i(cx, cy))
	return out


## Foreground silhouettes on the south rim: two or three, four cells apart, never within two
## cells of a door. Returns [{kind, pos (bottom centre, px), cell}].
static func place_foreground(t: RoomTemplate, look: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var kinds: Array[int] = []
	for i in FORE.size():
		if look in FORE[i]:
			kinds.append(i)
	if kinds.is_empty() or t.height < 3:
		return out
	var row := t.height - 1
	var doors: Array = t.doors.duplicate()
	doors.append_array(t.marker_cells("X"))
	var cells: Array = []
	for x in range(2, t.width - 2):
		if t.char_at(x, row) != "#":
			continue
		var clear := true
		for d: Vector2i in doors:
			if absi(d.x - x) <= DOOR_CLEAR and absi(d.y - row) <= DOOR_CLEAR:
				clear = false
				break
		if clear:
			cells.append(x)
	_shuffle(cells, rng)
	var want := rng.randi_range(FORE_MIN, FORE_MAX)
	var used: Array[int] = []
	for x: int in cells:
		if out.size() >= want:
			break
		var apart := true
		for u in used:
			if absi(u - x) < FORE_GAP:
				apart = false
				break
		if not apart:
			continue
		used.append(x)
		var kind: int = kinds[rng.randi() % kinds.size()]
		out.append({"kind": kind, "pos": Vector2(x * Tiles.SIZE + Tiles.SIZE / 2, (row + 1) * Tiles.SIZE), "cell": Vector2i(x, row)})
	return out
