extends Control
## One viewport for one independent map; no simulation state is advanced here.
const Sim = preload("res://simulation/simulation.gd")
const WorldData = preload("res://simulation/world.gd")
const Field = preload("res://simulation/pheromones.gd")
signal ant_selected(id: int)
signal habitat_clicked(position: Vector2, shift: bool, location: int)
signal activated(location: int)

var sim: Sim
var world_id: int = Sim.OUTDOORS
var selected_id: int = 0
var inspection: Dictionary = {}
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
	mouse_exited.connect(_clear_hover)
	small_font = SystemFont.new()
	small_font.font_names = PackedStringArray(["DejaVu Sans", "Arial", "Helvetica", "Liberation Sans", "Noto Sans"])
	terrain = sim.worlds[world_id].make_texture()
	var rng := RandomNumberGenerator.new()
	rng.seed = 291 + world_id
	for i in range(340):
		decorations.append(Vector3(rng.randf_range(25, WorldData.WIDTH - 25), rng.randf_range(25, WorldData.HEIGHT - 25), rng.randf_range(0.6, 2.4)))

func _clear_hover() -> void:
	hover = Vector2(-100, -100)
	dragging = false
	painting = false
	queue_redraw()

func base_scale() -> float:
	return minf(size.x / WorldData.WIDTH, size.y / WorldData.HEIGHT)

func origin() -> Vector2:
	return (size - Vector2(WorldData.WIDTH, WorldData.HEIGHT) * base_scale() * zoom) * 0.5 + pan

func to_world(p: Vector2) -> Vector2:
	return (p - origin()) / (base_scale() * zoom)

func reset_view() -> void:
	zoom = 1.0
	pan = Vector2.ZERO

func zoom_by(factor: float, at: Vector2 = Vector2(-1, -1)) -> void:
	if at.x < 0:
		at = size * 0.5
	var before := to_world(at)
	zoom = clampf(zoom * factor, 1.0, 3.0)
	pan += at - (origin() + before * base_scale() * zoom)
	if zoom == 1.0:
		pan = Vector2.ZERO

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		hover = event.position
		activated.emit(world_id)
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
					var closest: float = 22.0 / (base_scale() * zoom)
					var found: int = -1
					for ant in sim.ants:
						if ant.world_id != world_id:
							continue
						var d: float = point.distance_to(ant.position)
						if d < closest:
							closest = d
							found = ant.id
					if found >= 0:
						ant_selected.emit(found)
				else:
					habitat_clicked.emit(point, event.shift_pressed, world_id)
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
				habitat_clicked.emit(start.lerp(finish, float(i) / samples), event.shift_pressed, world_id)
		queue_redraw()

