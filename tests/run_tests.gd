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
	_test_population()
	_test_portal_sensing()
	_test_transfers()
	_test_food_storage()
	_test_hunger()
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
	_set_tile(world, 28, 37, 0)
	expect(not world.line_clear(a, b) and not world.line_clear(b, a), "wall blocks sight in both directions")
	field.deposit(b, Field.Kind.FOOD, 4)
	expect(field.sense(a, 0, Field.Kind.FOOD, 9, 82, PI / 2, 37, 32).count == 0, "pheromone cannot attract through a wall")
	_set_tile(world, 28, 37, 1)
	expect(field.sense(a, 0, Field.Kind.FOOD, 9, 82, PI / 2, 37, 32).count == 1, "opening restores attraction")
	world.walkable[WorldData.mask_index(101, 100)] = 0
	world.walkable[WorldData.mask_index(100, 101)] = 0
	expect(not world.line_clear(Vector2(201, 201), Vector2(205, 205)), "diagonal corner cannot leak pheromone sight")
	expect(not world.is_open(Vector2(-0.1, 200)), "negative world coordinates are solid")
	expect(not world.line_clear(Vector2(-4, 200), a), "out-of-bounds line is blocked")
	world.walkable.fill(1)
	for endpoint in [Vector2(348, 372), Vector2(372, 348), Vector2(330, 328), Vector2(350, 328), Vector2(328, 350)]:
		expect(world.line_clear(Vector2(350, 350), endpoint) and world.line_clear(endpoint, Vector2(350, 350)), "open sight lines ending on grid boundaries are symmetric")
	var default_world := WorldData.new(WorldData.Kind.COLONY)
	expect(default_world.is_open(default_world.food_storage.position), "nest is walkable")
	expect(not default_world.add_food(Vector2(40, 500)), "food cannot be placed in dirt")

func _test_motion_and_modes() -> void:
	var sim := Sim.new(1)
	sim.worlds[Sim.OUTDOORS].walkable.fill(1)
	sim.worlds[Sim.OUTDOORS].foods.clear()
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
	sim.fields[Sim.OUTDOORS].deposit(Vector2(244, 300), Field.Kind.FOOD, 1)
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
	sim.worlds[Sim.OUTDOORS].add_food(ant.position, 1)
	sim._interact(ant)
	expect(ant.mode == Sim.Mode.RETURN_FOOD and ant.carrying and sim.pickups == 1, "food pickup switches to returning-food mode")
	expect(sim.worlds[Sim.OUTDOORS].foods[0].amount == 0, "food pickup consumes one unit")
	ant.world_id = Sim.COLONY
	ant.position = sim.worlds[Sim.COLONY].food_storage.position
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
	var hunger_ok: bool = true
	var previous_worlds := PackedInt32Array()
	previous_worlds.resize(sim.ants.size())
	var previous_headings := PackedFloat32Array()
	previous_headings.resize(sim.ants.size())
	var start_time: int = Time.get_ticks_msec()
	for tick in range(60 * 180):
		for i in range(sim.ants.size()):
			previous_headings[i] = sim.ants[i].heading
			previous_worlds[i] = sim.ants[i].world_id
		sim.step()
		for ant in sim.ants:
			if previous_worlds[ant.id] == ant.world_id and absf(angle_difference(previous_headings[ant.id], ant.heading)) > deg_to_rad(sim.turn_rate) * Sim.FIXED_DT + 0.00001:
				turning_ok = false
		if tick % 60 == 0:
			for ant in sim.ants:
				collision_ok = collision_ok and sim.worlds[ant.world_id].fits(ant.position)
				speed_ok = speed_ok and ant.velocity.length() <= sim.speed + 0.001
				finite_ok = finite_ok and ant.position.is_finite() and ant.velocity.is_finite()
				hunger_ok = hunger_ok and is_finite(ant.hunger) and ant.hunger >= 0 and ant.hunger <= 100
		if tick % 3600 == 3599:
			print("Colony at %.0fs: %d picked up; %d delivered; %d stored; %d meals; modes %s" % [sim.elapsed, sim.pickups, sim.delivered, sim.stored_food, sim.meals_eaten, str(sim.mode_counts())])
	expect(collision_ok, "all ants stay in walkable space during a three-minute simulation")
	expect(speed_ok, "colony speed never exceeds cap")
	expect(turning_ok, "colony turn rate never exceeds cap")
	expect(finite_ok, "colony positions and velocities remain finite")
	expect(hunger_ok, "every ant's hunger remains finite and within its meter")
	expect(sim.transfers > 0, "workers travel through the entrance between independent maps")
	expect(sim.ants.size() == 10, "the population remains ten without manual additions")
	expect(sim.pickups > 0, "colony discovers food without seeded trails")
	expect(sim.delivered > 0, "colony returns food to underground storage")
	expect(sim.meals_eaten > 0, "hungry workers eat from storage in the autonomous colony")
	var remaining: int = 0
	var carrying: int = 0
	for world in sim.worlds:
		for food in world.foods:
			remaining += food.amount
	for ant in sim.ants:
		carrying += 1 if ant.carrying else 0
	expect(remaining + carrying + sim.stored_food + sim.meals_eaten == 440, "food is conserved across piles, carrying, storage and consumed meals")
	expect(sim.delivered == sim.stored_food + sim.meals_eaten, "deliveries account for both remaining provisions and eaten food")
	print("Three simulated minutes completed in %.2fs real time" % ((Time.get_ticks_msec() - start_time) / 1000.0))

