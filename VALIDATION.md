# Version 0.3 validation

- Godot 4.6.3 standard engine, typed GDScript, compatibility renderer.
- 114 simulation checks passed.
- 38 application integration checks passed, for 152 total checks using
  `./run-tests.sh` on Linux.
- The unchanged PowerShell launcher was exercised on Linux in version 0.2
  with an explicit Godot path. Windows engine download and interactive launch
  have not been tested here.
- The 180-second seeded run started with ten ants, picked up 76 food units and
  stored 74 inside the colony. Food conservation, collision, finite state,
  speed and continuous-map turn-rate checks passed.
- Tests cover two-way entrance transfers, worker identity and carried food,
  cooldown, arrival positions, portal path distance, combined attraction cap,
  and scent visibility blocked by walls on either side of the connection.
- Rounded boundaries, fine-mask visibility at grid-boundary endpoints,
  independent map fields and connected colony galleries are checked.
- Storage checks cover an autonomous pickup-to-storage journey, switching to
  Returning food, following the anthill beacon outdoors and storage indoors,
  rejecting delivery through a wall or at the entrance, exact inventory
  changes, and preventing stored food from being harvested again.
- The native Linux application was opened and inspected on the shared desktop.
  The marked storage area started empty, then accumulated a visible food pile.
  Its live count matched FOOD STORED above the maps. Pause and the 4x control
  were also checked manually.
- Integration checks also cover single-step, both maps' food placement and
  pheromone brushes, shared parameter controls, layer toggles, clearing both
  fields, selection following a worker through the entrance and camera reset.
  They also verify unloading while stepping, preserving provisions when
  clearing trails and emptying storage on reset.
- Version 0.3 is delivered as updated source for the existing clone and
  launcher. New standalone release exports were not produced for this update.