func _draw() -> void:
	if sim == null or terrain == null:
		return
	var world: WorldData = sim.worlds[world_id]
	draw_rect(Rect2(Vector2.ZERO, size), Color("18231d"))
	var scale_factor: float = base_scale() * zoom
	draw_set_transform(origin(), 0, Vector2.ONE * scale_factor)
	draw_texture_rect(terrain, Rect2(0, 0, WorldData.WIDTH, WorldData.HEIGHT), false)
	if world_id == Sim.OUTDOORS:
		_draw_outdoors(world)
	else:
		_draw_colony(world)
	var field: Field = sim.fields[world_id]
	if show_home or show_food:
		for y in range(WorldData.ROWS):
			for x in range(WorldData.COLS):
				var i := WorldData.index(x, y)
				var p := WorldData.cell_center(x, y)
				var home_value: float = field.home[i]
				var food_value: float = field.food[i]
				if show_home and home_value > Field.MIN_STRENGTH:
					draw_circle(p, 2.1 + minf(home_value, 2) * 0.45, Color(0.34, 0.72, 0.85, minf(0.65, home_value * 0.36)))
				if show_food and food_value > Field.MIN_STRENGTH:
					draw_circle(p + Vector2(1, 1), 2.1 + minf(food_value, 2) * 0.45, Color(1, 0.65, 0.28, minf(0.72, food_value * 0.4)))
	_draw_food(world)
	_draw_portal(world)
	if world_id == Sim.COLONY:
		_draw_storage(world)
	if selected_id >= 0 and selected_id < sim.ants.size():
		var selected = sim.ants[selected_id]
		if show_sensors:
			if selected.world_id == world_id:
				_draw_sensor(selected, world)
			else:
				var remote: PackedVector2Array = inspection.get("remote_visible", PackedVector2Array())
				for point in remote:
					draw_arc(point, 4.0, 0, TAU, 12, Color("f0edb4"), 0.8, true)
	for ant in sim.ants:
		if ant.world_id == world_id:
			_draw_ant(ant)
	if selected_id >= 0 and selected_id < sim.ants.size():
		var selected = sim.ants[selected_id]
		if selected.world_id == world_id:
			draw_arc(selected.position, 11, 0, TAU, 40, Color("f0f1ce"), 1.2, true)
	if tool != 0 and Rect2(Vector2.ZERO, size).has_point(hover):
		var cursor := to_world(hover)
		var valid: bool = world.fits(cursor, 4.0)
		draw_arc(cursor, 15.0, 0, TAU, 36, Color("f1f2d8") if valid else Color("e6806e"), 1.5, true)
		draw_line(cursor - Vector2(5, 0), cursor + Vector2(5, 0), Color("f1f2d8"), 1)
		draw_line(cursor - Vector2(0, 5), cursor + Vector2(0, 5), Color("f1f2d8"), 1)
	draw_set_transform(Vector2.ZERO)

func _draw_outdoors(world: WorldData) -> void:
	for item in decorations:
		var p := Vector2(item.x, item.y)
		if world.is_open(p) and p.distance_to(world.portal) > 43:
			var tint := Color(0.22, 0.36, 0.18, 0.30)
			draw_line(p, p + Vector2(-2, -item.z * 2), tint, 0.8, true)
			draw_line(p + Vector2(1, 0), p + Vector2(3, -item.z * 1.8), tint, 0.8, true)
	for rock in world.rocks:
		_ellipse(rock.center + Vector2(2, 4), rock.radii + Vector2(3, 2), Color(0.16, 0.24, 0.13, 0.28))
		_ellipse(rock.center, rock.radii, Color("999782"))
		_ellipse(rock.center + Vector2(-4, -5), rock.radii * Vector2(0.7, 0.55), Color("aaa792"))

func _draw_colony(world: WorldData) -> void:
	# Draw the whole union's shadow first, then its fill: no internal seams.
	for border in [3.0, 0.0]:
		var tint := Color("493b2c") if border > 0 else Color("c4a579")
		for path in world.paths:
			var points: PackedVector2Array = path.points
			var radius: float = path.radius + border
			draw_polyline(points, tint, radius * 2.0, true)
			for point in points:
				draw_circle(point, radius, tint, true, -1, true)
		for chamber in world.chambers:
			_ellipse(chamber.center, chamber.radii + Vector2.ONE * border, tint)
	for item in decorations:
		var p := Vector2(item.x, item.y)
		if not world.is_open(p):
			draw_circle(p, item.z, Color(0.21, 0.15, 0.10, 0.20))
	for chamber in world.chambers:
		draw_string(small_font, chamber.center + Vector2(-chamber.radii.x * 0.75, chamber.radii.y + 22), chamber.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("cfb18b"))