func _set_tile(world, x: int, y: int, value: int) -> void:
	var scale: int = int(WorldData.CELL / WorldData.WALK_CELL)
	for my in range(y * scale, (y + 1) * scale):
		for mx in range(x * scale, (x + 1) * scale):
			world.walkable[WorldData.mask_index(mx, my)] = value

func _test_population() -> void:
	var sim := Sim.new()
	expect(sim.ants.size() == 10 and sim.world_counts() == [10, 0], "ten initial workers start outside the mound")
	expect(sim.worlds[0] != sim.worlds[1] and sim.fields[0] != sim.fields[1], "maps and pheromone fields are separate objects")
	expect(sim.worlds[0].foods.size() == 2 and sim.worlds[1].foods.is_empty(), "food piles belong to the outdoor map")
	expect(sim.worlds[0].is_open(Vector2(100, 100)) and sim.worlds[0].is_open(Vector2(540, 650)), "outdoor land is walkable across both dimensions")
	expect(not sim.worlds[0].is_open(Vector2(16, 16)), "rounded outdoor corners block ants")
	expect(not sim.worlds[0].fits(sim.worlds[0].rocks[0].center), "rendered rocks block movement")
	expect(sim.add_ants(Vector2(100, 100), Sim.OUTDOORS, 1) == 1, "place one ant outdoors")
	expect(sim.add_ants(sim.worlds[1].food_storage.position, Sim.COLONY, 10) == 10, "place ten ants inside the colony")
	expect(sim.ants.size() == 21 and sim.world_counts() == [11, 10], "population and per-map counts include added workers")
	var identifiers: Dictionary = {}
	for ant in sim.ants:
		identifiers[ant.id] = true
	expect(identifiers.size() == 21 and sim.ants[-1].id == 20, "placed ants have unique stable identifiers")
	expect(sim.add_ants(Vector2(600, 700), Sim.COLONY, 3) == 0 and sim.ants.size() == 21, "ant placement rejects solid dirt")
	expect(sim.add_ant(Vector2(100, 100), -1) == null, "invalid map identifiers are rejected")
	sim.fields[0].deposit(Vector2(100, 100), Field.Kind.FOOD, 2)
	expect(sim.fields[1].food.count(0.0) == sim.fields[1].food.size(), "a deposit never appears at the same coordinates in the other map")
	sim.set_half_life(12)
	expect(sim.fields[0].half_life == 12 and sim.fields[1].half_life == 12, "half-life applies to both maps")
	sim.clear_trails()
	expect(sim.fields[0].food.count(0.0) == sim.fields[0].food.size(), "clear removes trails across the maps")
	# Flood the coarse sample graph using wall-checked edges to check tunnel connectivity.
	var world = sim.worlds[Sim.COLONY]
	expect(world.chambers.size() == 1 and world.paths.size() == 1, "the colony has one chamber and one entrance tunnel")
	expect(not world.is_open(Vector2(392, 636)), "the former lower galleries have been removed")
	var start: int = WorldData.index(floori(world.portal.x / WorldData.CELL), floori(world.portal.y / WorldData.CELL))
	var queue: Array[int] = [start]
	var visited := {start: true}
	var cursor: int = 0
	while cursor < queue.size():
		var current: int = queue[cursor]
		cursor += 1
		var x: int = current % WorldData.COLS
		var y: int = int(current / WorldData.COLS)
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = Vector2i(x, y) + offset
			if not world.is_cell_open(next.x, next.y):
				continue
			var key: int = WorldData.index(next.x, next.y)
			if visited.has(key) or not world.line_clear(WorldData.cell_center(x, y), WorldData.cell_center(next.x, next.y)):
				continue
			visited[key] = true
			queue.append(key)
	for chamber in world.chambers:
		var key: int = WorldData.index(floori(chamber.center.x / WorldData.CELL), floori(chamber.center.y / WorldData.CELL))
		expect(visited.has(key), "rounded chamber is reachable from the upper-left entrance: " + chamber.name)

