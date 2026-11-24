# Formicarium

A native **2D desktop ant colony simulator**, made with Godot 4.6 and typed
GDScript. Two separate maps are visible side by side: flat, top-down outdoor
land on the left and one rounded colony chamber on the right. The mound in
the grass links to the entrance at the upper left of the colony. Every open
area is walkable in any direction; walls block movement and pheromone sensing.

![Simulator preview](docs/preview.png)

## Clone and run on Windows

Install [Git for Windows](https://git-scm.com/download/win) if you do not have
Git installed. Clone this repository and open its folder in PowerShell:

    git clone https://github.com/ARandomDog4708/Formicarium.git
    cd Formicarium
    .\run.cmd

The launcher downloads the official standard **Godot 4.6.3** engine on first
use, verifies its SHA-512 checksum, imports the project and opens the simulator.
The engine is cached under your local application data folder for later runs.
You can also double-click **run.cmd** in the cloned folder. Administrator
access and a separate Godot installation are not required.

To run the checks on Windows:

    .\run.cmd -RunTests

The simulation and application source files are directly editable in this
repository. To open the project in the Godot editor, install the standard
Godot 4.6+ editor, import **project.godot**, and press **F5**.

## Update an existing clone

Close the running simulator, open PowerShell in your repository folder, then:

    git pull
    .\run.cmd

## Linux and macOS

Install the standard [Godot 4.6+ editor](https://godotengine.org/download/).
With Godot on your PATH:

    ./launch.sh

Or import **project.godot** in the editor and press **F5**. No .NET runtime,
plugins, or other packages are needed.

## Controls

| Control | Action |
| --- | --- |
| Space | Pause / resume |
| N / Step | One 1/60-second simulation step while paused |
| 1 / Inspect | Click a worker to select it |
| 2 / Food | Click walkable space to add 120 food units |
| 3 / Scent | Click or drag to paint food pheromone in either map |
| 4 / Ants | Click walkable space to add one worker |
| Shift + ant placement | Add ten workers at the clicked location |
| +10 above the maps | Add ten workers near the entrance in the active map |
| Shift + scent brush | Paint home pheromone |
| Mouse wheel | Zoom around the pointer |
| Middle mouse drag | Pan |
| 0 / Fit | Fit both maps |
| R / Reset colony | Restart the same seeded colony |
| H / ? | Controls guide |
| Escape | Close guide / return to inspection |

Start with **10 workers**. Select the Ants tool (4) to place more in either
map; Shift-click places ten. Reset restores the original ten. Each map has
its own zoom and pan. The bottom zoom buttons control the most recently
clicked map. Inspection follows the same worker as it travels between maps.
Stored food can also produce new workers automatically.

Use 1×, 2× and 4× to change the number of fixed simulation steps, independently
of the display frame rate. The inspector adjusts both radii, the forward
sensing angle, maximum turn rate, pheromone half-life and hunger settings.
Layer switches affect drawing only in both maps. Clear trails removes both fields. The
selected worker's cone shows its sensing region, with lines to visible samples.
A dashed line to the entrance and highlighted samples in the opposite map
show pheromones being sensed through the hole. The inspector's "hole" count
reports how many eligible samples are on the other side.

## Linked maps and the entrance

An ant entering the outdoor mound appears just below the colony's upper-left
entrance, facing down into the tunnel. Going back through that entrance
returns the same ant outdoors, heading back along its remembered surface
approach. Identity, mode, hunger, carried food and chemical source distance persist.
A short cooldown and exit offset prevent immediate bouncing between maps.
The mound is an entrance and a source of return pheromone. Food stays with a
carrying worker until it reaches the storage chamber inside the colony.

Pheromones stay in their own map and can be sensed through the hole. A remote
sample contributes only when both legs are unobstructed: ant to local opening,
and remote opening to sample. Its effective distance is the sum of those
legs plus an 8-unit connector. That entire distance must be inside the same
sensing ring. The ant must face the local opening, and the scent type must
match its mode. The direction of attraction is toward the opening. Local and
remote contributions are added before applying the speed cap.

The connection models a small tunnel between two maps; no attraction is
computed using the distance between the on-screen panels.

## Food storage and returning workers

The colony has a single rounded chamber and a short entrance tunnel. Its
**FOOD STORAGE** area starts empty and displays a pile representing the food
remaining, along with an exact unit count. The **FOOD STORED** counter above
the maps reads this same stockpile.

Picking up one food unit immediately switches a worker to **Returning food**.
It follows home/return pheromone toward the anthill while outdoors. After
crossing the entrance, it follows the storage beacon inside the colony. In
this mode, a worker already inside ignores the outdoor entrance beacon so
that it can continue toward storage. Food-trail sensing through the entrance
still works in both directions for foragers.

A delivery requires being within 25 world units of storage with a clear line
of sight. Reaching either entrance alone does not unload food. After delivery,
the worker becomes empty-handed and explores again, eating first if hungry.
Stored provisions are separate from forageable food piles and do not emit a
food-source beacon, so
foragers do not pick their deliveries straight back up. Hungry workers eat
from storage instead. Clear trails preserves stored food; Reset colony empties
storage and restores the initial ten ants.

## Colony growth and food replacement

The colony produces a worker whenever stored food reaches
`ceil(current_ant_count * 1.5)`. It spends that amount from storage and the
new worker appears inside the chamber near the stockpile, fed and ready to
explore. For example, ten ants need 15 food for the eleventh worker; eleven
ants then need 17 food for the twelfth. Manually added workers count toward
the next threshold.

Workers eat and unload before growth is checked. At most one worker is born
per fixed step, and the next cost is recalculated from the new population.
The population card shows automatic births and the next food cost; the food
card shows food spent on growth and the number of automatic new food piles.

When collection brings a forage source down to **five units**, a new source
containing **120 food** appears at a random clear location outdoors. It stays
away from rocks, the entrance and other active piles. The old pile keeps its
last five units. Each depletion triggers once, including when several ants
collect the remaining units in the same tick. New sources can create further
replacements when they run low, and refilling an old source allows another
replacement on its next depletion. A source placed inside the colony also
creates its successor outdoors.

If no clear location is available, the replacement stays pending and retries
later. Storage is separate from these forage sources. Reset restores the
original ten ants, two outdoor sources and empty storage, and clears growth
costs and replacement counters.

## Hunger

Every worker has its own hunger meter: **0% is fed and 100% is fully hungry**.
A small bar above each ant shows its hunger. Select a worker to see its exact
percentage and a larger meter with a mark at the return threshold.

Two controls in the inspector apply to all workers immediately:

| Setting | Meaning | Default | Range |
| --- | --- | --- | --- |
| Time to 100% hunger | Simulation seconds for the meter to fill from 0% | 180 s | 30–600 s |
| Return to eat at | Hunger percentage that triggers a meal trip | 65% | 10–100% |

At the default settings, a fed worker becomes hungry enough to return after
117 simulated seconds. Hunger increases by `100 * dt / hunger_time`, capped
at 100%. Pause holds the meter, single-step advances it once, and the speed
buttons advance hunger with the rest of the simulation. Changing the fill
time changes the rate without resetting existing hunger. Newly added ants
start fed; Reset restores fed workers and the default hunger settings.

At the threshold, an empty-handed worker switches to **Returning to eat**.
It follows the same entrance and indoor storage pheromones as a food carrier,
using the same range, cone, wall checks, turn limits and attraction equation.
Eating consumes one stored unit, resets that ant's hunger to 0%, and resumes
exploration. A worker carrying food finishes unloading before eating.

If storage is empty, the worker keeps its hunger and resumes foraging for
30 seconds before trying another meal trip. It can also collect food on the
way home, deliver it, and eat the unit it brought back. This allows the colony
to replenish an empty store. Stored food, lifetime deliveries and consumed
meals and food spent on growth are tracked separately. Food accounting also
includes the food added by automatic replacement sources.

## The model

For a pheromone sample j, strength a, distance d, and unit direction u:

    contribution_j = a_j * speed / (1 + d_j / falloff_length) * u_j
    attraction = cap_length(sum(contribution_j), speed)

Samples qualify only if:

- inner_radius < distance <= outer_radius;
- they are inside the forward cone;
- the grid ray from ant to sample crosses no solid cells;
- they match the pheromone type for the ant's current mode.

The two channels share the exact same equation:

| Mode | Follows | Deposits |
| --- | --- | --- |
| Explore | Persistent wandering; can detect food trails | Home |
| Follow food | Food | Home |
| Returning food | Home/return: entrance outdoors, storage indoors | Food |
| Returning to eat | Home/return: entrance outdoors, storage indoors | Home |

Workers pick up food on contact, turn around within the turn-rate limit, and
carry one unit back to storage. Deposits weaken with distance traveled from
their source. Samples combine repeated deposits in an 8-unit grid and decay
exponentially, with a default 32-second half-life. Food piles emit food beacons;
the entrance and storage emit home/return beacons. These all obey the same
radius, cone and wall checks and use the same attraction equation.

Exploration is an explicit state. After delivery, a worker explores for three
seconds before reacquiring a food trail. A trail followed for 40 seconds
without finding food triggers six seconds of exploration. This lets workers
leave unproductive scent clusters. Food is still picked up on contact while
exploring.

The capped attraction is combined with forward persistence and capped again.
Local obstacle checks choose a clear heading. The actual heading changes by
at most turn_rate * dt, including food pickup and delivery turns.

    velocity = facing_direction * desired_speed
    next_position = position + velocity * dt

This is explicit Euler integration at dt = 1/60 s. A displacement crossing
solid ground is rejected. The default turn rate is 720 degrees/second. Ants
use local sensing only; no pathfinder or global destination vector directs
their foraging.

### Initial conditions

Ten workers begin around the outdoor mound. Some initially face the entrance;
the others explore the flat land. Pheromone trails start empty. Two outdoor
food piles hold 440 units total. All workers start fed. The random seed is
1847. Reset recreates this same setup, including emptying storage and removing
manually added ants and food.

## Source layout

- simulation/world.gd: independent outdoor and colony maps, curved tunnel
  geometry, a 2-unit collision/visibility mask, safe food placement and storage.
- simulation/pheromones.gd: per-map chemical fields, deposition, decay, local
  attraction and wall-checked sensing through the entrance.
- simulation/simulation.gd: ant states, hunger and meals, colony growth, food
  replacement, manual spawning, entrance transfers and fixed-step motion.
- app/habitat.gd: one map viewport, rounded terrain and tunnels, ants, overlays,
  independent zoom/pan and map-specific placement tools.
- app/main.gd: native controls and inspection panel.
- tests/run_tests.gd: headless model checks and a three-minute colony run.

The model extends RefCounted and owns no scene nodes; the view reads it.

## Validation

Run ./run-tests.sh, or:

    godot --headless --path . --script res://tests/run_tests.gd
    godot --headless --path . --script res://tests/app_smoke.gd

Checks cover the ten-ant starting population, manual additions, stable worker
identity across transfers, entrance cooldown, two-way scent transmission,
visibility on both sides of the hole, a connected single chamber, rounded boundaries,
the attraction equation, speed cap, inner and outer radii,
forward angle, channel selection, zero-distance samples, wall occlusion,
diagonal corners, half-life decay, Euler motion, turn-rate limits, seeded
repeatability, food conservation and autonomous pickup/delivery. A three-minute
simulation also checks that ants remain in walkable space with finite state.
Storage checks cover the complete pickup-to-stockpile journey, indoor/outdoor
return scent selection, blocked deliveries, exact inventory changes and
preventing stored provisions from being reharvested.
Hunger checks cover fill time, threshold changes, the full return-to-eat trip,
consuming the last stored unit, empty-storage recovery, carrying food while
hungry, walls blocking meals and conservation including consumed food.
Growth checks cover rounded costs, spending food exactly once, fed newborns,
unique ids, meal priority, blocked birth locations and changing population
size during motion. Source checks cover crossing the five-food threshold,
multiple pickups in one tick, refilling sources, safe random placement,
retrying blocked placement, normal food pheromones and seeded repeatability.
Application checks exercise pause/step, both map views, shared selection,
parameter controls, food placement, both pheromone brush channels, ant
placement and batches, independent zoom, both hunger sliders, hunger during
pause and step, reset and the controls guide.

## Export

Install the matching Godot export templates, then use Project → Export.
Presets for Windows x86-64 and Linux x86-64 are included. The same source can
also be exported to macOS using Godot's macOS preset and templates.

## First-version scope

This is a tunable colony sandbox. Terrain and tunnels are initially fixed.
Worker production instantly converts stored food into new ants. Digging,
queens, brood development, combat and a game economy are future work. Trail
behavior is an approximation rather than a biologically calibrated model.

Project code is MIT licensed. Godot license and notices are included in
GODOT-LICENSE.txt and GODOT-COPYRIGHT.txt.