func _draw_portal(world: WorldData) -> void:
	var p: Vector2 = world.portal
	if world_id == Sim.OUTDOORS:
		_ellipse(p + Vector2(0, 4), Vector2(36, 27), Color(0.21, 0.29, 0.12, 0.26))
		_ellipse(p, Vector2(30, 24), Color("b3a16d"))
		_ellipse(p, Vector2(18, 14), Color("1a2117"))
		_ellipse(p + Vector2(-1, -2), Vector2(13, 9), Color("0f1711"))
		draw_string(small_font, p + Vector2(-53, 47), "ANTHILL ENTRANCE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("dbe4ba"))
	else:
		draw_circle(p, 13, Color("24271c"), true, -1, true)
		draw_string(small_font, p + Vector2(27, 5), "TO SURFACE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e1cfab"))
	if sim.elapsed - sim.last_transfer_time < 0.65:
		var radius: float = 20.0 + (sim.elapsed - sim.last_transfer_time) * 16.0
		draw_arc(p, radius, 0, TAU, 40, Color(0.85, 0.96, 0.70, 0.65), 1.3, true)

func _draw_storage(world: WorldData) -> void:
	var storage = world.food_storage
	var center: Vector2 = storage.position
	_ellipse(center + Vector2(0, 3), Vector2(34, 24), Color(0.40, 0.32, 0.18, 0.16))
	draw_arc(center, storage.radius, 0, TAU, 48, Color("8d794a"), 1.2, true)
	if storage.amount == 0:
		draw_line(center + Vector2(-9, 0), center + Vector2(9, 0), Color("9c8759"), 1.0, true)
	else:
		for i in range(mini(storage.amount, 30)):
			var angle: float = i * 2.399
			var offset := Vector2(cos(angle) * 1.2, sin(angle) * 0.7) * sqrt(float(i)) * 3.4
			_ellipse(center + offset + Vector2(1, 2), Vector2(4.3, 3.1), Color(0.28, 0.35, 0.15, 0.3))
			_ellipse(center + offset, Vector2(4, 2.9), Color("698044").lerp(Color("d2e592"), float(i % 4) / 3.0))
	var label: String = "%d UNITS" % storage.amount
	var width: float = small_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(small_font, center + Vector2(-width * 0.5, -33), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("5a4a2d"))

func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(64):
		points.append(center + Vector2.from_angle(float(i) * TAU / 64.0) * radii)
	draw_colored_polygon(points, color)
	points.append(points[0])
	draw_polyline(points, color, 1.0, true)

func _draw_food(world: WorldData) -> void:
	for food in world.foods:
		if food.amount <= 0:
			continue
		var p: Vector2 = food.position
		draw_circle(p, 19, Color(0.62, 0.76, 0.37, 0.16))
		var crumbs: int = mini(13, maxi(3, ceili(food.amount / 24.0)))
		for i in range(crumbs):
			var angle: float = float(i) * 2.399
			var offset := Vector2(cos(angle) * 10, sin(angle) * 6) * sqrt(float(i) / crumbs)
			_ellipse(p + offset, Vector2(3.6, 2.6), Color("657d44").lerp(Color("c9df88"), float(i % 3) / 2.0))
		draw_string(small_font, p + Vector2(-25, -27), "FOOD · " + str(food.amount), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e5e9bf") if world_id == Sim.OUTDOORS else Color("675638"))

func _draw_sensor(ant, world: WorldData) -> void:
	var half: float = deg_to_rad(sim.view_angle * 0.5)
	var points := PackedVector2Array()
	for i in range(33):
		points.append(ant.position + Vector2.from_angle(ant.heading - half + 2.0 * half * float(i) / 32.0) * sim.outer_radius)
	for i in range(32, -1, -1):
		points.append(ant.position + Vector2.from_angle(ant.heading - half + 2.0 * half * float(i) / 32.0) * sim.inner_radius)
	draw_colored_polygon(points, Color(0.7, 0.91, 0.83, 0.09))
	points.append(points[0])
	draw_polyline(points, Color(0.82, 0.96, 0.86, 0.55), 0.9, true)
	var visible: PackedVector2Array = inspection.get("visible", PackedVector2Array())
	for i in range(mini(visible.size(), 22)):
		draw_line(ant.position, visible[i], Color(0.95, 0.96, 0.76, 0.20), 0.7, true)
	if int(inspection.get("portal_count", 0)) > 0:
		draw_dashed_line(ant.position, world.portal, Color("dbe9ba"), 1.5, 4.0, true)
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
