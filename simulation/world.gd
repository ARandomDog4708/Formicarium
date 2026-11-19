extends RefCounted
## The two maps have independent occupancy; a fine mask keeps tunnels rounded.
enum Kind { OUTDOORS, COLONY }
const CELL: float = 8.0
const COLS: int = 80
const ROWS: int = 96
const WIDTH: float = COLS * CELL
const HEIGHT: float = ROWS * CELL
const WALK_CELL: float = 2.0
const WALK_COLS: int = 320
const WALK_ROWS: int = 384
const PORTAL_RADIUS: float = 18.0

var kind: int
var walkable := PackedByteArray()
var home := Vector2(150, 136)
var portal := Vector2.ZERO
var chambers: Array[Dictionary] = []
var tunnels: Array[Dictionary] = []
var paths: Array[Dictionary] = []
var rocks: Array[Dictionary] = []
var foods: Array[Dictionary] = []

func _init(location: int = Kind.OUTDOORS) -> void:
	kind = location
	walkable.resize(WALK_COLS * WALK_ROWS)
	if kind == Kind.OUTDOORS:
		portal = Vector2(350, 350)
		rocks = [
			{"center": Vector2(135, 258), "radii": Vector2(29, 22)},
			{"center": Vector2(496, 550), "radii": Vector2(35, 27)},
			{"center": Vector2(255, 650), "radii": Vector2(26, 18)},
		]
		for y in range(WALK_ROWS):
			for x in range(WALK_COLS):
				var p := mask_center(x, y)
				var open: bool = rounded_distance(p, Rect2(14, 14, WIDTH - 28, HEIGHT - 28), 45.0) <= 0.0
				for rock in rocks:
					if ((p - rock.center) / rock.radii).length_squared() <= 1.0:
						open = false
				walkable[mask_index(x, y)] = 1 if open else 0
		add_food(Vector2(438, 348), 180)
		add_food(Vector2(150, 560), 260)
	else:
		portal = Vector2(128, 36)
		chambers = [
			{"center": home, "radii": Vector2(74, 48), "name": "NEST CHAMBER"},
			{"center": Vector2(410, 300), "radii": Vector2(104, 58), "name": "EAST GALLERY"},
			{"center": Vector2(205, 455), "radii": Vector2(105, 62), "name": "WEST GALLERY"},
			{"center": Vector2(392, 636), "radii": Vector2(112, 57), "name": "LOWER CHAMBER"},
		]
		_add_tunnel([Vector2(128, -8), portal, Vector2(127, 87), home], 19.0)
		_add_tunnel([home, Vector2(242, 192), Vector2(254, 260), Vector2(335, 303), Vector2(410, 300)], 20.0)
		_add_tunnel([Vector2(410, 300), Vector2(486, 380), Vector2(417, 438), Vector2(300, 455), Vector2(205, 455)], 19.0)
		_add_tunnel([Vector2(205, 455), Vector2(133, 346), Vector2(148, 269), Vector2(242, 192)], 18.0)
		_add_tunnel([Vector2(205, 455), Vector2(233, 554), Vector2(294, 615), Vector2(392, 636)], 18.0)
		_add_tunnel([Vector2(486, 380), Vector2(526, 501), Vector2(479, 576), Vector2(392, 636)], 19.0)
		for chamber in chambers:
			_carve_ellipse(chamber.center, chamber.radii)
		for tunnel in tunnels:
			_carve_capsule(tunnel.a, tunnel.b, tunnel.radius)

static func rounded_distance(p: Vector2, rect: Rect2, radius: float) -> float:
	var q := (p - rect.get_center()).abs() - rect.size * 0.5 + Vector2.ONE * radius
	return q.max(Vector2.ZERO).length() + minf(maxf(q.x, q.y), 0.0) - radius

func _add_tunnel(points: Array, radius: float) -> void:
	var smooth := PackedVector2Array()
	for i in range(points.size() - 1):
		var before: Vector2 = points[maxi(0, i - 1)]
		var after: Vector2 = points[mini(points.size() - 1, i + 2)]
		for step in range(10):
			var p: Vector2 = points[i]
			smooth.append(p.cubic_interpolate(points[i + 1], before, after, float(step) / 10.0))
	smooth.append(points[-1])
	paths.append({"points": smooth, "radius": radius})
	for i in range(smooth.size() - 1):
		tunnels.append({"a": smooth[i], "b": smooth[i + 1], "radius": radius})

func _carve_ellipse(center: Vector2, radii: Vector2) -> void:
	var lower := ((center - radii) / WALK_CELL).floor()
	var upper := ((center + radii) / WALK_CELL).ceil()
	for y in range(maxi(0, int(lower.y)), mini(WALK_ROWS, int(upper.y) + 1)):
		for x in range(maxi(0, int(lower.x)), mini(WALK_COLS, int(upper.x) + 1)):
			if ((mask_center(x, y) - center) / radii).length_squared() <= 1.0:
				walkable[mask_index(x, y)] = 1

