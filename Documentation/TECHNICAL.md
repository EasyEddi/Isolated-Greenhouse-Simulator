# Technical Notes

## Runtime

- Engine: Godot `4.6.3-stable`
- Renderer: GL Compatibility for broad Windows hardware support
- Language: GDScript
- Target: Windows x86_64, release PCK embedded in the executable
- Persistence: versioned JSON save under `user://isolated_greenhouse_save.json`

## Architecture

- `game.gd`: scene ownership, mode transitions, and service wiring.
- `world_builder.gd`: deterministic hall, furniture, lights, workstations, and navigation-free collision generation.
- `player.gd`: first-person movement, focus ray, held-item presentation, and input modes.
- `plant_catalog.gd`: immutable species and item definitions.
- `plant_actor.gd`: per-pot care simulation, visuals, growth, and harvest interaction.
- `game_state.gd`: inventory, economy, unlocks, objectives, deliveries, and save snapshot.
- `terminal_ui.gd`: shop, sales, journal, and delivery feedback.
- `drone_controller.gd`: physical delivery sequence and crate state.
- `hud.gd`: crosshair, prompt, hotbar, objective, plant readout, pause, and settings.

## Validation Gates

1. Headless editor import exits without parse or resource errors.
2. Unit tests cover catalog integrity, purchases, deliveries, care calculations, growth, harvesting, selling, and save round-trips.
3. Scene audit checks required departments, collisions, interactions, lights, and plant slots.
4. Automated smoke mode runs a complete purchase-to-sale loop without human input.
5. The exported Windows executable launches in headless smoke mode and exits successfully.
6. A hidden-window visual capture is inspected for framing, blank rendering, and HUD overlap.