func _test_portal_sensing() -> void:
	var sim := Sim.new(0)
	for world in sim.worlds:
		world.walkable.fill(1)
	var local = sim.worlds[Sim.OUTDOORS]
	var remote = sim.worlds[Sim.COLONY]
	var ant := sim.add_ant(local.portal + Vector2(0, 24), Sim.OUTDOORS)
	ant.explore_time = 0
	ant.mode = Sim.Mode.FOLLOW_FOOD
	ant.heading = -PI / 2
	var target := Vector2(132, 60)
	sim.fields[Sim.COLONY].deposit(target, Field.Kind.FOOD, 1)
	var result: Dictionary = sim.sense_for(ant, true)
	var distance: float = 24.0 + Sim.LINK_LENGTH + remote.portal.distance_to(target)
	var expected: float = 1.06 * sim.speed / (1 + distance / sim.falloff)
	expect(result.portal_count == 1 and result.count == 1, "an ant can sense a pheromone on the other side of the entrance")
	expect(absf(result.force.y + expected) < 0.001 and absf(result.force.x) < 0.001, "portal attraction uses distance through the hole and the original equation")
	expect(result.remote_visible.size() == 1 and result.visible.is_empty(), "inspection distinguishes remote from local samples")
	ant.heading = PI / 2
	expect(sim.sense_for(ant).count == 0, "the entrance must be inside the forward sensing cone")
	ant.heading = -PI / 2
	sim.outer_radius = distance - 1
	expect(sim.sense_for(ant).count == 0, "portal path distance respects the outer radius")
	sim.outer_radius = 82
	sim.inner_radius = distance + 1
	expect(sim.sense_for(ant).count == 0, "portal path distance respects the inner exclusion radius")
	sim.inner_radius = 9
	local.walkable[WorldData.mask_index(175, 179)] = 0
	expect(sim.sense_for(ant).count == 0, "a wall between the ant and its entrance blocks remote scent")
	local.walkable.fill(1)
	for x in range(62, 69):
		remote.walkable[WorldData.mask_index(x, 22)] = 0
	expect(sim.sense_for(ant).count == 0, "a wall beyond the other entrance blocks remote scent")
	remote.walkable.fill(1)
	sim.clear_trails()
	sim.fields[Sim.COLONY].deposit(ant.position, Field.Kind.FOOD, 4)
	expect(sim.sense_for(ant).count == 0, "overlapping coordinates do not leak scent between unrelated map locations")
	sim.clear_trails()
	sim.fields[Sim.COLONY].deposit(target, Field.Kind.HOME, 1)
	expect(sim.sense_for(ant).count == 0, "portal sensing still filters the pheromone type by mode")
	ant.mode = Sim.Mode.RETURN_FOOD
	expect(sim.sense_for(ant).portal_count == 1, "returning-food mode follows home scent through the hole")
	sim.clear_trails()
	ant.world_id = Sim.COLONY
	ant.position = remote.portal + Vector2.DOWN * 28
	ant.heading = -PI / 2
	ant.mode = Sim.Mode.FOLLOW_FOOD
	sim.fields[Sim.OUTDOORS].deposit(Vector2(348, 372), Field.Kind.FOOD, 2)
	expect(sim.sense_for(ant).portal_count == 1, "scent can pass through the entrance in both directions")
	sim.fields[Sim.COLONY].deposit(remote.portal, Field.Kind.FOOD, 5)
	sim.fields[Sim.OUTDOORS].deposit(Vector2(348, 364), Field.Kind.FOOD, 5)
	expect(sim.sense_for(ant).force.length() <= sim.speed + 0.001, "combined local and portal attraction is capped once at the speed limit")
	ant.position = remote.portal
	expect(sim.sense_for(ant).force.is_finite(), "zero distance at the entrance remains finite")

