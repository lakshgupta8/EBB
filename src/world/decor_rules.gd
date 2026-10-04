class_name DecorRules
extends RefCounted
## Where the small things lie (art Stage 12; STYLE.md 8). Decor is placed by rule, not
## scattered: never in a doorway or the cells before it, never on raised stone, never under a
## prop or a spawn; kelp and puddles only by water; benches, pots and barrels against walls;
## candles in the Hall's corners. Fountain and altar rooms are sparse, treasure rooms are
## cluttered on one side, the boss arena is nearly bare. Placement only; room.gd draws.

enum Rule { ANY, BY_WATER, ON_WATER, BY_WALL, WALL_NORTH, CORNER, DRY_BY_WALL }

## Per look, one entry per atlas cell: [rule, cap] (cap 0 means only the shared cap applies).
## Flats: shell, kelp, driftwood, pebbles, puddle, bones, hole, grass.
const FLATS := [[Rule.ANY, 0], [Rule.BY_WATER, 0], [Rule.ANY, 0], [Rule.ANY, 0], [Rule.ON_WATER, 0],
	[Rule.ANY, 1], [Rule.ANY, 1], [Rule.DRY_BY_WALL, 0]]
## Streets: lamppost, bench, barrel, signboard, crack, weed, pot, sign.
const STREETS := [[Rule.BY_WALL, 1], [Rule.WALL_NORTH, 0], [Rule.BY_WALL, 0], [Rule.BY_WALL, 0], [Rule.ANY, 0],
	[Rule.BY_WALL, 0], [Rule.BY_WALL, 0], [Rule.BY_WALL, 1]]
## Hall: candles, chain coil, pew, keeper statue, chain, kelp column, cracked, dead lamp.
## Candles carry a minimum too ([rule, cap, min]): every Hall room gets 2-4 drifts, placed first.
const HALL := [[Rule.CORNER, 4, 2], [Rule.ANY, 0], [Rule.WALL_NORTH, 0], [Rule.BY_WALL, 1], [Rule.BY_WALL, 0],
	[Rule.BY_WATER, 0], [Rule.ANY, 0], [Rule.BY_WALL, 2]]
## Harbour (its decor is Stage 19): anything anywhere.
const HARBOUR := [[Rule.ANY, 0], [Rule.ANY, 0], [Rule.ANY, 0], [Rule.ANY, 0], [Rule.ANY, 0], [Rule.ANY, 0],
	[Rule.ANY, 0], [Rule.ANY, 0]]

## How many pieces a room gets, by its template's name: [lo, hi, one_side].
const DENSITY := {
	"fountain": [6, 9, false], "altar": [6, 9, false], "echo": [6, 9, false],
	"treasure": [16, 18, true], "vault": [16, 18, true],
	"shop": [8, 12, false], "boss": [4, 8, false], "hub": [10, 14, false],
}
const DENSITY_DEFAULT := [10, 18, false]
## Clusters (map Stage 04): pieces per cluster, how far round its anchor, anchors apart.
const CLUSTER_MIN := 3
const CLUSTER_MAX := 7
const CLUSTER_RADIUS := 2
const ANCHOR_GAP := 6
## Clear cells kept: before a door, round the player's spawn and every prop marker.
const DOOR_CLEAR := 2
const MARKER_CLEAR := 1


static func rules_for(look: int) -> Array:
	match look:
		Tiles.Look.STREETS: return STREETS
		Tiles.Look.DEEP: return HALL
		Tiles.Look.HARBOUR: return HARBOUR
		_: return FLATS


static func density_for(name: String) -> Array:
	for prefix in DENSITY:
		if name.begins_with(prefix):
			return DENSITY[prefix]
	return DENSITY_DEFAULT


## Cells no decor may take: solid and raised cells, doors and the cells before them, the
## spawn, enemy spawns, every marker and its neighbours.
static func blocked_cells(t: RoomTemplate) -> Dictionary:
	var blocked: Dictionary = {}
	var doors: Array = t.doors.duplicate()
	doors.append_array(t.marker_cells("X"))
	for d: Vector2i in doors:
		for dy in range(-DOOR_CLEAR, DOOR_CLEAR + 1):
			for dx in range(-DOOR_CLEAR, DOOR_CLEAR + 1):
				blocked[d + Vector2i(dx, dy)] = true
	var near: Array = [t.player_spawn]
	for ch in t.markers:
		near.append_array(t.markers[ch])
	for c: Vector2i in near:
		for dy in range(-MARKER_CLEAR, MARKER_CLEAR + 1):
			for dx in range(-MARKER_CLEAR, MARKER_CLEAR + 1):
				blocked[c + Vector2i(dx, dy)] = true
	for c in t.enemy_spawns:
		blocked[c] = true
	for c in t.piece_cells:
		blocked[c] = true
	return blocked


static func _wall(t: RoomTemplate, c: Vector2i) -> bool:
	var ch := t.char_at(c.x, c.y)
	return ch == "#" or ch == "o" or t.piece_cells.has(c)


static func _low(t: RoomTemplate, c: Vector2i) -> bool:
	return not t.is_solid(c.x, c.y) and t.height_at(c.x, c.y) == 0


