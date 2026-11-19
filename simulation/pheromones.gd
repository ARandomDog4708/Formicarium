extends RefCounted
## Each occupied grid cell is one pheromone sample per channel. Deposits
## reinforce samples; grid lookup bounds the query without scanning all trails.
const WorldData = preload("res://simulation/world.gd")
enum Kind { HOME, FOOD }
const MIN_STRENGTH: float = 0.025

var world: WorldData
var home := PackedFloat32Array()
var food := PackedFloat32Array()
var half_life: float = 32.0
var active_count: int = 0

func _init(map: WorldData) -> void:
	world = map
	home.resize(WorldData.COLS * WorldData.ROWS)
	food.resize(home.size())

func clear() -> void:
	home.fill(0.0)
	food.fill(0.0)
	active_count = 0

func deposit(p: Vector2, kind: int, strength: float) -> void:
	var x: int = floori(p.x / WorldData.CELL)
	var y: int = floori(p.y / WorldData.CELL)
	if not world.is_cell_open(x, y):
		return
	var i := WorldData.index(x, y)
	if kind == Kind.HOME:
		home[i] = minf(5.0, maxf(home[i], strength) + strength * 0.06)
	else:
		food[i] = minf(5.0, maxf(food[i], strength) + strength * 0.06)

func decay(dt: float) -> void:
	var factor: float = exp(-log(2.0) * dt / half_life)
	active_count = 0
	for i in range(home.size()):
		home[i] = home[i] * factor if home[i] * factor >= MIN_STRENGTH else 0.0
		food[i] = food[i] * factor if food[i] * factor >= MIN_STRENGTH else 0.0
		if home[i] > 0:
			active_count += 1
		if food[i] > 0:
			active_count += 1

func sense(p: Vector2, heading: float, kind: int, inner: float, outer: float, half_angle: float, speed: float, falloff: float, collect: bool = false) -> Dictionary:
	var force := Vector2.ZERO
	var count: int = 0
	var visible := PackedVector2Array()
	var forward := Vector2.from_angle(heading)
	var cosine: float = cos(half_angle)
	var x0: int = maxi(0, floori((p.x - outer) / WorldData.CELL))
	var x1: int = mini(WorldData.COLS - 1, floori((p.x + outer) / WorldData.CELL))
	var y0: int = maxi(0, floori((p.y - outer) / WorldData.CELL))
	var y1: int = mini(WorldData.ROWS - 1, floori((p.y + outer) / WorldData.CELL))
	var values: PackedFloat32Array = home if kind == Kind.HOME else food
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var strength: float = values[WorldData.index(x, y)]
			if strength < MIN_STRENGTH:
				continue
			var target := WorldData.cell_center(x, y)
			var offset := target - p
			var d2: float = offset.length_squared()
			if d2 <= inner * inner or d2 > outer * outer:
				continue
			var distance: float = sqrt(d2)
			var unit := offset / distance
			if forward.dot(unit) < cosine or not world.line_clear(p, target):
				continue
			force += unit * strength * speed / (1.0 + distance / falloff)
			count += 1
			if collect:
				visible.append(target)
	return {"force": force.limit_length(speed), "count": count, "visible": visible}
