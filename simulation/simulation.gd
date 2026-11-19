extends RefCounted
## Renderer-independent fixed-step model. All velocities are world units/sec.
## No navigation/pathfinding secretly steers ants toward food or home.
const WorldData = preload("res://simulation/world.gd")
const Field = preload("res://simulation/pheromones.gd")
const FIXED_DT: float = 1.0 / 60.0
enum Mode { EXPLORE, FOLLOW_FOOD, RETURN_HOME }
const MODE_NAMES = ["Exploring", "Following food", "Returning home"]

class Ant extends RefCounted:
	var id: int
	var position := Vector2.ZERO
	var heading: float = 0.0
	var velocity := Vector2.ZERO
	var mode: int = Mode.EXPLORE
	var force := Vector2.ZERO
	var sense_count: int = 0
	var sense_clock: float = 0.0
	var deposit_clock: float = 0.0
	var wander_clock: float = 0.0
	var wander_angle: float = 0.0
	var lost_time: float = 0.0
	var source_distance: float = 0.0
	var reverse_time: float = 0.0
	var reverse_target: float = 0.0
	var turn_side: float = 1.0
	var carrying: bool = false
	var age: float = 0.0
	var following_time: float = 0.0
	var explore_time: float = 0.0

var world: WorldData
var trails: Field
var ants: Array[Ant] = []
var rng := RandomNumberGenerator.new()
var elapsed: float = 0.0
var delivered: int = 0
var pickups: int = 0
var outer_radius: float = 82.0
var inner_radius: float = 9.0
var view_angle: float = 150.0
var turn_rate: float = 720.0
var speed: float = 37.0
var falloff: float = 32.0
var field_clock: float = 0.0
var source_clock: float = 0.0
var seed_value: int = 1847

func _init(population: int = 84, colony_seed: int = 1847) -> void:
	seed_value = colony_seed
	rng.seed = colony_seed
	world = WorldData.new()
	trails = Field.new(world)
	for i in range(population):
		var ant := Ant.new()
		ant.id = i
		ant.heading = rng.randf_range(-PI, PI)
		ant.turn_side = 1.0 if rng.randf() > 0.5 else -1.0
		ant.sense_clock = rng.randf_range(0, 0.12)
		ant.deposit_clock = rng.randf_range(0, 0.16)
		ant.wander_clock = rng.randf_range(0, 0.7)
		ant.explore_time = rng.randf_range(0, 3.0)
		# An established colony: workers occupy the nest and its entrance.
		# A small initial patrol is already on the surface; no trails are seeded.
		if i < 12:
			var px: float = 360.0 + float(i) * 27.0
			ant.position = Vector2(px, WorldData.surface_y(px) - 12.0)
			ant.heading = 0.0 if i % 2 == 0 else PI
		elif i < 30:
			var t: float = float(i - 12) / 18.0
			ant.position = Vector2(532, 197).lerp(Vector2(467, 291), t)
			ant.heading = -PI / 2.0
		else:
			ant.position = world.home + Vector2(rng.randf_range(-60, 60), rng.randf_range(-31, 31))
		if not world.fits(ant.position):
			ant.position = world.home
		ants.append(ant)

func mode_counts() -> Array[int]:
	var counts: Array[int] = [0, 0, 0]
	for ant in ants:
		counts[ant.mode] += 1
	return counts

func step(dt: float = FIXED_DT) -> void:
	elapsed += dt
	field_clock += dt
	if field_clock >= 0.1:
		trails.decay(field_clock)
		field_clock = 0.0
	source_clock += dt
	if source_clock >= 0.3:
		# Only local beacons, subject to exactly the same cone and wall checks.
		trails.deposit(world.home, Field.Kind.HOME, 4.0)
		for food in world.foods:
			if food.amount > 0:
				trails.deposit(food.position, Field.Kind.FOOD, 4.0)
		source_clock = 0.0
	# All ants sense the same field before this tick's deposits are applied.
	for ant in ants:
		ant.age += dt
		ant.explore_time = maxf(0, ant.explore_time - dt)
		if ant.mode == Mode.FOLLOW_FOOD:
			ant.following_time += dt
			if ant.following_time > 40.0:
				# An unproductive trail should not suppress exploration forever.
				ant.mode = Mode.EXPLORE
				ant.explore_time = 6.0
				ant.following_time = 0.0
				ant.force = Vector2.ZERO
				ant.sense_count = 0
		ant.sense_clock += dt
		if ant.sense_clock >= 0.12:
			_sense(ant)
			ant.sense_clock = 0.0
	for ant in ants:
		_move(ant, dt)
		_interact(ant)
	for ant in ants:
		ant.deposit_clock += dt
		if ant.deposit_clock >= 0.16:
			var kind: int = Field.Kind.FOOD if ant.carrying else Field.Kind.HOME
			var strength: float = maxf(0.045, 1.5 * exp(-ant.source_distance / 220.0))
			trails.deposit(ant.position, kind, strength)
			ant.deposit_clock = 0.0