func _test_transfers() -> void:
	var sim := Sim.new(0)
	var ant := sim.add_ant(sim.worlds[Sim.OUTDOORS].portal + Vector2.RIGHT * 12, Sim.OUTDOORS)
	ant.heading = PI
	ant.velocity = Vector2.LEFT * sim.speed
	ant.carrying = true
	ant.mode = Sim.Mode.RETURN_FOOD
	ant.source_distance = 77
	var original_id: int = ant.id
	expect(sim._try_transfer(ant), "stepping into the mound enters the colony map")
	expect(ant.world_id == Sim.COLONY and sim.worlds[Sim.COLONY].fits(ant.position), "the destination is walkable near the upper-left entrance")
	expect(ant.position.y > sim.worlds[Sim.COLONY].portal.y and ant.heading == PI / 2, "incoming workers face down from the top of the colony")
	expect(ant.id == original_id and ant.carrying and ant.mode == Sim.Mode.RETURN_FOOD, "crossing preserves identity, carried food, and mode")
	expect(sim.ants.size() == 1 and sim.ants[0] == ant and sim.world_counts() == [0, 1], "crossing transfers a worker without duplicating it")
	expect(ant.source_distance == 77 + Sim.LINK_LENGTH, "crossing accounts for the connector distance")
	ant.position = sim.worlds[Sim.COLONY].portal
	expect(not sim._try_transfer(ant), "cooldown prevents immediate portal bounce")
	ant.portal_cooldown = 0
	expect(sim._try_transfer(ant) and ant.world_id == Sim.OUTDOORS, "the colony exit returns workers outdoors")
	expect(ant.heading == 0 and sim.worlds[Sim.OUTDOORS].fits(ant.position), "outgoing workers remember their surface approach direction")
	ant.position = sim.worlds[Sim.OUTDOORS].portal
	sim._interact(ant)
	expect(ant.carrying and sim.delivered == 0, "food is not deposited outside at the mound")
	ant.world_id = Sim.COLONY
	ant.position = sim.worlds[Sim.COLONY].food_storage.position
	sim._interact(ant)
	expect(not ant.carrying and sim.delivered == 1, "food is delivered only into underground storage")

