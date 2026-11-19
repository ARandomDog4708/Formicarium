# Version 0.1 validation

- Godot 4.6.3 standard engine, typed GDScript, compatibility renderer.
- 43 simulation checks passed.
- 16 application integration checks passed.
- The new PowerShell launcher was exercised on Linux with an explicit Godot
  path. It imported the project and ran all 59 checks successfully. Its
  Windows engine download and interactive launch have not been tested here.
- The 180-second seeded colony run found 117 food units and delivered 110.
  Food conservation, collision, finite state, speed and turn-rate checks passed.
- The native Linux application was opened and inspected on the shared desktop.
  Manual checks covered pause, single-step, worker selection, radius and angle
  controls, rejected food placement in dirt, successful food placement on open
  ground, both pheromone brush channels, zoom, and the controls guide.
- Windows x86-64 and Linux x86-64 release exports completed successfully.
  The Windows executable was checked as a valid PE32+ x86-64 GUI binary.
  Windows execution was not tested in this Linux environment.
