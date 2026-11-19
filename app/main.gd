extends Control
const Sim = preload("res://simulation/simulation.gd")
const Habitat = preload("res://app/habitat.gd")
const Field = preload("res://simulation/pheromones.gd")
const BG := Color("101a16")
const PANEL := Color("18231d")
const LINE := Color("2c3c31")
const TEXT := Color("e5edda")
const MUTED := Color("899b88")
const GREEN := Color("b9d695")
const BLUE := Color("85bed0")
const AMBER := Color("e9ae67")

var sim: Sim
var habitat: Habitat
var regular: SystemFont
var bold: SystemFont
var mono: SystemFont
var paused: bool = false
var rate: int = 1
var selected_id: int = 36
var tool: int = 0
var pause_button: Button
var step_button: Button
var tool_buttons: Array[Button] = []
var rate_buttons: Array[Button] = []
var sliders: Dictionary = {}
var notice: String = ""
var notice_time: float = 0.0
var help_visible: bool = false
var help_panel: PanelContainer
var capture_path: String = ""
var capture_at: float = 0.0
var capturing: bool = false
var notice_label: Label

func _ready() -> void:
	regular = SystemFont.new()
	regular.font_names = PackedStringArray(["DejaVu Sans", "Arial", "Helvetica", "Liberation Sans", "Noto Sans"])
	bold = SystemFont.new()
	bold.font_names = regular.font_names
	bold.font_weight = 700
	mono = SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Consolas", "Menlo", "Liberation Mono"])
	theme = _make_theme()
	sim = Sim.new()
	habitat = Habitat.new()
	habitat.sim = sim
	habitat.position = Vector2(88, 218)
	habitat.size = Vector2(1014, 608.4)
	habitat.ant_selected.connect(func(id: int): selected_id = id)
	habitat.habitat_clicked.connect(_on_habitat_click)
	add_child(habitat)
	_build_controls()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--at="):
			capture_at = float(arg.trim_prefix("--at="))
		elif arg == "--paused":
			_set_paused(true)
	queue_redraw()

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = regular
	t.default_font_size = 12
	for type in ["Button", "CheckBox", "Label"]:
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, GREEN)
		t.set_color("font_pressed_color", type, BG)
	t.set_stylebox("normal", "Button", _style(Color("223027"), LINE, 7))
	t.set_stylebox("hover", "Button", _style(Color("304333"), Color("58734b"), 7))
	t.set_stylebox("pressed", "Button", _style(GREEN, GREEN, 7))
	t.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), Color("b9d695"), 7))
	t.set_stylebox("disabled", "Button", _style(Color("172019"), Color("263329"), 7))
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		t.set_stylebox(state, "CheckBox", _style(Color.TRANSPARENT, Color.TRANSPARENT, 0))
	t.set_color("font_pressed_color", "CheckBox", TEXT)
	t.set_color("font_hover_pressed_color", "CheckBox", GREEN)
	t.set_color("font_disabled_color", "Button", Color("50604f"))
	var track := _style(Color("344537"), Color(0, 0, 0, 0), 3)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	var fill := _style(Color("a7c88b"), Color(0, 0, 0, 0), 3)
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var image := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	for y in range(14):
		for x in range(14):
			image.set_pixel(x, y, GREEN if Vector2(x - 6.5, y - 6.5).length() < 5.5 else Color.TRANSPARENT)
	var grabber := ImageTexture.create_from_image(image)
	t.set_icon("grabber", "HSlider", grabber)
	t.set_icon("grabber_highlight", "HSlider", grabber)
	return t