static func _by(t: RoomTemplate, c: Vector2i, test: Callable) -> bool:
	for off: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		if test.call(t, c + off):
			return true
	return false


static func allowed(t: RoomTemplate, c: Vector2i, rule: int) -> bool:
	match rule:
		Rule.ANY: return true
		Rule.ON_WATER: return _low(t, c)
		Rule.BY_WATER: return _low(t, c) or _by(t, c, _low)
		Rule.BY_WALL: return _by(t, c, _wall)
		Rule.WALL_NORTH: return _wall(t, c + Vector2i(0, -1))
		Rule.CORNER:
			return (_wall(t, c + Vector2i(0, -1)) or _wall(t, c + Vector2i(0, 1))) \
				and (_wall(t, c + Vector2i(1, 0)) or _wall(t, c + Vector2i(-1, 0)))
		Rule.DRY_BY_WALL: return _by(t, c, _wall) and not _low(t, c) and not _by(t, c, _low)
	return false


static func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = list[i]
		list[i] = list[j]
		list[j] = tmp


static func _apart(c: Vector2i, taken: Array[Vector2i], gap: int) -> bool:
	for tk in taken:
		if maxi(absi(tk.x - c.x), absi(tk.y - c.y)) < gap:
			return false
	return true


## The room's decor: [{kind, cell}], deterministic for a seed.
static func plan(t: RoomTemplate, look: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rules := rules_for(look)
	var d := density_for(t.name)
	var want: int = rng.randi_range(d[0], d[1])
	# A room larger than a screen takes more, by area (map Stage 02).
	want = int(round(want * maxf(1.0, float(t.width * t.height) / (40.0 * 23.0))))
	var one_side: bool = d[2]
	var side := rng.randi() % 2
	var blocked := blocked_cells(t)
	var cells: Array = []
	for y in range(1, t.height - 1):
		for x in range(1, t.width - 1):
			var c := Vector2i(x, y)
			var ch := t.char_at(x, y)
			if (ch != "." and ch != "_") or blocked.has(c):
				continue
			# a cluttered room keeps nearly all of its pieces to one half
			if one_side and (x * 2 < t.width) != (side == 0) and rng.randf() < 0.92:
				continue
			cells.append(c)
	_shuffle(cells, rng)
	var gap := 1 if one_side else 2
	var shared_cap := ceili(want / 3.0)
	var counts: Dictionary = {}
	var taken: Array[Vector2i] = []
	# Kinds with a minimum go first, from the cells that suit them.
	for kind in rules.size():
		var lo: int = rules[kind][2] if rules[kind].size() > 2 else 0
		if lo <= 0:
			continue
		var want_k: int = rng.randi_range(lo, rules[kind][1])
		for c: Vector2i in cells:
			if int(counts.get(kind, 0)) >= want_k:
				break
			if not allowed(t, c, rules[kind][0]) or not _apart(c, taken, gap):
				continue
			counts[kind] = int(counts.get(kind, 0)) + 1
			taken.append(c)
			out.append({"kind": kind, "cell": c})
	# The rest go down in clusters (map Stage 04, STYLE.md 22): three to seven pieces round an
	# anchor that has a reason to gather things (the tide line, the foot of a wall or a rock, a
	# corner), bare ground between the clusters, never a sprinkle.
	var anchors := _anchors(t, cells, rng)
	var ai := 0
	while out.size() < want and ai < anchors.size():
		var anchor: Vector2i = anchors[ai]
		ai += 1
		var cap_here := rng.randi_range(CLUSTER_MIN, CLUSTER_MAX)
		var here := 0
		for c: Vector2i in cells:
			if out.size() >= want or here >= cap_here:
				break
			if maxi(absi(c.x - anchor.x), absi(c.y - anchor.y)) > CLUSTER_RADIUS or not _apart(c, taken, 1):
				continue
			var order := range(rules.size())
			_shuffle(order, rng)
			for kind: int in order:
				var cap: int = rules[kind][1] if int(rules[kind][1]) > 0 else shared_cap
				if int(counts.get(kind, 0)) >= cap or not allowed(t, c, rules[kind][0]):
					continue
				counts[kind] = int(counts.get(kind, 0)) + 1
				taken.append(c)
				out.append({"kind": kind, "cell": c})
				here += 1
				break
	return out


## Cluster anchors, reasoned ones first (by low ground, by a wall or a rock, in a corner), each
## ANCHOR_GAP from the last, then any cell as a fallback so a bare room still gets its count.
static func _anchors(t: RoomTemplate, cells: Array, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var reasoned: Array = []
	var rest: Array = []
	for c: Vector2i in cells:
		if _by(t, c, _low) or _by(t, c, _wall) or allowed(t, c, Rule.CORNER) or _wall(t, c + Vector2i(0, -2)):
			reasoned.append(c)
		else:
			rest.append(c)
	var out: Array[Vector2i] = []
	for pool in [reasoned, rest]:
		for c: Vector2i in pool:
			var clear := true
			for a in out:
				if maxi(absi(a.x - c.x), absi(a.y - c.y)) < ANCHOR_GAP:
					clear = false
					break
			if clear:
				out.append(c)
	return out
