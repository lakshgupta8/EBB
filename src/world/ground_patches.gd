class_name GroundPatches
extends RefCounted
## Ground at scale (map Stage 04; STYLE.md 22): which floor cells carry which of the look's three
## overlay patches (patch.png, tools/gen_terrain.py). Each patch lies where it has a reason to:
## wet ground by low ground, worn ground on the routes between the doors, shingle or moss at the
## foot of walls and rocks, and blobs by noise in the open. The open blobs grow until bare floor
## is at most MAX_BASE of the floor. Placement only; room.gd draws.

enum Reason { WET, PATH, FOOT, SHADE, NOISE }

## Per look (Tiles.Look order), the reason for patch 0, 1 and 2 (patch.png rows), and which one
## also takes the noise blobs.
const REASONS := {
	Tiles.Look.FLATS: [Reason.WET, Reason.NOISE, Reason.FOOT],
	Tiles.Look.STREETS: [Reason.PATH, Reason.SHADE, Reason.WET],
	Tiles.Look.DEEP: [Reason.PATH, Reason.NOISE, Reason.WET],
	Tiles.Look.HARBOUR: [Reason.PATH, Reason.NOISE, Reason.WET],
	Tiles.Look.HUB: [Reason.WET, Reason.NOISE, Reason.FOOT],
}
const SPREAD := 1  # the patch that grows by noise until the floor is broken up enough
const MAX_BASE := 0.55
const WET_REACH := 2
const PATH_HALF := 1
const NOISE_FREQ := 0.09


## A floor cell for patches: walkable floor height (not low, not raised), not a wall or rock.
static func is_floor(t: RoomTemplate, x: int, y: int) -> bool:
	if t.is_solid(x, y) or t.is_beyond(x, y):
		return false
	var ch := t.char_at(x, y)
	return ch != "D" and t.height_at(x, y) == 1


## cell -> patch index (0-2). Deterministic for a seed.
static func plan(t: RoomTemplate, look: int, seed_value: int) -> Dictionary:
	var reasons: Array = REASONS.get(look, REASONS[Tiles.Look.FLATS])
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = NOISE_FREQ
	var floor_cells: Array[Vector2i] = []
	for y in t.height:
		for x in t.width:
			if is_floor(t, x, y):
				floor_cells.append(Vector2i(x, y))
	if floor_cells.is_empty():
		return {}
	var wet := _wet(t, noise)
	var path := _paths(t, noise)
	var out: Dictionary = {}
	# Reasons first, in the look's order of priority (wet ground before a path across it).
	for c in floor_cells:
		for p in reasons.size():
			var hit := false
			match reasons[p]:
				Reason.WET: hit = wet.has(c)
				Reason.PATH: hit = path.has(c)
				# Shingle gathers in drifts at the foot of the rock, not as a hem along all of it.
				Reason.FOOT: hit = (_near_solid(t, c, 1) and noise.get_noise_2d(c.x * 3.0, c.y * 3.0) > -0.1) 					or (_near_solid(t, c, 2) and noise.get_noise_2d(c.x * 3.0, c.y * 3.0) > 0.35)
				Reason.SHADE: hit = _shaded(t, c, noise)
			if hit:
				out[c] = p
				break
	# Then the spread patch takes noise blobs, its threshold lowered until the floor is broken up.
	var threshold := 0.35
	var spread: Dictionary = {}
	while true:
		spread.clear()
		for c in floor_cells:
			if not out.has(c) and noise.get_noise_2d(c.x, c.y) > threshold:
				spread[c] = true
		var bare := floor_cells.size() - out.size() - spread.size()
		if float(bare) / floor_cells.size() <= MAX_BASE or threshold < -0.6:
			break
		threshold -= 0.05
	for c in spread:
		out[c] = SPREAD
	return out


## Share of the floor left as the bare base tile.
static func base_share(t: RoomTemplate, patches: Dictionary) -> float:
	var n := 0
	var bare := 0
	for y in t.height:
		for x in t.width:
			if is_floor(t, x, y):
				n += 1
				if not patches.has(Vector2i(x, y)):
					bare += 1
	return float(bare) / maxf(1.0, n)