func _test_food_storage() -> void:
	var sim := Sim.new(0)
	var outdoors = sim.worlds[Sim.OUTDOORS]
	var colony = sim.worlds[Sim.COLONY]
	var storage = colony.food_storage
	outdoors.foods.clear()
	expect(outdoors.food_storage == null and storage.amount == 0, "only the colony has storage, which starts empty")
	expect(colony.fits(storage.position) and colony.foods.is_empty(), "storage is walkable and separate from forageable food piles")
	sim.step(0.3)
	var entrance_index: int = WorldData.index(floori(outdoors.portal.x / WorldData.CELL), floori(outdoors.portal.y / WorldData.CELL))
	var storage_index: int = WorldData.index(floori(storage.position.x / WorldData.CELL), floori(storage.position.y / WorldData.CELL))
	expect(sim.fields[Sim.OUTDOORS].home[entrance_index] > 0 and sim.fields[Sim.OUTDOORS].food[entrance_index] == 0, "the anthill emits return scent rather than advertising food")
	expect(sim.fields[Sim.COLONY].home[storage_index] > 0 and sim.fields[Sim.COLONY].food[storage_index] == 0, "storage emits a return beacon even while empty")
	var ant := sim.add_ant(outdoors.portal + Vector2.RIGHT * 40, Sim.OUTDOORS)
	ant.explore_time = 0
	ant.heading = PI
	expect(sim.sense_for(ant).count == 0, "an empty-handed explorer is not attracted to the anthill's return beacon")
	outdoors.add_food(ant.position, 1)
	ant.heading = 0
	sim._interact(ant)
	expect(ant.carrying and ant.mode == Sim.Mode.RETURN_FOOD and sim.pickups == 1, "food pickup immediately switches a worker into carrying food home")
	ant.heading = PI
	var sensed: Dictionary = sim.sense_for(ant)
	expect(sensed.count > 0 and sensed.force.x < 0, "a carrier outside follows return pheromones toward the anthill")
	ant.world_id = Sim.COLONY
	ant.position = colony.portal + Vector2.DOWN * 26
	ant.heading = -PI / 2
	sensed = sim.sense_for(ant)
	expect(sensed.portal_count == 0 and sensed.count == 0, "a carrier inside ignores the surface return beacon behind it")
	ant.heading = PI / 2
	sensed = sim.sense_for(ant)
	expect(sensed.count > 0 and sensed.force.y > 0, "after entry a carrier follows the indoor beacon toward storage")
	ant.position = colony.portal
	sim._interact(ant)
	expect(ant.carrying and storage.amount == 0, "arriving at the underground entrance does not count as storage delivery")
	ant.position = storage.position + Vector2.RIGHT * (storage.radius + 2)
	sim._interact(ant)
	expect(ant.carrying and storage.amount == 0, "workers must reach the storage drop-off radius")
	ant.position = storage.position + Vector2.LEFT * 12
	for y in range(57, 79):
		colony.walkable[WorldData.mask_index(72, y)] = 0
	sim._interact(ant)
	expect(ant.carrying and storage.amount == 0, "storage cannot accept food through a wall, even inside its radius")
	ant.position = storage.position
	sim._interact(ant)
	expect(storage.amount == 1 and sim.delivered == storage.amount and not ant.carrying, "a successful delivery adds exactly one unit to the physical stockpile")
	expect(ant.mode == Sim.Mode.EXPLORE and ant.explore_time == 3.0, "after unloading, a worker resumes exploration")
	sim._interact(ant)
	expect(storage.amount == 1 and not ant.carrying, "stored food is not picked straight back up or counted twice")
	sim.clear_trails()
	expect(storage.amount == 1 and sim.fields[Sim.COLONY].home[storage_index] == 0, "clearing pheromones preserves the food stockpile")
	# An occupied stockpile emits return scent, never a forageable food beacon.
	var occupied := Sim.new(0)
	occupied.worlds[Sim.OUTDOORS].foods.clear()
	occupied.worlds[Sim.COLONY].food_storage.amount = 20
	occupied.step(0.3)
	expect(occupied.fields[Sim.COLONY].food.count(0.0) == occupied.fields[Sim.COLONY].food.size(), "stored provisions do not attract foragers as a food source")
	expect(occupied.fields[Sim.COLONY].home[storage_index] > 0, "the storage beacon remains active after provisions accumulate")
	# Exercise pickup, motion, portal crossing and unloading without teleporting.
	var route := Sim.new(0)
	route.worlds[Sim.OUTDOORS].foods.clear()
	var worker := route.add_ant(route.worlds[Sim.OUTDOORS].portal + Vector2.RIGHT * 40, Sim.OUTDOORS)
	worker.heading = 0
	worker.explore_time = 0
	route.worlds[Sim.OUTDOORS].add_food(worker.position, 1)
	for tick in range(60 * 30):
		route.step()
		if route.delivered == 1:
			break
	expect(route.transfers > 0 and route.delivered == 1 and not worker.carrying, "a worker autonomously carries food through the mound into storage")
	for tick in range(60 * 10):
		route.step()
	expect(route.pickups == 1 and route.delivered == 1, "delivered food remains stored while the worker explores again")

