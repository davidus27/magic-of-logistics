# Documentation

Split so you load only the part you are working on. The behaviour specification
used to be one 32 KB file; it is now one file per system.

## Read first

| File | When |
|---|---|
| [`status.md`](status.md) | **Always.** What is built, what is next, what is deliberately missing. |
| [`engine-notes.md`](engine-notes.md) | Before touching a `.tscn`, a `Control`, or the navigation bake. Godot traps that look like working code when wrong. |
| [`spec/`](spec/) | The behaviour specification, by system. Open the one file your task needs. |
| [`milestones/`](milestones/) | Closed milestone reports. History, not instructions. |

## Specification map

Section numbers are preserved in every heading, so a code comment that reads
"section 15.7" still resolves. Find the owning file here.

| §    | Topic | File |
|---|---|---|
| 1–7, 44 | Purpose, scope, technical terms, objective, run duration | [`spec/00-overview.md`](spec/00-overview.md) |
| 8 | Game states: profile select, instructions, run, pause, portal cast, success, failure, result | [`spec/01-game-flow.md`](spec/01-game-flow.md) |
| 9 | Camera | [`spec/01-game-flow.md`](spec/01-game-flow.md) |
| 10 | Visual design: paper-and-ink style, grain, line effect, entity and selection symbols | [`spec/02-visual-style.md`](spec/02-visual-style.md) |
| 11 | Battlefield layout | [`spec/03-map-and-terrain.md`](spec/03-map-and-terrain.md) |
| 12 | Terrain: road, mud, off-road, feedback | [`spec/03-map-and-terrain.md`](spec/03-map-and-terrain.md) |
| 13 | Cargo unit: properties, health, collision, rider | [`spec/04-cargo.md`](spec/04-cargo.md) |
| 14 | Wizard: position, mana, spell selection, Arc Bolt, Mend, Ward | [`spec/05-wizard.md`](spec/05-wizard.md) |
| 15 | Defenders: count, values, movement, all seven states | [`spec/06-defenders.md`](spec/06-defenders.md) |
| 16 | Defender selection | [`spec/06-defenders.md`](spec/06-defenders.md) |
| 17 | Defender control method A — role orders | [`spec/06-defenders.md`](spec/06-defenders.md) |
| 18 | Defender control method B — direct target orders | [`spec/06-defenders.md`](spec/06-defenders.md) |
| 19–21 | Cargo control methods A, B, C | [`spec/04-cargo.md`](spec/04-cargo.md) |
| 22 | Input priority rules | [`spec/12-profiles-and-testing.md`](spec/12-profiles-and-testing.md) |
| 23–24 | Recommended first profile, the four test profiles | [`spec/12-profiles-and-testing.md`](spec/12-profiles-and-testing.md) |
| 25 | Enemies: short-range, long-range | [`spec/07-enemies-and-threat.md`](spec/07-enemies-and-threat.md) |
| 26 | Enemy attack schedule, six trigger areas | [`spec/07-enemies-and-threat.md`](spec/07-enemies-and-threat.md) |
| 27 | Threat system | [`spec/07-enemies-and-threat.md`](spec/07-enemies-and-threat.md) |
| 28 | Barriers | [`spec/03-map-and-terrain.md`](spec/03-map-and-terrain.md) |
| 29 | Combat rules and the damage formula | [`spec/08-combat-rules.md`](spec/08-combat-rules.md) |
| 30 | User interface regions and world feedback | [`spec/09-ui-and-sound.md`](spec/09-ui-and-sound.md) |
| 31 | Sound design | [`spec/09-ui-and-sound.md`](spec/09-ui-and-sound.md) |
| 32 | Godot scene design and data resources | [`spec/10-architecture.md`](spec/10-architecture.md) |
| 33 | State machine design | [`spec/10-architecture.md`](spec/10-architecture.md) |
| 34 | Navigation rules | [`spec/10-architecture.md`](spec/10-architecture.md) |
| 35 | Test seed rules | [`spec/10-architecture.md`](spec/10-architecture.md) |
| 36 | Telemetry | [`spec/11-telemetry-and-results.md`](spec/11-telemetry-and-results.md) |
| 37 | Result screen | [`spec/11-telemetry-and-results.md`](spec/11-telemetry-and-results.md) |
| 38–39 | Test procedure, profile evaluation | [`spec/12-profiles-and-testing.md`](spec/12-profiles-and-testing.md) |
| 40 | MVP acceptance criteria | [`spec/12-profiles-and-testing.md`](spec/12-profiles-and-testing.md) and the checklist in [`status.md`](status.md) |
| 41 | Implementation order | [`spec/12-profiles-and-testing.md`](spec/12-profiles-and-testing.md) and the tracked table in [`status.md`](status.md) |
| 42–43 | Decisions after the test, initial recommendation | [`spec/12-profiles-and-testing.md`](spec/12-profiles-and-testing.md) |

## Conventions

The specification is written in simplified technical English: short sentences,
active voice, one topic per paragraph. Keep that style when you edit it — it is
what makes the numbers easy to find.

Every value in the specification also exists as a Godot resource under `data/`
(§32.5). **The resource is what the game reads.** If the two disagree, that is a
bug — say which one you changed.