func _sense(ant: Ant) -> void:
	if ant.mode == Mode.EXPLORE and ant.explore_time > 0:
		ant.force = Vector2.ZERO
		ant.sense_count = 0
		return
	var kind: int = Field.Kind.HOME if ant.mode == Mode.RETURN_HOME else Field.Kind.FOOD
	var sensed: Dictionary = trails.sense(ant.position, ant.heading, kind, inner_radius, outer_radius, deg_to_rad(view_angle * 0.5), speed, falloff)
	ant.force = sensed.force
	ant.sense_count = sensed.count
	if ant.mode == Mode.EXPLORE and ant.sense_count > 0:
		ant.mode = Mode.FOLLOW_FOOD
		ant.following_time = 0.0
	if ant.mode == Mode.FOLLOW_FOOD:
		ant.lost_time = ant.lost_time + 0.12 if ant.sense_count == 0 else 0.0
		if ant.lost_time > 1.2:
			ant.mode = Mode.EXPLORE
			ant.following_time = 0.0

static func turn_toward(current: float, target: float, max_change: float) -> float:
	return wrapf(current + clampf(angle_difference(current, target), -max_change, max_change), -PI, PI)

func _move(ant: Ant, dt: float) -> void:
	ant.wander_clock -= dt
	if ant.wander_clock <= 0:
		ant.wander_clock = rng.randf_range(0.25, 0.8)
		ant.wander_angle = rng.randf_range(-0.85, 0.85)
	var forward := Vector2.from_angle(ant.heading)
	var target: float = ant.heading
	var desired_speed: float = speed
	if ant.reverse_time > 0.0:
		target = ant.reverse_target
		ant.reverse_time = maxf(0, ant.reverse_time - dt)
		desired_speed = speed * 0.35
	elif ant.mode == Mode.EXPLORE or ant.sense_count == 0:
		target = ant.heading + ant.wander_angle * dt * 2.0
	else:
		# Sum unit-vector attraction, add forward persistence, then cap speed.
		var desired := (ant.force + forward * speed * 0.35).limit_length(speed)
		target = desired.angle()
		desired_speed = desired.length()
	if ant.reverse_time <= 0.0:
		target = _avoid_wall(ant, target)
	ant.heading = turn_toward(ant.heading, target, deg_to_rad(turn_rate) * dt)
	var velocity := Vector2.from_angle(ant.heading) * desired_speed
	# Explicit Euler. Collision can reject displacement; it cannot teleport ants.
	var next := ant.position + velocity * dt
	if world.fits(next) and world.line_clear(ant.position, next):
		ant.position = next
		ant.velocity = velocity
		ant.source_distance += velocity.length() * dt
	else:
		ant.velocity = Vector2.ZERO
	if not ant.carrying and ant.position.distance_to(world.home) < 23.0:
		ant.source_distance = 0.0

func _avoid_wall(ant: Ant, target: float) -> float:
	var look: float = 13.0
	var ahead := ant.position + Vector2.from_angle(target) * look
	if world.fits(ahead) and world.line_clear(ant.position, ahead):
		return target
	var best: float = target + PI * ant.turn_side
	var best_score: float = -INF
	for i in range(1, 9):
		for side in [ant.turn_side, -ant.turn_side]:
			var candidate: float = ant.heading + side * float(i) * PI / 8.0
			var point := ant.position + Vector2.from_angle(candidate) * look
			if not world.fits(point) or not world.line_clear(ant.position, point):
				continue
			var score: float = -absf(angle_difference(candidate, target)) - float(i) * 0.01
			if score > best_score:
				best_score = score
				best = candidate
	return best

func _reverse(ant: Ant) -> void:
	ant.reverse_target = wrapf(ant.heading + PI, -PI, PI)
	ant.reverse_time = 180.0 / turn_rate + FIXED_DT
	ant.source_distance = 0.0
	ant.force = Vector2.ZERO
	ant.sense_count = 0

func _interact(ant: Ant) -> void:
	if ant.carrying:
		if ant.position.distance_to(world.home) < 25.0:
			delivered += 1
			ant.carrying = false
			ant.mode = Mode.EXPLORE
			ant.explore_time = 3.0
			_reverse(ant)
		return
	for food in world.foods:
		if food.amount > 0 and ant.position.distance_to(food.position) < 14.0 and world.line_clear(ant.position, food.position):
			food.amount -= 1
			pickups += 1
			ant.carrying = true
			ant.mode = Mode.RETURN_HOME
			_reverse(ant)
			return
