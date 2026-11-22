# Version 0.4 validation

- Godot 4.6.3 standard engine, typed GDScript, compatibility renderer.
- 142 simulation checks passed.
- 46 application integration checks passed, for 188 total checks using
  `./run-tests.sh` on Linux.
- The unchanged PowerShell launcher was exercised on Linux in version 0.2
  with an explicit Godot path. Windows engine download and interactive launch
  have not been tested here.
- The 180-second seeded run started with ten ants, picked up 39 food units,
  delivered 35, consumed ten meals and had 25 units left in storage.
  Food conservation includes consumed meals. Collision, finite state,
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
- The native Linux application was opened and inspected on the shared desktop.
  The single chamber, per-worker meters, selected worker's hunger bar and
  Returning to eat mode were visible. Both hunger sliders were changed to
  their minimums; stepping applied the new threshold. Reset restored fed
  workers, empty storage and the 180-second / 65% defaults. Pause and the 4x
  control were also checked manually.
- Integration checks also cover single-step, both maps' food placement and
  pheromone brushes, shared parameter controls, layer toggles, clearing both
  fields, selection following a worker through the entrance and camera reset.
  They also verify unloading while stepping, preserving provisions when
  clearing trails, eating while stepping, hunger pausing with the simulation,
  and restoring hunger settings and storage on reset.
- Version 0.4 is delivered as updated source for the existing clone and
  launcher. New standalone release exports were not produced for this update.
