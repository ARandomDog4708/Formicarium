extends Control
## The view never advances simulation state.
const Sim = preload("res://simulation/simulation.gd")
const WorldData = preload("res://simulation/world.gd")
const Field = preload("res://simulation/pheromones.gd")
signal ant_selected(id: int)
signal habitat_clicked(position: Vector2, shift: bool)
signal view_changed

var sim: Sim
var selected_id: int = 36
var show_home: bool = true
var show_food: bool = true
var show_sensors: bool = true
var tool: int = 0
var zoom: float = 1.0
var pan := Vector2.ZERO
var terrain: ImageTexture
var small_font: SystemFont
var decorations: Array[Vector3] = []
var dragging: bool = false
var painting: bool = false
var hover := Vector2(-100, -100)

func _ready() -> void:
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	small_font = SystemFont.new()
	small_font.font_names = PackedStringArray(["DejaVu Sans", "Arial", "Helvetica", "Liberation Sans", "Noto Sans"])
	terrain = sim.world.make_texture()
	var rng := RandomNumberGenerator.new()
	rng.seed = 291
	for i in range(620):
		var p := Vector2(rng.randf_range(8, 1192), rng.randf_range(205, 709))
		if not sim.world.is_open(p):
			decorations.append(Vector3(p.x, p.y, rng.randf_range(0.7, 2.4)))

func base_scale() -> float:
	return minf(size.x / WorldData.WIDTH, size.y / WorldData.HEIGHT)

func origin() -> Vector2:
	return (size - Vector2(WorldData.WIDTH, WorldData.HEIGHT) * base_scale() * zoom) * 0.5 + pan

func to_world(p: Vector2) -> Vector2:
	return (p - origin()) / (base_scale() * zoom)

func reset_view() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	view_changed.emit()

func zoom_by(factor: float, at: Vector2 = Vector2(-1, -1)) -> void:
	if at.x < 0:
		at = size * 0.5
	var before := to_world(at)
	zoom = clampf(zoom * factor, 1.0, 3.0)
	pan += at - (origin() + before * base_scale() * zoom)
	if zoom == 1.0:
		pan = Vector2.ZERO
	view_changed.emit()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		hover = event.position
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_by(1.15, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_by(1.0 / 1.15, event.position)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT:
			painting = event.pressed and tool == 2
			if event.pressed:
				var point := to_world(event.position)
				if tool == 0:
					var closest: float = 28.0 / (base_scale() * zoom)
					for ant in sim.ants:
						var d: float = point.distance_to(ant.position)
						if d < closest:
							closest = d
							selected_id = ant.id
					ant_selected.emit(selected_id)
				else:
					habitat_clicked.emit(point, event.shift_pressed)
		accept_event()
	elif event is InputEventMouseMotion:
		hover = event.position
		if dragging:
			pan += event.relative
		if painting and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			var start := to_world(event.position - event.relative)
			var finish := to_world(event.position)
			var samples: int = maxi(1, ceili(start.distance_to(finish) / (WorldData.CELL * 0.5)))
			for i in range(1, samples + 1):
				habitat_clicked.emit(start.lerp(finish, float(i) / samples), event.shift_pressed)
		queue_redraw()

func _draw() -> void:
	if sim == null or terrain == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("bfcab4"))
	var scale_factor: float = base_scale() * zoom
	draw_set_transform(origin(), 0, Vector2.ONE * scale_factor)
	draw_texture_rect(terrain, Rect2(0, 0, WorldData.WIDTH, WorldData.HEIGHT), false)
	_draw_landscape()
	for speck in decorations:
		draw_circle(Vector2(speck.x, speck.y), speck.z, Color(0.28, 0.20, 0.14, 0.2))
	for chamber in sim.world.chambers:
		var label_pos: Vector2 = chamber.center + Vector2(-chamber.radii.x * 0.65, chamber.radii.y + 25)
		draw_string(small_font, label_pos, chamber.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("d1b58e"))
	_draw_nest()
	if show_home or show_food:
		for y in range(WorldData.ROWS):
			for x in range(WorldData.COLS):
				var i := WorldData.index(x, y)
				var p := WorldData.cell_center(x, y)
				var home_value: float = sim.trails.home[i]
				var food_value: float = sim.trails.food[i]
				if show_home and home_value > Field.MIN_STRENGTH:
					draw_circle(p, 2.0 + minf(home_value, 2) * 0.65, Color(0.34, 0.69, 0.78, minf(0.67, home_value * 0.36)))
				if show_food and food_value > Field.MIN_STRENGTH:
					draw_circle(p + Vector2(1, 1), 2.0 + minf(food_value, 2) * 0.65, Color(0.98, 0.64, 0.28, minf(0.72, food_value * 0.4)))
	_draw_food()
	if show_sensors and selected_id >= 0 and selected_id < sim.ants.size():
		_draw_sensor(sim.ants[selected_id])
	for ant in sim.ants:
		_draw_ant(ant)
	if selected_id >= 0 and selected_id < sim.ants.size():
		var selected = sim.ants[selected_id]
		draw_arc(selected.position, 11, 0, TAU, 40, Color("f0f1ce"), 1.2, true)
		draw_circle(selected.position + Vector2(12, -13), 2.2, Color("f0f1ce"))
	if tool != 0 and Rect2(Vector2.ZERO, size).has_point(hover):
		var cursor := to_world(hover)
		var valid: bool = sim.world.fits(cursor, 4.0)
		draw_arc(cursor, 15.0, 0, TAU, 36, Color("f1f2d8") if valid else Color("d57563"), 1.5, true)
		draw_line(cursor - Vector2(5, 0), cursor + Vector2(5, 0), Color("f1f2d8"), 1)
		draw_line(cursor - Vector2(0, 5), cursor + Vector2(0, 5), Color("f1f2d8"), 1)
	draw_set_transform(Vector2.ZERO)