func _test_hunger() -> void:
	var sim := Sim.new(0)
	var outdoors = sim.worlds[Sim.OUTDOORS]
	var colony = sim.worlds[Sim.COLONY]
	var storage = colony.food_storage
	var ant := sim.add_ant(Vector2(200, 100), Sim.OUTDOORS)
	expect(ant.hunger == 0 and ant.meals == 0, "newly placed workers start fed with an independent hunger meter")
	sim.hunger_time = 200
	sim.hunger_threshold = 65
	sim._update_hunger(ant, 60)
	expect(is_equal_approx(ant.hunger, 30.0) and ant.mode == Sim.Mode.EXPLORE, "hunger fills linearly with simulation time below the return threshold")
	sim.hunger_time = 100
	sim._update_hunger(ant, 10)
	expect(is_equal_approx(ant.hunger, 40.0), "changing the fill time changes the rate without resetting the meter")
	ant.source_distance = 120
	ant.mode = Sim.Mode.FOLLOW_FOOD
	ant.hunger = 64
	sim._update_hunger(ant, 0.5)
	expect(ant.mode == Sim.Mode.FOLLOW_FOOD, "a worker keeps foraging until its hunger reaches the threshold")
	sim._update_hunger(ant, 0.5)
	expect(ant.mode == Sim.Mode.SEEK_MEAL and ant.hunger == 65.0, "reaching the hunger threshold starts a return-to-eat trip")
	expect(ant.source_distance == 120 and ant.explore_time == 0, "seeking a meal preserves the home trail's source distance and bypasses exploration cooldown")
	sim._update_hunger(ant, 1000)
	expect(ant.hunger == 100 and is_finite(ant.hunger), "hunger saturates safely at 100 percent")
	ant.hunger = 50
	ant.mode = Sim.Mode.EXPLORE
	sim.hunger_threshold = 40
	sim._update_hunger(ant, 0)
	expect(ant.mode == Sim.Mode.SEEK_MEAL, "lowering the threshold affects a worker on its next update")
	outdoors.foods.clear()
	ant.position = outdoors.portal + Vector2.RIGHT * 40
	ant.heading = PI
	sim.step(0.3)
	ant.heading = PI
	var sensed: Dictionary = sim.sense_for(ant)
	expect(sensed.count > 0 and sensed.force.x < 0, "a hungry worker follows return pheromones toward the mound")
	ant.world_id = Sim.COLONY
	ant.position = colony.portal + Vector2.DOWN * 26
	ant.heading = -PI / 2
	expect(sim.sense_for(ant).count == 0, "a hungry worker inside ignores the exterior entrance beacon behind it")
	ant.heading = PI / 2
	expect(sim.sense_for(ant).force.y > 0, "a hungry worker inside follows the storage beacon")
	colony.store_food(storage.position)
	ant.position = colony.portal
	sim._interact(ant)
	expect(ant.meals == 0 and storage.amount == 1, "reaching the entrance alone does not feed a hungry ant")
	ant.position = storage.position + Vector2.LEFT * 12
	for y in range(57, 79):
		colony.walkable[WorldData.mask_index(72, y)] = 0
	sim._interact(ant)
	expect(ant.meals == 0 and storage.amount == 1, "a hungry worker cannot eat through a wall")
	ant.position = storage.position
	sim._interact(ant)
	expect(storage.amount == 0 and sim.meals_eaten == 1 and ant.meals == 1, "a meal consumes exactly one unit from storage")
	expect(ant.hunger == 0 and ant.mode == Sim.Mode.EXPLORE, "eating resets the worker's meter and resumes exploration")
	expect(sim.delivered == 1 and sim.stored_food == 0, "lifetime deliveries remain distinct from the food left in storage")
	sim._interact(ant)
	expect(sim.meals_eaten == 1, "a fed worker does not immediately eat again")
	# An empty store must not trap the whole population waiting for a meal.
	ant.hunger = 90
	ant.mode = Sim.Mode.SEEK_MEAL
	sim._interact(ant)
	expect(ant.mode == Sim.Mode.EXPLORE and ant.hunger == 90 and ant.meal_retry > 0, "an empty store sends a hungry worker back to forage without falsely feeding it")
	sim._update_hunger(ant, 1)
	expect(ant.mode == Sim.Mode.EXPLORE, "a worker gets a foraging interval after finding storage empty")
	# Carriers bring their food inside before eating from the stockpile.
	ant.carrying = true
	ant.mode = Sim.Mode.RETURN_FOOD
	ant.meal_retry = 0
	sim._update_hunger(ant, 1)
	expect(ant.mode == Sim.Mode.RETURN_FOOD and ant.carrying, "a hungry carrier keeps its delivery task")
	sim._interact(ant)
	expect(not ant.carrying and ant.hunger == 0 and sim.delivered == 2 and sim.meals_eaten == 2 and sim.stored_food == 0, "a hungry carrier unloads first and can eat the unit it brought back")
	# Two workers competing for the last stored unit cannot overdraw it.
	colony.store_food(storage.position)
	var other := sim.add_ant(storage.position, Sim.COLONY)
	for worker in [ant, other]:
		worker.hunger = 90
		worker.mode = Sim.Mode.SEEK_MEAL
		worker.meal_retry = 0
		sim._interact(worker)
	expect(storage.amount == 0 and sim.meals_eaten == 3 and ant.hunger == 0 and other.hunger == 90, "the last stored unit feeds only one ant and inventory never becomes negative")
	var scavenger := sim.add_ant(outdoors.portal + Vector2.RIGHT * 40, Sim.OUTDOORS)
	scavenger.heading = PI
	scavenger.hunger = 90
	sim._update_hunger(scavenger, 0)
	expect(scavenger.mode == Sim.Mode.SEEK_MEAL and scavenger.reverse_time == 0, "a worker already facing return scent keeps heading toward the mound when hungry")
	outdoors.add_food(scavenger.position, 1)
	sim._interact(scavenger)
	expect(scavenger.carrying and scavenger.mode == Sim.Mode.RETURN_FOOD and scavenger.reverse_time == 0, "a hungry returning ant can pick up encountered food without turning away from home")
	# Verify the complete hunger-driven trip with motion and a portal crossing.
	var route := Sim.new(0)
	route.worlds[Sim.OUTDOORS].foods.clear()
	route.worlds[Sim.COLONY].store_food(route.worlds[Sim.COLONY].food_storage.position)
	var hungry := route.add_ant(route.worlds[Sim.OUTDOORS].portal + Vector2.RIGHT * 40, Sim.OUTDOORS)
	hungry.hunger = route.hunger_threshold
	hungry.heading = 0
	for tick in range(60 * 30):
		route.step()
		if hungry.meals > 0:
			break
	expect(hungry.meals == 1 and hungry.world_id == Sim.COLONY and route.transfers > 0, "a hungry ant autonomously returns through the mound and eats in the chamber")
	expect(hungry.hunger == 0 and route.stored_food == 0, "the complete meal trip updates both hunger and provisions")
