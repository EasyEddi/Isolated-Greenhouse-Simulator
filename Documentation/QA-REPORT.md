# MVP Alpha 0.1.0 QA Report

## Automated Coverage

- Headless editor import: pass, no stderr output.
- Simulation and state suite: `355/355` checks passing.
- Scene integration suite: `67/67` checks passing, no stderr output.
- Complete purchase, drone delivery, pot preparation, care, harvest, sale, and save smoke path: pass.
- Consecutive drone orders: FIFO delivery order verified with two physical crates.
- Full reload: leaf balance, inventory, pending delivery data, continuous plant growth, mutations, and all twelve shelf slots persist.
- Input modes: fixed terminal camera from three approach positions, `F` entry, ignored `E`, `Escape` exit, pause freeze, and movement restoration verified.

## Visual Review

- `1920x1080` and `1280x720` captures inspected for blank output, clipping, overlap, and readable controls.
- Twelve species use distinct modeled silhouettes; no plant billboards are used.
- Growth emergence, watering stream, variegation, stressed foliage, prepared soil, and ready offshoot visuals were individually rendered and inspected.
- Storage rows keep soil on brown lower pads and fertilizer on green upper pads; stored bags lie on individual slots.

## Performance

- GPU benchmark at `1920x1080`: `190.5 FPS` average, `8.477 ms` p95 frame time, `2,664` peak draw calls on an NVIDIA GeForce RTX 4060.
- The renderer remains Godot GL Compatibility for wider Windows support.

## Release Gate

The release is ready only when the final exported executable also completes the embedded headless smoke path with exit code `0` and the GitHub Actions build succeeds from a clean checkout.
