# Version 0.5 validation

- Godot 4.6.3 standard engine, typed GDScript, compatibility renderer.
- 172 simulation checks passed.
- 51 application integration checks passed, for 223 total checks using
  `./run-tests.sh` on Linux.
- The unchanged PowerShell launcher was exercised on Linux in version 0.2
  with an explicit Godot path. Windows engine download and interactive launch
  have not been tested here.
- The 180-second seeded run grew from ten to twelve ants, picked up 53 food
  units, delivered 50, consumed ten meals, spent 32 food on two births and
  had eight units left in storage. Food accounting includes meals, growth
  spending and automatically generated food. Collision, finite state,
  speed and continuous-map turn-rate checks passed.
- Tests cover two-way entrance transfers, worker identity and carried food,
  cooldown, arrival positions, portal path distance, combined attraction cap,
  and scent visibility blocked by walls on either side of the connection.
- Rounded boundaries, fine-mask visibility at grid-boundary endpoints,
  independent map fields, a single connected colony chamber and removal of
  the former galleries are checked.
- Storage checks cover an autonomous pickup-to-storage journey, switching to
  Returning food, following the anthill beacon outdoors and storage indoors,
  rejecting delivery through a wall or at the entrance, exact inventory
  changes, and preventing stored food from being harvested again.
- Hunger checks cover time-based meter filling, fill-rate and threshold
  changes, saturation, the complete return-to-eat trip, indoor/outdoor return
  scent, eating one unit, walls blocking meals, finishing a delivery before
  eating, empty-store recovery, and two ants competing for the last unit.
  A worker already facing home scent keeps its heading, including when
  picking up food on the way back to eat.
- Growth checks cover exact and rounded population-based costs, charging
  food once, fed newborns inside the colony, stable ids, one birth per step,
  manual additions changing the next cost, blocked birth positions and
  workers eating before growth spends the remaining food.
- Food-source checks cover the six-to-five transition, repeated ticks at
  five, collecting below five, several pickups in one tick, refilling an old
  source, generated sources making successors, safe placement, normal food
  beacons, blocked placement retry and seeded repeatability. Indoor forage
  sources create their successors outdoors; colony storage does not trigger
  this rule.
- The native Linux application was opened and inspected on the shared desktop.
  The population grew automatically to eighteen workers. The population card
  showed eight births and a 27-food next cost; the food card showed 164 units
  spent on growth. New status text fit in both cards. Pause and the 4x control
  were also checked manually.
- Integration checks also cover single-step, both maps' food placement and
  pheromone brushes, shared parameter controls, layer toggles, clearing both
  fields, selection following a worker through the entrance and camera reset.
  They also verify unloading while stepping, preserving provisions when
  clearing trails, eating while stepping, hunger pausing with the simulation,
  and restoring hunger settings and storage on reset.
  New checks cover paused growth, a birth on single-step, selecting a newborn,
  replacing a low food source in the displayed outdoor world, and clearing
  automatic births, costs and new sources on reset.
- Version 0.5 is delivered as updated source for the existing clone and
  launcher. New standalone release exports were not produced for this update.
