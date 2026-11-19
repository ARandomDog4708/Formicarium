extends SceneTree
## Integration checks against the actual application controls and model.
const MainScene = preload("res://main.tscn")
const Sim = preload("res://simulation/simulation.gd")
const Field = preload("res://simulation/pheromones.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	var app = MainScene.instantiate()
	root.add_child(app)
	app._set_paused(true)
	await process_frame
	var time: float = app.sim.elapsed
	await physics_frame
	expect(app.sim.elapsed == time, "pause holds simulation time")
	app._single_step()
	expect(is_equal_approx(app.sim.elapsed - time, Sim.FIXED_DT), "step advances exactly one fixed tick")
	app.sliders.inner.value = 30
	app.sliders.outer.value = 36
	expect(app.sim.inner_radius < app.sim.outer_radius and app.sliders.inner.max_value == 28, "radius sliders preserve a nonempty sensing ring")
	app.sliders.angle.value = 90
	app.sliders.turn.value = 180
	app.sliders.decay.value = 8
	expect(app.sim.view_angle == 90 and app.sim.turn_rate == 180 and app.sim.trails.half_life == 8, "sliders update the actual simulation")
	var food_count: int = app.sim.world.foods.size()
	app._select_tool(1)
	app._on_habitat_click(Vector2(40, 500), false)
	expect(app.sim.world.foods.size() == food_count, "food tool rejects solid dirt")
	app._on_habitat_click(Vector2(750, 162), false)
	expect(app.sim.world.foods.size() == food_count + 1, "food tool adds a pile in walkable space")
	app._select_tool(2)
	app._on_habitat_click(Vector2(748, 412), false)
	app._on_habitat_click(Vector2(756, 412), true)
	var food_index: int = 51 * 150 + 93
	var home_index: int = 51 * 150 + 94
	expect(app.sim.trails.food[food_index] > 0 and app.sim.trails.home[home_index] > 0, "brush uses food and Shift-home channels")
	app.habitat.size = Vector2(1014, 608.4)
	var point := Vector2(290, 220)
	var before: Vector2 = app.habitat.to_world(point)
	app.habitat.zoom_by(1.2, point)
	expect(before.is_equal_approx(app.habitat.to_world(point)), "zoom preserves the world point under the cursor")
	app.habitat.reset_view()
	expect(app.habitat.zoom == 1.0 and app.habitat.pan == Vector2.ZERO, "fit restores the complete map")
	app._reset()
	expect(app.sim.outer_radius == 82 and app.sim.inner_radius == 9, "reset restores both sensing radii after slider edits")
	expect(app.sim.view_angle == 150 and app.sim.turn_rate == 720 and app.sim.trails.half_life == 32, "reset restores movement and decay defaults")
	expect(app.sim.world.foods.size() == 2 and app.sim.elapsed == 0 and app.sim.delivered == 0, "reset restores colony and original food")
	expect(app.paused, "reset preserves pause state")
	app._set_rate(4)
	expect(app.rate == 4 and app.rate_buttons[2].button_pressed, "speed control selects four fixed steps")
	app._toggle_help()
	expect(app.help_panel.visible, "guide opens")
	app._toggle_help()
	expect(not app.help_panel.visible, "guide closes")
	print("%d application checks; %d failures" % [checks, failures])
	app.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
