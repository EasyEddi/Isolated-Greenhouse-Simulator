# Isolated Greenhouse

Isolated Greenhouse is a calm first-person plant-care and greenhouse-management simulator. It is a standalone reimplementation focused on one polished loop: order supplies, receive a drone delivery, prepare species-appropriate pots, grow and care for plants, harvest offshoots, and sell them to expand the nursery.

## Play

The packaged Windows build is produced at `build/IsolatedGreenhouse_0.1.0.exe`.

Core controls:

- `WASD`: Move
- Mouse: Look
- `E`: Interact / use selected item
- `F`: Use or leave the shop terminal
- `1`-`5` or mouse wheel: Select hotbar item
- `Tab`: Open inventory and plant journal
- `Esc`: Pause or close the current screen

## Development

The project targets Godot `4.6.3-stable` and uses GDScript. It is intentionally buildable and testable from the command line.

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --export-release "Windows Desktop" build/IsolatedGreenhouse_0.1.0.exe
```

See [Documentation/DESIGN-BIBLE.md](Documentation/DESIGN-BIBLE.md) for the gameplay scope and [Documentation/TECHNICAL.md](Documentation/TECHNICAL.md) for architecture and validation.