func _draw_landscape() -> void:
	# All landscape details are decorative; the occupancy texture is authoritative.
	for x in range(12, 1190, 11):
		var ground: float = WorldData.surface_y(x)
		var height: float = 3.0 + fmod(float(x) * 1.71, 7.0)
		draw_line(Vector2(x, ground - 1), Vector2(x - 2, ground - height), Color("77865b"), 1.0, true)
		if x % 3 == 0:
			draw_line(Vector2(x + 3, ground), Vector2(x + 6, ground - height * 0.65), Color("899263"), 1.0, true)
	for plant_x in [66, 115, 321, 814, 1065, 1124]:
		var ground: float = WorldData.surface_y(plant_x)
		var base := Vector2(plant_x, ground - 1)
		draw_line(base, base + Vector2(0, -22), Color("6b7c53"), 1.6, true)
		for j in range(3):
			var p := base + Vector2(0, -6 - j * 6)
			draw_line(p, p + Vector2(-7 + j, -5), Color("7e8f60"), 3, true)
			draw_line(p, p + Vector2(8 - j, -4), Color("7e8f60"), 3, true)
	draw_string(small_font, Vector2(31, 40), "SURFACE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("67745b"))
	draw_string(small_font, Vector2(549, 108), "ENTRANCE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("657459"))
	draw_line(Vector2(545, 112), Vector2(530, 126), Color(0.36, 0.42, 0.3, 0.5), 1, true)
	for depth in [100, 200, 300, 400, 500]:
		var y: float = 180 + depth
		draw_line(Vector2(1177, y), Vector2(1188, y), Color(0.9, 0.79, 0.62, 0.5), 1)
		draw_string(small_font, Vector2(1138, y + 4), str(depth), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("c6a780"))

func _draw_nest() -> void:
	var center: Vector2 = sim.world.home
	draw_circle(center, 24, Color(0.93, 0.83, 0.58, 0.12))
	draw_arc(center, 24, 0, TAU, 40, Color(0.88, 0.82, 0.60, 0.43), 1, true)
	for j in range(9):
		var p := center + Vector2(-14 + j % 3 * 11, -10 + int(j / 3.0) * 9)
		_ellipse(p, Vector2(4.1, 2.7), Color("e6d8ad"))
	draw_string(small_font, center + Vector2(-24, -35), "COLONY", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("6c5b3f"))

func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(20):
		points.append(center + Vector2.from_angle(float(i) * TAU / 20.0) * radii)
	draw_colored_polygon(points, color)

func _draw_food() -> void:
	for food in sim.world.foods:
		if food.amount <= 0:
			continue
		var p: Vector2 = food.position
		draw_circle(p, 19, Color(0.62, 0.76, 0.37, 0.16))
		var crumbs: int = mini(13, maxi(3, ceili(food.amount / 24.0)))
		for i in range(crumbs):
			var angle: float = float(i) * 2.399
			var offset := Vector2(cos(angle) * 10, sin(angle) * 6) * sqrt(float(i) / crumbs)
			_ellipse(p + offset, Vector2(3.6, 2.6), Color("657d44").lerp(Color("bad487"), float(i % 3) / 2.0))
		draw_string(small_font, p + Vector2(-25, -27), "FOOD · " + str(food.amount), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("536943"))

func _draw_sensor(ant) -> void:
	var half: float = deg_to_rad(sim.view_angle * 0.5)
	var points := PackedVector2Array()
	for i in range(33):
		var angle: float = ant.heading - half + 2.0 * half * float(i) / 32.0
		points.append(ant.position + Vector2.from_angle(angle) * sim.outer_radius)
	for i in range(32, -1, -1):
		var angle: float = ant.heading - half + 2.0 * half * float(i) / 32.0
		points.append(ant.position + Vector2.from_angle(angle) * sim.inner_radius)
	draw_colored_polygon(points, Color(0.7, 0.91, 0.83, 0.09))
	points.append(points[0])
	draw_polyline(points, Color(0.82, 0.96, 0.86, 0.55), 0.9, true)
	var kind: int = Field.Kind.HOME if ant.carrying else Field.Kind.FOOD
	var sensed: Dictionary = sim.trails.sense(ant.position, ant.heading, kind, sim.inner_radius, sim.outer_radius, half, sim.speed, sim.falloff, true)
	var visible: PackedVector2Array = sensed.visible
	for i in range(mini(visible.size(), 22)):
		draw_line(ant.position, visible[i], Color(0.95, 0.96, 0.76, 0.16), 0.7, true)
	var tip: Vector2 = ant.position + Vector2.from_angle(ant.heading) * 23
	draw_line(ant.position, tip, Color("f1edb4"), 1.1, true)
	draw_circle(tip, 1.8, Color("f1edb4"))

func _draw_ant(ant) -> void:
	var p: Vector2 = ant.position
	var facing: float = ant.heading
	var body := Color("32382a")
	var tint := Color("a9bd7e") if ant.mode == Sim.Mode.EXPLORE else Color("dc9b50")
	if ant.carrying:
		tint = Color("90bed0")
	var phase: float = ant.age * 23.0 + ant.id * 1.7
	for i in range(3):
		for side in [-1.0, 1.0]:
			var anchor := Vector2(float(i - 1) * 2, side)
			var knee := Vector2(float(i - 1) * 3.3 + sin(phase + i * 2.0) * 1.2, side * 3.7)
			var foot := knee + Vector2(-2 + i * 1.6, side * 2.5)
			draw_line(p + anchor.rotated(facing), p + knee.rotated(facing), body, 0.9, true)
			draw_line(p + knee.rotated(facing), p + foot.rotated(facing), body, 0.75, true)
	draw_ellipse_rotated(p + Vector2(-4, 0).rotated(facing), Vector2(3.6, 2.6), facing, body)
	draw_circle(p, 1.9, body)
	draw_circle(p + Vector2(3.7, 0).rotated(facing), 2.1, body)
	draw_line(p + Vector2(-4.7, -1).rotated(facing), p + Vector2(-4.7, 1).rotated(facing), tint, 1.3, true)
	for side in [-1, 1]:
		draw_line(p + Vector2(4, side).rotated(facing), p + Vector2(7, side * 3.5).rotated(facing), body, 0.8, true)
	if ant.carrying:
		draw_circle(p + Vector2(7, 0).rotated(facing), 2.1, Color("c4dc8a"))

func draw_ellipse_rotated(center: Vector2, radii: Vector2, angle: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(14):
		points.append(center + (Vector2.from_angle(float(i) * TAU / 14.0) * radii).rotated(angle))
	draw_colored_polygon(points, color)
