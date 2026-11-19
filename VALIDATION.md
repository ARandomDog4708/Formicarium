# Version 0.2 validation

- Godot 4.6.3 standard engine, typed GDScript, compatibility renderer.
- 94 simulation checks passed.
- 34 application integration checks passed.
- The PowerShell launcher was exercised on Linux with an explicit Godot
  path. It imported the project and ran all 128 checks successfully. Its
  Windows engine download and interactive launch have not been tested here.
- The 180-second seeded run started with ten ants, picked up 53 food units and
  delivered 51 inside the nest. Food conservation, collision, finite state,
  speed and continuous-map turn-rate checks passed.
- Tests cover two-way entrance transfers, worker identity and carried food,
  cooldown, arrival positions, portal path distance, combined attraction cap,
  and scent visibility blocked by walls on either side of the connection.
- Rounded boundaries, fine-mask visibility at grid-boundary endpoints,
  independent map fields and connected colony galleries are checked.
- The native Linux application was opened and inspected on the shared desktop.
  Manual checks covered both maps, worker transfers, pause, worker selection,
  one-ant placement, Shift-click batches, rejected placement in dirt, the +10
  control, independent zoom, reset to ten ants and the controls guide.
- Integration checks also cover single-step, both maps' food placement and
  pheromone brushes, shared parameter controls, layer toggles, clearing both
  fields, selection following a worker through the entrance and camera reset.
- Version 0.2 is delivered as updated source for the existing clone and
  launcher. New standalone release exports were not produced for this update.
