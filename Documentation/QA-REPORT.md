# MVP Alpha 0.1.0 QA Report

## Automated Coverage

- Headless editor import: pass, no stderr output.
- Simulation and state suite: `367/367` checks passing.
- Scene integration suite: `87/87` checks passing, no stderr output.
- Complete purchase, drone delivery, pot preparation, care, two offshoot harvests, propagation, sale, and save smoke path: pass.
- Consecutive drone orders: FIFO delivery order verified with two physical crates.
- Interrupted delivery recovery: a pending order survives a full scene restart, resumes flight, lands, and clears only after collection.
- Full reload: leaf balance, inventory, pending delivery data, continuous plant growth, mutations, and all twelve shelf slots persist.
- Save recovery: a deliberately corrupted primary JSON file falls back to the previous valid backup.
- Save protection: closing the application from the start menu leaves the existing greenhouse untouched.
- Input modes: fixed terminal camera from three approach positions, buffered exit during camera travel, `F` entry, ignored `E`, `Escape` exit, pause freeze, and movement restoration verified.

## Visual Review

- `1024x768`, `1280x720`, `1920x1080`, and `3440x1440` captures inspected for blank output, clipping, overlap, and readable controls.
- Compact 4:3 and ultrawide renders keep the terminal checkout, inventory, currency, objectives, and hotbar inside their intended bounds.
- Twelve species use distinct modeled silhouettes; no plant billboards are used.
- Growth emergence, watering stream, inherited variegation, propagated young plants, stressed foliage, prepared soil, and ready offshoot visuals were individually rendered and inspected.
- All eight soil and feed profiles use distinct, consistent icon accents across the terminal, inventory, and hotbar.
- Storage rows keep soil on brown lower pads and fertilizer on green upper pads; stored bags lie on individual slots.
- The first-person capsule is blocked by all five exterior wall runs while both the residential-wing opening and greenhouse doorway remain traversable.

## Performance

- GPU benchmark at `1920x1080`: `190.5 FPS` average, `8.477 ms` p95 frame time, `2,664` peak draw calls on an NVIDIA GeForce RTX 4060.
- The renderer remains Godot GL Compatibility for wider Windows support.

## Release Gate

The release is ready only when the final exported executable also completes the embedded headless smoke path with exit code `0` and the GitHub Actions build succeeds from a clean checkout.