func _carve_capsule(a: Vector2, b: Vector2, radius: float) -> void:
	var lower := ((a.min(b) - Vector2.ONE * radius) / WALK_CELL).floor()
	var upper := ((a.max(b) + Vector2.ONE * radius) / WALK_CELL).ceil()
	for y in range(maxi(0, int(lower.y)), mini(WALK_ROWS, int(upper.y) + 1)):
		for x in range(maxi(0, int(lower.x)), mini(WALK_COLS, int(upper.x) + 1)):
			var p := mask_center(x, y)
			if p.distance_squared_to(Geometry2D.get_closest_point_to_segment(p, a, b)) <= radius * radius:
				walkable[mask_index(x, y)] = 1

static func index(x: int, y: int) -> int:
	return y * COLS + x

static func cell_center(x: int, y: int) -> Vector2:
	return Vector2((x + 0.5) * CELL, (y + 0.5) * CELL)

static func mask_index(x: int, y: int) -> int:
	return y * WALK_COLS + x

static func mask_center(x: int, y: int) -> Vector2:
	return Vector2((x + 0.5) * WALK_CELL, (y + 0.5) * WALK_CELL)

func is_mask_open(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < WALK_COLS and y < WALK_ROWS and walkable[mask_index(x, y)] == 1

func is_cell_open(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < COLS and y < ROWS and is_open(cell_center(x, y))

func is_open(p: Vector2) -> bool:
	return is_mask_open(floori(p.x / WALK_CELL), floori(p.y / WALK_CELL))

func fits(p: Vector2, radius: float = 2.3) -> bool:
	if not is_open(p):
		return false
	for i in range(8):
		if not is_open(p + Vector2.from_angle(i * TAU / 8.0) * radius):
			return false
	return true

func line_clear(a: Vector2, b: Vector2) -> bool:
	var x: int = floori(a.x / WALK_CELL)
	var y: int = floori(a.y / WALK_CELL)
	var end_x: int = floori(b.x / WALK_CELL)
	var end_y: int = floori(b.y / WALK_CELL)
	if not is_mask_open(x, y) or not is_mask_open(end_x, end_y):
		return false
	var delta := b - a
	var step_x: int = 1 if delta.x > 0 else -1
	var step_y: int = 1 if delta.y > 0 else -1
	var t_delta_x: float = WALK_CELL / absf(delta.x) if delta.x != 0 else INF
	var t_delta_y: float = WALK_CELL / absf(delta.y) if delta.y != 0 else INF
	var edge_x: float = (x + (1 if step_x > 0 else 0)) * WALK_CELL
	var edge_y: float = (y + (1 if step_y > 0 else 0)) * WALK_CELL
	var t_max_x: float = (edge_x - a.x) / delta.x if delta.x != 0 else INF
	var t_max_y: float = (edge_y - a.y) / delta.y if delta.y != 0 else INF
	while x != end_x or y != end_y:
		# A sample can lie exactly on a mask boundary. Stop at the endpoint
		# rather than stepping past it when travelling in a negative direction.
		if minf(t_max_x, t_max_y) >= 1.0 - 0.000001:
			return true
		if absf(t_max_x - t_max_y) < 0.000001:
			if not is_mask_open(x + step_x, y) or not is_mask_open(x, y + step_y):
				return false
			x += step_x
			y += step_y
			t_max_x += t_delta_x
			t_max_y += t_delta_y
		elif t_max_x < t_max_y:
			x += step_x
			t_max_x += t_delta_x
		else:
			y += step_y
			t_max_y += t_delta_y
		if not is_mask_open(x, y):
			return false
	return true

func add_food(p: Vector2, amount: int = 120) -> bool:
	if amount <= 0 or not fits(p, 4.0):
		return false
	for food in foods:
		if food.position.distance_to(p) < 18.0:
			food.amount += amount
			food.initial += amount
			return true
	foods.append({"position": p, "amount": amount, "initial": amount})
	return true

func make_texture() -> ImageTexture:
	var image := Image.create(int(WIDTH), int(HEIGHT), false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210 + kind
	for py in range(int(HEIGHT)):
		for px in range(int(WIDTH)):
			var color := Color("819e5d") if kind == Kind.OUTDOORS else Color("77583e")
			var noise: float = rng.randf_range(-0.023, 0.023)
			if kind == Kind.OUTDOORS:
				var patch: float = sin(px * 0.016 + sin(py * 0.009)) * 0.018 + cos(py * 0.018) * 0.012
				color += Color(patch, patch, patch * 0.5, 0)
				if rounded_distance(Vector2(px, py), Rect2(14, 14, WIDTH - 28, HEIGHT - 28), 45) > 0:
					color = Color("485c38")
			else:
				color = color.lerp(Color("5f4535"), float(py) / HEIGHT * 0.65)
				var layer: float = sin(py * 0.07 + sin(px * 0.01)) * 0.014
				color += Color(layer, layer * 0.65, layer * 0.4, 0)
			color += Color(noise, noise, noise, 0)
			color.a = clampf(0.5 - rounded_distance(Vector2(px + 0.5, py + 0.5), Rect2(0, 0, WIDTH, HEIGHT), 30), 0, 1)
			image.set_pixel(px, py, color)
	return ImageTexture.create_from_image(image)
