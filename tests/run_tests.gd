extends SceneTree
const WorldData = preload("res://simulation/world.gd")
const Field = preload("res://simulation/pheromones.gd")
const Sim = preload("res://simulation/simulation.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	_test_sensing()
	_test_walls()
	_test_motion_and_modes()
	_test_determinism()
	_test_colony()
	print("%d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _open_world():
	var world := WorldData.new()
	world.walkable.fill(1)
	return world

func _test_sensing() -> void:
	var world = _open_world()
	var field := Field.new(world)
	var p := Vector2(204, 300)
	var target := Vector2(244, 300)
	field.deposit(target, Field.Kind.FOOD, 1.0)
	var result: Dictionary = field.sense(p, 0, Field.Kind.FOOD, 9, 82, deg_to_rad(75), 37, 32)
	var expected: float = 1.06 * 37.0 / (1.0 + 40.0 / 32.0)
	expect(is_equal_approx(result.force.x, expected) and absf(result.force.y) < 0.001, "unit vector and distance falloff match the specified equation")
	expect(result.count == 1, "one eligible food sample")
	expect(field.sense(p, PI, Field.Kind.FOOD, 9, 82, deg_to_rad(75), 37, 32).count == 0, "behind-facing pheromone excluded")
	expect(field.sense(p, 0, Field.Kind.HOME, 9, 82, deg_to_rad(75), 37, 32).count == 0, "other pheromone channel excluded")
	expect(field.sense(p, 0, Field.Kind.FOOD, 41, 82, deg_to_rad(75), 37, 32).count == 0, "inner exclusion radius")
	expect(field.sense(p, 0, Field.Kind.FOOD, 9, 39, deg_to_rad(75), 37, 32).count == 0, "outer radius")
	field.deposit(p, Field.Kind.FOOD, 5.0)
	expect(field.sense(p, 0, Field.Kind.FOOD, 0, 82, deg_to_rad(75), 37, 32).count == 1, "zero-distance point is safe and excluded")
	field.deposit(Vector2(236, 292), Field.Kind.FOOD, 5)
	field.deposit(Vector2(236, 308), Field.Kind.FOOD, 5)
	expect(field.sense(p, 0, Field.Kind.FOOD, 9, 82, deg_to_rad(75), 37, 32).force.length() <= 37.0001, "sum is capped at ant speed")
	var before: float = field.food[WorldData.index(30, 37)]
	field.decay(field.half_life)
	expect(is_equal_approx(field.food[WorldData.index(30, 37)], before * 0.5), "half-life decay is time based")
	field.clear()
	expect(field.active_count == 0 and field.food.count(0.0) == field.food.size(), "clear removes all pheromones")

func _test_walls() -> void:
	var world = _open_world()
	var field := Field.new(world)
	var a := Vector2(204, 300)
	var b := Vector2(244, 300)
	world.walkable[WorldData.index(28, 37)] = 0
	expect(not world.line_clear(a, b) and not world.line_clear(b, a), "wall blocks sight in both directions")
	field.deposit(b, Field.Kind.FOOD, 4)
	expect(field.sense(a, 0, Field.Kind.FOOD, 9, 82, PI / 2, 37, 32).count == 0, "pheromone cannot attract through a wall")
	world.walkable[WorldData.index(28, 37)] = 1
	expect(field.sense(a, 0, Field.Kind.FOOD, 9, 82, PI / 2, 37, 32).count == 1, "opening restores attraction")
	world.walkable[WorldData.index(26, 25)] = 0
	world.walkable[WorldData.index(25, 26)] = 0
	expect(not world.line_clear(Vector2(204, 204), Vector2(220, 220)), "diagonal corner cannot leak pheromone sight")
	expect(not world.is_open(Vector2(-0.1, 200)), "negative world coordinates are solid")
	expect(not world.line_clear(Vector2(-4, 200), a), "out-of-bounds line is blocked")
	var default_world := WorldData.new()
	expect(default_world.is_open(default_world.home), "nest is walkable")
	expect(not default_world.add_food(Vector2(40, 500)), "food cannot be placed in dirt")

func _test_motion_and_modes() -> void:
	var sim := Sim.new(1)
	sim.world.walkable.fill(1)
	sim.world.foods.clear()
	var ant = sim.ants[0]
	ant.position = Vector2(204, 300)
	ant.heading = 0
	ant.wander_angle = 0
	ant.wander_clock = 100
	ant.sense_clock = -100
	ant.explore_time = 0.0
	var start: Vector2 = ant.position
	sim.step()
	expect(ant.position.is_equal_approx(start + ant.velocity * Sim.FIXED_DT), "position follows explicit Euler")
	expect(ant.mode == Sim.Mode.EXPLORE, "exploration is a distinct mode")
	sim.trails.deposit(Vector2(244, 300), Field.Kind.FOOD, 1)
	sim._sense(ant)
	expect(ant.mode == Sim.Mode.FOLLOW_FOOD, "explorer switches on detecting food scent")
	ant.mode = Sim.Mode.EXPLORE
	ant.explore_time = 2.0
	sim._sense(ant)
	expect(ant.mode == Sim.Mode.EXPLORE and ant.sense_count == 0, "exploration interval is independent of nearby food trails")
	ant.mode = Sim.Mode.FOLLOW_FOOD
	ant.following_time = 41
	sim.step()
	expect(ant.mode == Sim.Mode.EXPLORE, "an unproductive trail eventually gives way to exploration")
	sim.world.add_food(ant.position, 1)
	sim._interact(ant)
	expect(ant.mode == Sim.Mode.RETURN_HOME and ant.carrying and sim.pickups == 1, "food pickup switches to return-home mode")
	expect(sim.world.foods[0].amount == 0, "food pickup consumes one unit")
	ant.position = sim.world.home
	sim._interact(ant)
	expect(ant.mode == Sim.Mode.EXPLORE and not ant.carrying and sim.delivered == 1, "delivery switches back to exploring")
	var turn: float = Sim.turn_toward(deg_to_rad(179), deg_to_rad(-179), deg_to_rad(1))
	expect(absf(angle_difference(deg_to_rad(179), turn)) <= deg_to_rad(1) + 0.00001, "turning uses shortest wrapped angle and respects cap")
	sim._reverse(ant)
	var before: float = ant.heading
	sim._move(ant, Sim.FIXED_DT)
	expect(absf(angle_difference(before, ant.heading)) <= deg_to_rad(sim.turn_rate) * Sim.FIXED_DT + 0.00001, "food turnaround also respects turn cap")

func _test_determinism() -> void:
	var a := Sim.new(8, 99)
	var b := Sim.new(8, 99)
	for i in range(180):
		a.step()
		b.step()
	for i in range(a.ants.size()):
		expect(a.ants[i].position == b.ants[i].position and a.ants[i].heading == b.ants[i].heading, "seeded simulation repeats exactly")

func _test_colony() -> void:
	var sim := Sim.new()
	var collision_ok: bool = true
	var speed_ok: bool = true
	var turning_ok: bool = true
	var finite_ok: bool = true
	var previous_headings := PackedFloat32Array()
	previous_headings.resize(sim.ants.size())
	var start_time: int = Time.get_ticks_msec()
	for tick in range(60 * 180):
		for i in range(sim.ants.size()):
			previous_headings[i] = sim.ants[i].heading
		sim.step()
		for ant in sim.ants:
			if absf(angle_difference(previous_headings[ant.id], ant.heading)) > deg_to_rad(sim.turn_rate) * Sim.FIXED_DT + 0.00001:
				turning_ok = false
		if tick % 60 == 0:
			for ant in sim.ants:
				collision_ok = collision_ok and sim.world.fits(ant.position)
				speed_ok = speed_ok and ant.velocity.length() <= sim.speed + 0.001
				finite_ok = finite_ok and ant.position.is_finite() and ant.velocity.is_finite()
		if tick % 3600 == 3599:
			print("Colony at %.0fs: %d picked up; %d delivered; modes %s" % [sim.elapsed, sim.pickups, sim.delivered, str(sim.mode_counts())])
	expect(collision_ok, "all ants stay in walkable space during a three-minute simulation")
	expect(speed_ok, "colony speed never exceeds cap")
	expect(turning_ok, "colony turn rate never exceeds cap")
	expect(finite_ok, "colony positions and velocities remain finite")
	expect(sim.pickups > 0, "colony discovers food without seeded trails")
	expect(sim.delivered > 0, "colony returns food to the underground nest")
	var remaining: int = 0
	var carrying: int = 0
	for food in sim.world.foods:
		remaining += food.amount
	for ant in sim.ants:
		carrying += 1 if ant.carrying else 0
	expect(remaining + carrying + sim.delivered == 440, "food is conserved across piles, carrying and delivery")
	print("Three simulated minutes completed in %.2fs real time" % ((Time.get_ticks_msec() - start_time) / 1000.0))
