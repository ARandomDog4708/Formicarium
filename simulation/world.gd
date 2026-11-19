extends RefCounted
## The same binary occupancy map drives drawing, collision and line of sight.
## There is no gravity or platforming: every open cell is equally walkable.

const CELL: float = 8.0
const COLS: int = 150
const ROWS: int = 90
const WIDTH: float = COLS * CELL
const HEIGHT: float = ROWS * CELL

var walkable := PackedByteArray()
var home := Vector2(440, 326)
var chambers: Array[Dictionary] = []
var tunnels: Array[Dictionary] = []
var foods: Array[Dictionary] = []

func _init() -> void:
	chambers = [
		{"center": Vector2(440, 326), "radii": Vector2(96, 57), "name": "NEST CHAMBER"},
		{"center": Vector2(230, 490), "radii": Vector2(99, 52), "name": "WEST GALLERY"},
		{"center": Vector2(750, 410), "radii": Vector2(104, 53), "name": "EAST GALLERY"},
		{"center": Vector2(520, 600), "radii": Vector2(118, 48), "name": "LOWER CHAMBER"},
	]
	_add_tunnel([Vector2(523, 118), Vector2(536, 200), Vector2(503, 252), Vector2(464, 294)], 19.0)
	_add_tunnel([Vector2(410, 356), Vector2(358, 407), Vector2(286, 449), Vector2(248, 476)], 18.0)
	_add_tunnel([Vector2(483, 353), Vector2(578, 404), Vector2(664, 422), Vector2(720, 413)], 18.0)
	_add_tunnel([Vector2(231, 518), Vector2(278, 567), Vector2(386, 606), Vector2(448, 600)], 17.0)
	_add_tunnel([Vector2(761, 444), Vector2(767, 518), Vector2(701, 572), Vector2(605, 600)], 17.0)
	walkable.resize(COLS * ROWS)
	for y in range(ROWS):
		for x in range(COLS):
			var p := cell_center(x, y)
			var ground := surface_y(p.x)
			var open: bool = p.y >= ground - 30.0 and p.y <= ground + 5.0
			for chamber in chambers:
				if ((p - chamber.center) / chamber.radii).length_squared() <= 1.0:
					open = true
			for tunnel in tunnels:
				if p.distance_to(Geometry2D.get_closest_point_to_segment(p, tunnel.a, tunnel.b)) <= tunnel.radius:
					open = true
			walkable[index(x, y)] = 1 if open and x > 1 and x < COLS - 2 else 0
	add_food(Vector2(171, surface_y(171) - 13), 180)
	add_food(Vector2(976, surface_y(976) - 13), 260)

func _add_tunnel(points: Array, radius: float) -> void:
	for i in range(points.size() - 1):
		tunnels.append({"a": points[i], "b": points[i + 1], "radius": radius})

static func surface_y(x: float) -> float:
	return 180.0 - 49.0 * exp(-pow((x - 523.0) / 100.0, 2.0)) + 3.0 * sin(x / 92.0)

static func index(x: int, y: int) -> int:
	return y * COLS + x

static func cell_center(x: int, y: int) -> Vector2:
	return Vector2((x + 0.5) * CELL, (y + 0.5) * CELL)

func is_cell_open(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < COLS and y < ROWS and walkable[index(x, y)] == 1

func is_open(p: Vector2) -> bool:
	return is_cell_open(floori(p.x / CELL), floori(p.y / CELL))

func fits(p: Vector2, radius: float = 2.3) -> bool:
	return is_open(p) and is_open(p + Vector2(radius, 0)) and is_open(p - Vector2(radius, 0)) and is_open(p + Vector2(0, radius)) and is_open(p - Vector2(0, radius))

func line_clear(a: Vector2, b: Vector2) -> bool:
	# Supercover grid traversal: also checks both side cells at an exact corner.
	# A diagonal sight line cannot leak through two touching solid cells.
	var x: int = floori(a.x / CELL)
	var y: int = floori(a.y / CELL)
	var end_x: int = floori(b.x / CELL)
	var end_y: int = floori(b.y / CELL)
	if not is_cell_open(x, y) or not is_cell_open(end_x, end_y):
		return false
	var delta := b - a
	var step_x: int = 1 if delta.x > 0 else -1
	var step_y: int = 1 if delta.y > 0 else -1
	var t_delta_x: float = CELL / absf(delta.x) if delta.x != 0 else INF
	var t_delta_y: float = CELL / absf(delta.y) if delta.y != 0 else INF
	var edge_x: float = (x + (1 if step_x > 0 else 0)) * CELL
	var edge_y: float = (y + (1 if step_y > 0 else 0)) * CELL
	var t_max_x: float = (edge_x - a.x) / delta.x if delta.x != 0 else INF
	var t_max_y: float = (edge_y - a.y) / delta.y if delta.y != 0 else INF
	while x != end_x or y != end_y:
		if absf(t_max_x - t_max_y) < 0.000001:
			if not is_cell_open(x + step_x, y) or not is_cell_open(x, y + step_y):
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
		if not is_cell_open(x, y):
			return false
	return true

func add_food(p: Vector2, amount: int = 120) -> bool:
	if not fits(p, 4.0):
		return false
	for food in foods:
		if food.position.distance_to(p) < 18.0:
			food.amount += amount
			food.initial += amount
			return true
	foods.append({"position": p, "amount": amount, "initial": amount})
	return true

func make_texture() -> ImageTexture:
	# Seeded procedural terrain: no external assets, and no hidden collision map.
	var image := Image.create(int(WIDTH), int(HEIGHT), false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for py in range(int(HEIGHT)):
		for px in range(int(WIDTH)):
			var ground := surface_y(float(px))
			var depth: float = clampf((py - ground) / 550.0, 0, 1)
			var color := Color("d8d9bf")
			var noise: float = rng.randf_range(-0.019, 0.019)
			if py >= ground:
				color = Color("a77e53").lerp(Color("77513d"), depth)
				var layer: float = sin(py * 0.064 + sin(px * 0.006) * 0.8) * 0.013
				color += Color(layer, layer * 0.65, layer * 0.4, 0)
				if is_open(Vector2(px, py)):
					color = Color("caaa79").lerp(Color("b58b60"), depth)
					if not is_open(Vector2(px, py - 3)):
						color = color.lightened(0.08)
				elif is_open(Vector2(px, py + 3)):
					color = color.darkened(0.18)
			elif py > ground - 4:
				color = Color("829064")
			else:
				color = color.lerp(Color("becbb5"), 1.0 - float(py) / 190.0)
			color += Color(noise, noise, noise, 0)
			image.set_pixel(px, py, color)
	return ImageTexture.create_from_image(image)
