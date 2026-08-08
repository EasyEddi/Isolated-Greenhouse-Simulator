# Agent Rules

Read this file and `Documentation/DESIGN-BIBLE.md` before changing the project.

## Product Rules

- The game is peaceful, isolated, warm, and lightly melancholic. It is never horror, combat, or survival-stress driven.
- English is the only in-game language for this build.
- The first-person physical workflow is the product. Do not replace it with menu-only abstractions.
- Plants are the visual and mechanical priority. New breadth must not reduce their quality.
- Finish and test a coherent loop before adding lower-priority systems.
- Preserve the L-shaped hall layout and its residential, office, storage, nursery, and greenhouse departments.
- Online purchases arrive through the physical delivery drone.
- Care data must remain species-specific: water use, soil, fertilizer, growth, health, and offshoot behavior.

## Engineering Rules

- Keep runtime code deterministic enough for headless tests.
- Add or update tests for shared gameplay state changes.
- Run import validation, tests, a smoke session, and a Windows release export before declaring a change complete.
- Do not commit generated `.godot`, logs, captures, or raw source assets.
- Keep third-party licensing in `Documentation/CREDITS.md` current.
- Do not edit or delete the older Unreal repository from this project.