func _style(fill: Color, border: Color = Color.TRANSPARENT, radius: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	return s

func _button(text: String, rect: Rect2, action: Callable, tooltip: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	add_child(button)
	return button

func _build_controls() -> void:
	_button("Reset colony", Rect2(1262, 25, 144, 36), _reset, "Restart with the same seed [R]")
	_button("?", Rect2(1216, 25, 34, 36), _toggle_help, "Controls and simulation rules [H]")
	for i in range(3):
		var texts := ["01", "02", "03"]
		var tips := ["Inspect a worker [1]", "Place food on walkable ground [2]", "Paint food pheromone; hold Shift for home pheromone [3]"]
		var b := _button(texts[i], Rect2(15, 231 + i * 62, 43, 43), _select_tool.bind(i), tips[i])
		b.toggle_mode = true
		tool_buttons.append(b)
	_select_tool(0)
	pause_button = _button("Ⅱ  Pause", Rect2(88, 840, 110, 34), func(): _set_paused(not paused), "Pause / resume [Space]")
	step_button = _button("Step", Rect2(206, 840, 60, 34), _single_step, "Advance one 1/60 second tick while paused [N]")
	step_button.disabled = true
	for i in range(3):
		var value: int = [1, 2, 4][i]
		var b := _button(str(value) + "×", Rect2(288 + i * 46, 840, 42, 34), _set_rate.bind(value), "Simulation speed")
		b.toggle_mode = true
		rate_buttons.append(b)
	_set_rate(1)
	_button("Clear trails", Rect2(458, 840, 106, 34), func(): sim.trails.clear(); _notify("Pheromones cleared"), "Remove every trail; local sources resume emitting")
	_button("−", Rect2(931, 840, 34, 34), func(): habitat.zoom_by(1.0 / 1.2), "Zoom out [mouse wheel]")
	_button("+", Rect2(971, 840, 34, 34), func(): habitat.zoom_by(1.2), "Zoom in [mouse wheel]")
	_button("Fit", Rect2(1013, 840, 88, 34), func(): habitat.reset_view(), "Reset zoom and pan [0]")
	_slider("outer", 414, 36, 140, sim.outer_radius, 1, func(v: float):
		sim.outer_radius = v
		sliders.inner.max_value = minf(32, v - 8)
		sim.inner_radius = sliders.inner.value)
	_slider("inner", 472, 2, 32, sim.inner_radius, 1, func(v: float): sim.inner_radius = v)
	_slider("angle", 530, 45, 180, sim.view_angle, 5, func(v: float): sim.view_angle = v)
	_slider("turn", 588, 90, 1080, sim.turn_rate, 30, func(v: float): sim.turn_rate = v)
	_slider("decay", 646, 8, 90, sim.trails.half_life, 1, func(v: float): sim.trails.half_life = v)
	_check("Home trails", Vector2(1145, 725), true, func(v: bool): habitat.show_home = v)
	_check("Food trails", Vector2(1275, 725), true, func(v: bool): habitat.show_food = v)
	_check("Selected ant's sensing cone", Vector2(1145, 760), true, func(v: bool): habitat.show_sensors = v)
	notice_label = Label.new()
	notice_label.position = Vector2(335, 778)
	notice_label.size = Vector2(510, 35)
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notice_label.add_theme_stylebox_override("normal", _style(Color("203328"), Color("6d865b"), 7))
	notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_label.visible = false
	add_child(notice_label)
	_build_help()

func _slider(key: String, y: float, minimum: float, maximum: float, value: float, increment: float, action: Callable) -> void:
	var slider := HSlider.new()
	slider.position = Vector2(1147, y)
	slider.size = Vector2(236, 24)
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = increment
	slider.value = value
	slider.value_changed.connect(action)
	slider.tooltip_text = {"outer": "Maximum sensing distance", "inner": "Pheromones this close exert no attraction", "angle": "Total forward sensing angle", "turn": "Maximum heading change in degrees per second", "decay": "Seconds until a pheromone loses half its strength"}[key]
	sliders[key] = slider
	add_child(slider)

func _check(text: String, pos: Vector2, checked: bool, action: Callable) -> void:
	var check := CheckBox.new()
	check.text = text
	check.position = pos
	check.add_theme_font_size_override("font_size", 11)
	check.button_pressed = checked
	check.focus_mode = Control.FOCUS_NONE
	check.toggled.connect(action)
	add_child(check)

func _build_help() -> void:
	help_panel = PanelContainer.new()
	help_panel.position = Vector2(358, 200)
	help_panel.size = Vector2(660, 480)
	help_panel.add_theme_stylebox_override("panel", _style(Color("213127"), Color("66815b"), 12))
	help_panel.visible = false
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	help_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	var title := Label.new()
	title.text = "A small colony. Local rules."
	title.add_theme_font_size_override("font_size", 23)
	column.add_child(title)
	var body := Label.new()
	body.text = "Space     Pause / resume\nN             Single fixed step when paused\n1 / 2 / 3   Inspect / place food / paint pheromones\nShift         Paint home pheromone instead of food\nWheel      Zoom around the pointer\nMiddle     Drag to pan the habitat\n0 / R        Fit view / reset colony\nH / Esc    Toggle / close this guide\n\nAnts sense only their selected pheromone type, inside a\nforward ring sector. Dirt blocks movement and scent.\nExplorers lay home trails; returning workers lay food trails.\nPheromones evaporate. Nothing directs ants through walls."
	body.add_theme_font_size_override("font_size", 13)
	body.add_theme_color_override("font_color", TEXT)
	column.add_child(body)
	var close := Button.new()
	close.text = "Back to the colony"
	close.pressed.connect(_toggle_help)
	column.add_child(close)
	add_child(help_panel)

func _physics_process(_delta: float) -> void:
	if not paused:
		for i in range(rate):
			sim.step()

func _process(delta: float) -> void:
	notice_time = maxf(0, notice_time - delta)
	notice_label.visible = notice_time > 0
	habitat.queue_redraw()
	queue_redraw()
	if not capture_path.is_empty() and not capturing and sim.elapsed >= capture_at:
		capturing = true
		_capture()

func _capture() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(capture_path)
	print("Screenshot saved: " + capture_path)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE: _set_paused(not paused)
		KEY_N: _single_step()
		KEY_1: _select_tool(0)
		KEY_2: _select_tool(1)
		KEY_3: _select_tool(2)
		KEY_0: habitat.reset_view()
		KEY_R: _reset()
		KEY_H: _toggle_help()
		KEY_ESCAPE:
			if help_panel.visible:
				_toggle_help()
			else:
				_select_tool(0)

func _select_tool(value: int) -> void:
	tool = value
	if habitat != null:
		habitat.tool = value
	for i in range(tool_buttons.size()):
		tool_buttons[i].set_pressed_no_signal(i == value)

func _set_paused(value: bool) -> void:
	paused = value
	pause_button.text = "▶  Resume" if paused else "Ⅱ  Pause"
	step_button.disabled = not paused

func _single_step() -> void:
	if paused:
		sim.step()

func _set_rate(value: int) -> void:
	rate = value
	for i in range(rate_buttons.size()):
		rate_buttons[i].set_pressed_no_signal([1, 2, 4][i] == value)

func _toggle_help() -> void:
	help_panel.visible = not help_panel.visible

func _notify(message: String) -> void:
	notice = message
	notice_time = 3.0
	notice_label.text = message

func _on_habitat_click(point: Vector2, shift: bool) -> void:
	if tool == 1:
		if sim.world.add_food(point):
			_notify("Food placed · 120 units")
		else:
			_notify("Choose walkable ground")
	elif tool == 2 and sim.world.is_open(point):
		sim.trails.deposit(point, Field.Kind.HOME if shift else Field.Kind.FOOD, 3.0)

func _reset() -> void:
	sim = Sim.new()
	habitat.sim = sim
	selected_id = 36
	habitat.selected_id = selected_id
	# Reset controls without letting their callbacks overwrite the new defaults.
	sliders.inner.max_value = 32.0
	sliders.outer.set_value_no_signal(sim.outer_radius)
	sliders.inner.set_value_no_signal(sim.inner_radius)
	sliders.angle.set_value_no_signal(sim.view_angle)
	sliders.turn.set_value_no_signal(sim.turn_rate)
	sliders.decay.set_value_no_signal(sim.trails.half_life)
	_notify("Colony reset · seed 1847")

func _text(p: Vector2, text: String, font_size: int = 12, color: Color = TEXT, font: Font = null) -> void:
	draw_string(regular if font == null else font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _panel(rect: Rect2, color: Color = PANEL, radius: int = 10) -> void:
	draw_style_box(_style(color, LINE, radius), rect)

func _draw() -> void:
	if sim == null:
		return
	draw_rect(Rect2(0, 0, 1440, 900), BG)
	draw_line(Vector2(72, 82), Vector2(72, 900), LINE, 1)
	draw_line(Vector2(0, 82), Vector2(1440, 82), LINE, 1)
	_draw_brand()
	_text(Vector2(90, 40), "FORMICARIUM", 21, TEXT, bold)
	_text(Vector2(91, 61), "An ant colony, one small decision at a time.", 11, MUTED)
	draw_circle(Vector2(1024, 43), 3, GREEN)
	_text(Vector2(1036, 47), "DESKTOP LAB", 11, MUTED, mono)
	_text(Vector2(1154, 47), "v0.1", 11, MUTED, mono)
	_draw_stats()
	_text(Vector2(88, 200), "HABITAT", 12, TEXT, bold)
	_text(Vector2(166, 200), "/  SIDE CUTAWAY", 11, MUTED, mono)
	var counts := sim.mode_counts()
	_legend(Vector2(704, 196), GREEN, "Explore " + str(counts[0]))
	_legend(Vector2(833, 196), AMBER, "Follow " + str(counts[1]))
	_legend(Vector2(947, 196), BLUE, "Return " + str(counts[2]))
	_panel(Rect2(84, 214, 1022, 616), Color("253226"), 6)
	# Habitat is a child control, drawn over this backing.
	_draw_toolbar()
	_draw_inspector()
	_text(Vector2(593, 862), str(roundi(habitat.zoom * 100)) + "%", 11, MUTED, mono)
	var instructions: String = ["Click a worker to inspect", "Click walkable ground to place food", "Drag to lay food scent · Shift for home scent"][tool]
	_text(Vector2(88, 894), instructions + "   ·   Wheel to zoom / middle-drag to pan", 10, MUTED)
	draw_circle(Vector2(1146, 864), 3, GREEN if not paused else AMBER)
	_text(Vector2(1158, 868), "PAUSED" if paused else "SIMULATION LIVE", 10, MUTED, mono)
	_text(Vector2(1145, 890), "EULER  ·  FIXED Δt 1/60 s", 10, Color("627a63"), mono)

func _draw_brand() -> void:
	draw_circle(Vector2(35, 30), 5, GREEN)
	draw_circle(Vector2(35, 42), 3.5, GREEN)
	draw_circle(Vector2(35, 56), 7, GREEN)
	for side in [-1, 1]:
		draw_line(Vector2(35, 36), Vector2(35 + side * 12, 29), GREEN, 1.6, true)
		draw_line(Vector2(35, 43), Vector2(35 + side * 14, 43), GREEN, 1.6, true)
		draw_line(Vector2(35, 50), Vector2(35 + side * 12, 62), GREEN, 1.6, true)
		draw_line(Vector2(35 + side * 3, 26), Vector2(35 + side * 7, 18), GREEN, 1.3, true)

func _draw_stats() -> void:
	var counts := sim.mode_counts()
	var titles := ["COLONY POPULATION", "FOOD DELIVERED", "RETURNING WORKERS", "SIMULATION TIME"]
	var values := [str(sim.ants.size()), str(sim.delivered), str(counts[2]), _clock(sim.elapsed)]
	for i in range(4):
		var x: float = 88 + i * 258
		_panel(Rect2(x, 100, 242, 73), PANEL, 8)
		_text(Vector2(x + 15, 120), titles[i], 9, MUTED, mono)
		_text(Vector2(x + 15, 151), values[i], 26 if i != 3 else 23, TEXT, bold if i != 3 else mono)
		if i == 3:
			_text(Vector2(x + 133, 151), str(rate) + "×", 11, GREEN, mono)
		else:
			_text(Vector2(x + 76, 147), ["workers", "units", "workers"][i], 10, MUTED)

static func _clock(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]

func _legend(pos: Vector2, color: Color, label: String) -> void:
	draw_circle(pos, 3.2, color)
	_text(pos + Vector2(10, 4), label, 10, MUTED)

func _draw_toolbar() -> void:
	_text(Vector2(20, 198), "TOOLS", 9, MUTED, mono)
	for i in range(3):
		_text(Vector2(14, 288 + i * 62), ["INSPECT", "FOOD", "SCENT"][i], 8, GREEN if i == tool else MUTED, mono)
	_text(Vector2(23, 853), "2D", 11, MUTED, mono)
	draw_line(Vector2(23, 819), Vector2(49, 819), LINE, 1)

func _draw_inspector() -> void:
	_panel(Rect2(1126, 100, 280, 730), PANEL, 10)
	_text(Vector2(1146, 125), "WORKER INSPECTOR", 10, MUTED, mono)
	var ant = sim.ants[selected_id]
	_text(Vector2(1146, 161), "Ant %03d" % (ant.id + 1), 25, TEXT, bold)
	var mode_color: Color = [GREEN, AMBER, BLUE][ant.mode]
	draw_circle(Vector2(1150, 183), 3, mode_color)
	_text(Vector2(1160, 187), Sim.MODE_NAMES[ant.mode], 11, mode_color)
	_draw_large_ant(Vector2(1259, 242), mode_color, ant.carrying)
	_text(Vector2(1146, 288), "SPEED", 9, MUTED, mono)
	_text(Vector2(1274, 288), "SENSED POINTS", 9, MUTED, mono)
	_text(Vector2(1146, 309), "%.1f" % ant.velocity.length() + " u/s", 15, TEXT, mono)
	_text(Vector2(1274, 309), str(ant.sense_count), 15, TEXT, mono)
	_text(Vector2(1146, 337), "x %04d   y %04d" % [roundi(ant.position.x), roundi(ant.position.y)], 10, MUTED, mono)
	draw_line(Vector2(1146, 357), Vector2(1384, 357), LINE, 1)
	_text(Vector2(1146, 383), "MOVEMENT & SENSING", 10, TEXT, bold)
	var labels := ["Outer sensing radius", "Inner exclusion radius", "Forward sensing angle", "Maximum turn rate", "Pheromone half-life"]
	var values := [str(roundi(sim.outer_radius)) + " u", str(roundi(sim.inner_radius)) + " u", str(roundi(sim.view_angle)) + "°", str(roundi(sim.turn_rate)) + "°/s", str(roundi(sim.trails.half_life)) + " s"]
	for i in range(5):
		var y: float = 408 + i * 58
		_text(Vector2(1147, y), labels[i], 11, MUTED)
		var width: float = mono.get_string_size(values[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		_text(Vector2(1383 - width, y), values[i], 11, GREEN, mono)
	draw_line(Vector2(1146, 698), Vector2(1384, 698), LINE, 1)
	_text(Vector2(1146, 719), "VISIBLE LAYERS", 10, TEXT, bold)
	_text(Vector2(1147, 809), "Scent is blocked by solid ground.", 10, MUTED)

func _draw_large_ant(center: Vector2, color: Color, carrying: bool) -> void:
	for i in range(3):
		for side in [-1, 1]:
			var anchor := center + Vector2(-5 + i * 8, side * 3)
			var knee := center + Vector2(-15 + i * 15, side * 13)
			var foot := knee + Vector2(-8 + i * 7, side * 8)
			draw_line(anchor, knee, color.darkened(0.2), 1.4, true)
			draw_line(knee, foot, color.darkened(0.2), 1.4, true)
	_ellipse(center + Vector2(-22, 0), Vector2(15, 10), color)
	draw_circle(center, 7, color)
	draw_circle(center + Vector2(18, 0), 8, color)
	for side in [-1, 1]:
		draw_line(center + Vector2(22, side * 4), center + Vector2(35, side * 12), color, 1.4, true)
	draw_line(center + Vector2(-27, -7), center + Vector2(-27, 7), PANEL, 1.4, true)
	if carrying:
		draw_circle(center + Vector2(35, 0), 4, GREEN)

func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(30):
		points.append(center + Vector2.from_angle(float(i) * TAU / 30.0) * radii)
	draw_colored_polygon(points, color)