static func _near_solid(t: RoomTemplate, c: Vector2i, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var n := c + Vector2i(dx, dy)
			var ch := t.char_at(n.x, n.y)
			if (ch == "#" and not t.is_beyond(n.x, n.y)) or ch == "o" or t.piece_cells.has(n):
				return true
	return false


## Moss grows where a wall stands to the north (its shade) or right against one.
static func _shaded(t: RoomTemplate, c: Vector2i, noise: FastNoiseLite) -> bool:
	for k in [1, 2]:
		if t.char_at(c.x, c.y - k) == "#":
			return k == 1 or noise.get_noise_2d(c.x * 2.0, c.y * 2.0) > -0.2
	for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
		var n: Vector2i = c + off
		if t.char_at(n.x, n.y) == "#":
			return true
	return false


## Wet ground: within WET_REACH of low ground, a step further where the noise says.
static func _wet(t: RoomTemplate, noise: FastNoiseLite) -> Dictionary:
	var dist: Dictionary = {}
	var queue: Array[Vector2i] = []
	for y in t.height:
		for x in t.width:
			if not t.is_solid(x, y) and t.height_at(x, y) == 0:
				dist[Vector2i(x, y)] = 0
				queue.append(Vector2i(x, y))
	var qi := 0
	while qi < queue.size():
		var c: Vector2i = queue[qi]
		qi += 1
		if int(dist[c]) >= WET_REACH + 1:
			continue
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + off
			if dist.has(n) or t.is_solid(n.x, n.y) or n.x < 0 or n.y < 0 or n.x >= t.width or n.y >= t.height:
				continue
			dist[n] = int(dist[c]) + 1
			queue.append(n)
	var out: Dictionary = {}
	for c in dist:
		var d: int = dist[c]
		# One cell always, then as far as the noise carries it: a tide mark, not a halo.
		var n := noise.get_noise_2d(c.x * 2.0, c.y * 2.0)
		if d == 1 or (d == 2 and n > -0.15) or (d == WET_REACH + 1 and n > 0.25):
			out[c] = true
	return out


## Worn ground: the routes a body takes between the keeper's spawn and every door, three wide.
static func _paths(t: RoomTemplate, noise: FastNoiseLite) -> Dictionary:
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, t.width, t.height)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in t.height:
		for x in t.width:
			if t.is_solid(x, y):
				astar.set_point_solid(Vector2i(x, y), true)
	var ends: Array[Vector2i] = []
	if t.player_spawn.x >= 0:
		ends.append(t.player_spawn)
	for d in t.doors:
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = d + off
			if n.x >= 0 and n.y >= 0 and n.x < t.width and n.y < t.height and not t.is_solid(n.x, n.y):
				ends.append(n)
				break
	var line: Dictionary = {}
	for i in ends.size():
		for j in range(i + 1, ends.size()):
			for c in astar.get_id_path(ends[i], ends[j]):
				line[c] = true
	var out: Dictionary = {}
	for c: Vector2i in line:
		var r := PATH_HALF + (1 if noise.get_noise_2d(c.x * 2.0, c.y * 2.0) > 0.3 else 0)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				out[c + Vector2i(dx, dy)] = true
	return out


## Large decals (tools/gen_ground_decals.py, ground_decals.png): [{kind, cell}] where cell is
## the top-left of a clear 2x2 of bare floor. About one per screen of floor, DECAL_GAP apart,
## never before a door or on a spawn or a prop.
const DECAL_GAP := 10
const DECAL_KINDS := 3


static func decals(t: RoomTemplate, p: Dictionary, seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 101
	var blocked := DecorRules.blocked_cells(t)
	var spots: Array[Vector2i] = []
	var floor_n := 0
	for y in t.height - 1:
		for x in t.width - 1:
			if is_floor(t, x, y):
				floor_n += 1
			var ok := true
			for c in [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x, y + 1), Vector2i(x + 1, y + 1)]:
				if not is_floor(t, c.x, c.y) or p.has(c) or blocked.has(c) or t.char_at(c.x, c.y) != ".":
					ok = false
					break
			if ok:
				spots.append(Vector2i(x, y))
	var want := floor_n / 700
	if floor_n % 700 > 350 and rng.randf() < 0.5:
		want += 1
	var out: Array[Dictionary] = []
	for i in range(spots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := spots[i]
		spots[i] = spots[j]
		spots[j] = tmp
	for c in spots:
		if out.size() >= want:
			break
		var clear := true
		for d in out:
			if maxi(absi(d.cell.x - c.x), absi(d.cell.y - c.y)) < DECAL_GAP:
				clear = false
				break
		if clear:
			out.append({"kind": rng.randi() % DECAL_KINDS, "cell": c})
	return out
