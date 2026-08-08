# Agent Rules

These rules apply to every automated or assisted change in this repository.

## Product Direction

- Preserve the calm, isolated plant-work atmosphere. Do not add horror, combat, hunger, hostile NPCs, or time pressure.
- Keep the game and all player-facing text in English.
- Treat plants, believable care, and the physical first-person work loop as the highest priorities.
- Prefer one finished, tested interaction over several placeholder systems.
- Keep the established L-shaped hall and its residential, office, storage, nursery, greenhouse, water, and delivery departments recognizable.

## Engineering

- Read `Documentation/DESIGN-BIBLE.md` and `Documentation/TECHNICAL.md` before changing gameplay or architecture.
- Keep command-line import, simulation tests, integration tests, and Windows export working.
- Add regression coverage for behavioral changes and inspect a rendered capture for visual changes.
- Do not commit `.godot/`, `build/`, `captures/`, `logs/`, raw source assets, or user save files.
- Do not replace project-owned models with third-party marketplace content without explicit approval and license documentation.

## Scope

- Do not promise unimplemented systems in documentation or UI.
- Lower-priority mechanics may be deferred when they would weaken the core loop.
- Keep save files backward compatible where practical; increase `SAVE_VERSION` only for a deliberate migration boundary.

## Releases

- Release titles use `MVP Alpha x.y.z` while the project is pre-release.
- Keep major version `0` until the owner explicitly requests otherwise.
- Every release description must contain `Description`, `Changelog`, and GitHub-native contributor attribution.
- Attach the standalone Windows executable named `IsolatedGreenhouse_x.y.z.exe`.
