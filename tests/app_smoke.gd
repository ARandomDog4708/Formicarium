extends SceneTree
## Integration checks against the actual controls and both map viewports.
const MainScene = preload("res://main.tscn")
const Sim = preload("res://simulation/simulation.gd")
const Field = preload("res://simulation/pheromones.gd")
const WorldData = preload("res://simulation/world.gd")
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
	expect(app.sim.ants.size() == 10, "UI starts with exactly ten ants")
	expect(app.habitats.size() == 2 and app.habitats[0].world_id != app.habitats[1].world_id, "two viewports display independent maps")
	expect(app.selected_id == 0 and app.sim.ants[app.selected_id] != null, "initial inspector selection is valid for a ten-ant colony")
	expect(app.sim.worlds[Sim.COLONY].food_storage.amount == 0, "the colony storage shown in the UI starts empty")
	expect(app.sim.worlds[Sim.COLONY].chambers.size() == 1, "the colony view displays a single chamber")
	var time: float = app.sim.elapsed
	var hunger: float = app.sim.ants[0].hunger
	await physics_frame
	expect(app.sim.elapsed == time, "pause holds both maps at the same simulation time")
	expect(app.sim.ants[0].hunger == hunger, "pause also holds hunger meters")
	app._single_step()
	expect(is_equal_approx(app.sim.elapsed - time, Sim.FIXED_DT), "step advances both maps by one fixed tick")
	expect(is_equal_approx(app.sim.ants[0].hunger - hunger, 100 * Sim.FIXED_DT / app.sim.hunger_time), "single-step advances hunger by simulation time")
	app.sliders.hunger_time.value = 300
	app.sliders.hunger_threshold.value = 80
	expect(app.sim.hunger_time == 300 and app.sim.hunger_threshold == 80, "the hunger sliders update fill time and return threshold")
	app.sim.ants[0].hunger = 79
	app.sliders.hunger_threshold.value = 75
	app._single_step()
	expect(app.sim.ants[0].mode == Sim.Mode.SEEK_MEAL, "changing the hunger threshold sends an eligible worker back to eat")
	app.sliders.inner.value = 30
	app.sliders.outer.value = 36
	expect(app.sim.inner_radius < app.sim.outer_radius and app.sliders.inner.max_value == 28, "radius sliders preserve a nonempty sensing ring")
	app.sliders.angle.value = 90
	app.sliders.turn.value = 180
	app.sliders.decay.value = 8
	expect(app.sim.view_angle == 90 and app.sim.turn_rate == 180, "movement sliders update the actual model")
	expect(app.sim.fields[0].half_life == 8 and app.sim.fields[1].half_life == 8, "half-life control updates both fields")
	app._set_layer("show_home", false)
	expect(not app.habitats[0].show_home and not app.habitats[1].show_home, "home layer applies to both maps")
	app._set_layer("show_home", true)
	app._select_tool(1)
	app._on_habitat_click(Vector2(600, 700), false, Sim.COLONY)
	expect(app.sim.worlds[1].foods.is_empty(), "food tool rejects solid colony dirt")
	app._on_habitat_click(Vector2(200, 100), false, Sim.OUTDOORS)
	expect(app.sim.worlds[0].foods.size() == 3 and app.sim.worlds[1].foods.is_empty(), "food tool adds outdoor food only to that map")
	app._on_habitat_click(app.sim.worlds[1].food_storage.position, false, Sim.COLONY)
	expect(app.sim.worlds[1].foods.size() == 1, "food can also be placed inside walkable colony space")
	app._select_tool(2)
	app._on_habitat_click(Vector2(100, 100), false, Sim.OUTDOORS)
	app._on_habitat_click(Vector2(108, 100), true, Sim.OUTDOORS)
	app._on_habitat_click(app.sim.worlds[1].food_storage.position, true, Sim.COLONY)
	expect(app.sim.fields[0].food[WorldData.index(12, 12)] > 0 and app.sim.fields[0].home[WorldData.index(13, 12)] > 0, "scent brush keeps both outdoor pheromone channels")
	expect(app.sim.fields[1].home[WorldData.index(18, 17)] > 0, "scent brush addresses the clicked colony map")
	app.sim.clear_trails()
	expect(app.sim.fields[0].food.count(0.0) == app.sim.fields[0].food.size() and app.sim.fields[1].home.count(0.0) == app.sim.fields[1].home.size(), "clear trails clears both maps")
	app._select_tool(3)
	expect(app.tool_buttons.size() == 4 and app.tool_buttons[3].button_pressed, "ant placement is the fourth tool")
	app._on_habitat_click(Vector2(200, 100), false, Sim.OUTDOORS)
	expect(app.sim.ants.size() == 11 and app.sim.ants[app.selected_id].world_id == Sim.OUTDOORS, "ant tool places and inspects one outdoor worker")
	app._on_habitat_click(app.sim.worlds[1].food_storage.position, true, Sim.COLONY)
	expect(app.sim.ants.size() == 21 and app.sim.world_counts() == [11, 10], "Shift placement adds ten workers inside the colony")
	app._on_habitat_click(Vector2(600, 700), true, Sim.COLONY)
	expect(app.sim.ants.size() == 21, "ant brush rejects solid dirt")
	app._focus_view(Sim.COLONY)
	app._add_workers(10)
	expect(app.sim.ants.size() == 31 and app.sim.world_counts() == [11, 20], "quick-add button adds ten workers to the active map")
	expect(app.habitats[0].selected_id == app.selected_id and app.habitats[1].selected_id == app.selected_id, "selection is shared without duplicating workers")
	var point := Vector2(200, 220)
	var before: Vector2 = app.habitats[0].to_world(point)
	app.habitats[0].zoom_by(1.2, point)
	expect(before.is_equal_approx(app.habitats[0].to_world(point)), "zoom preserves the map point under the cursor")
	expect(app.habitats[1].zoom == 1.0, "zooming outdoors does not zoom the colony")
	app._fit_views()
	expect(app.habitats[0].zoom == 1.0 and app.habitats[1].zoom == 1.0, "fit restores both maps")
	app._reset()
	expect(app.sim.ants.size() == 10 and app.sim.world_counts() == [10, 0], "reset restores exactly ten initial workers")
	expect(app.selected_id == 0 and app.habitats[1].selected_id == 0, "reset restores a valid shared selection")
	expect(app.sim.outer_radius == 82 and app.sim.inner_radius == 9, "reset restores both sensing radii")
	expect(app.sim.view_angle == 150 and app.sim.turn_rate == 720 and app.sim.fields[1].half_life == 32, "reset restores movement and both fields' decay defaults")
	expect(app.sim.hunger_time == 180 and app.sim.hunger_threshold == 65 and app.sliders.hunger_time.value == 180 and app.sliders.hunger_threshold.value == 65, "reset restores both hunger settings and controls")
	expect(app.sim.ants[0].hunger == 0, "reset starts the workers fed again")
	expect(app.sim.worlds[0].foods.size() == 2 and app.sim.worlds[1].foods.is_empty() and app.sim.elapsed == 0, "reset restores original food in the correct maps")
	expect(app.paused, "reset preserves pause state")
	app._set_rate(4)
	expect(app.rate == 4 and app.rate_buttons[2].button_pressed, "speed control selects four fixed steps")
	var selected = app.sim.ants[app.selected_id]
	selected.position = app.sim.worlds[0].portal
	selected.portal_cooldown = 0
	app.sim._try_transfer(selected)
	await process_frame
	expect(app.sim.ants[app.selected_id].world_id == Sim.COLONY and app.habitats[0].selected_id == app.habitats[1].selected_id, "the inspector follows a selected worker through the entrance")
	selected.carrying = true
	selected.mode = Sim.Mode.RETURN_FOOD
	selected.position = app.sim.worlds[Sim.COLONY].food_storage.position
	app._single_step()
	await process_frame
	expect(app.sim.worlds[Sim.COLONY].food_storage.amount == 1 and app.sim.delivered == 1 and not selected.carrying, "single-step unloads a carrier into the storage displayed by the app")
	app.sim.clear_trails()
	expect(app.sim.stored_food == 1 and app.sim.delivered == 1, "the clear-trails control leaves food stored")
	selected.hunger = app.sim.hunger_threshold
	app._single_step()
	await process_frame
	expect(selected.hunger == 0 and selected.meals == 1 and app.sim.stored_food == 0 and app.sim.delivered == 1, "the app consumes a stored unit for a hungry selected ant")
	app._reset()
	expect(app.sim.worlds[Sim.COLONY].food_storage.amount == 0 and app.sim.delivered == 0, "reset clears stored provisions as well as the worker state")
	for unit in range(15):
		app.sim.worlds[Sim.COLONY].store_food(app.sim.worlds[Sim.COLONY].food_storage.position)
	await physics_frame
	expect(app.sim.ants.size() == 10 and app.sim.births == 0 and app.sim.stored_food == 15, "pause holds automatic reproduction even when enough food is stored")
	app._single_step()
	await process_frame
	expect(app.sim.ants.size() == 11 and app.sim.births == 1 and app.sim.stored_food == 0 and app.sim.birth_cost() == 17, "stepping produces one worker and updates the population and next cost")
	app._select_ant(app.sim.ants[-1].id)
	await process_frame
	expect(app.habitats[0].selected_id == 10 and app.habitats[1].selected_id == 10 and app.sim.ants[10].hunger == 0, "a born worker can be selected in the shared inspector")
	app._reset()
	app.sim.worlds[Sim.OUTDOORS].add_food(Vector2(200, 100), 6)
	app.sim.ants[0].position = Vector2(200, 100)
	app._single_step()
	await process_frame
	expect(app.sim.worlds[Sim.OUTDOORS].foods.size() == 4 and app.sim.food_sources_spawned == 1, "single-step replaces a low source in the outdoor map shown by the app")
	app._reset()
	expect(app.sim.ants.size() == 10 and app.selected_id == 0 and app.sim.births == 0 and app.sim.food_for_growth == 0 and app.sim.food_sources_spawned == 0 and app.sim.worlds[Sim.OUTDOORS].foods.size() == 2, "reset clears automatic births, food costs and replacement sources")
	app._toggle_help()
	expect(app.help_panel.visible, "guide opens")
	app._toggle_help()
	expect(not app.help_panel.visible, "guide closes")
	print("%d application checks; %d failures" % [checks, failures])
	app.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
