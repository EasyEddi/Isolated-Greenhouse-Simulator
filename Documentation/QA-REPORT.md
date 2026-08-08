# MVP Alpha 0.1.0 QA Report

## Automated Coverage

- Headless editor import: pass, no stderr output.
- Simulation and state suite: `577/577` checks passing.
- Scene integration suite: `92/92` checks passing, no stderr output.
- Complete purchase, drone delivery, pot preparation, care, two offshoot harvests, propagation, sale, and save smoke path: pass.
- Guided-shift completion: the complete smoke path advances every objective and reaches open-ended nursery play.
- Consecutive drone orders: FIFO delivery order verified with two physical crates.
- Interrupted delivery recovery: a pending order survives a full scene restart, resumes flight, lands, and clears only after collection.
- Full reload: leaf balance, inventory, pending delivery data, continuous plant growth, mutations, and all twelve shelf slots persist.
- Save recovery: a deliberately corrupted primary JSON file falls back to the previous valid backup.
- Save sanitization: valid-but-malformed JSON cannot restore unknown items, mutations, species, negative balances, invalid orders, or out-of-range plant state.
- Economy integrity: carts accept catalog stock only, deliveries grant the paid server-side order exactly once, and duplicate collection attempts grant nothing.
- Save protection: closing the application from the start menu leaves the existing greenhouse untouched.
- Input modes: fixed terminal camera from three approach positions, buffered exit during camera travel, `F` entry/reopen/exit, ignored `E`, `Escape` exit, pause freeze, and movement restoration verified.

## Visual Review

- `1024x768`, `1280x720`, `1920x1080`, and `3440x1440` captures inspected for blank output, clipping, overlap, and readable controls.
- Compact 4:3 and ultrawide renders keep the terminal checkout, inventory, currency, objectives, and hotbar inside their intended bounds.
- Sell mode hides all shop-only category and cart controls; returning to shop restores both without shifting or overlapping the terminal frame.
- Twelve species use distinct modeled silhouettes and unique SHA-256-verified model assets; no plant billboards are used.
- Growth emergence, watering stream, inherited variegation, propagated young plants, stressed foliage, prepared soil, and ready offshoot visuals were individually rendered and inspected.
- Live care readouts distinguish drought, dry, ideal, wet, and waterlogged soil while showing whether the applied soil and feed match the species profile.
- Matching fertilizer outperforms a mismatched feed, correct care recovers stressed plants, and mismatched fertilizer cannot drive offshoot production.
- Every launch species completes three repeated offshoot harvests within a one-hour simulated matching-care soak while preserving health and exact inventory accounting.
- Every plant GLB imports as a packed scene with rendered surfaces, at least 100 vertices, complete normals, indexed triangles, multiple authored materials, finite non-empty bounds, no non-finite positions, and multiple continuous-growth parts.
- All eight soil and feed profiles use distinct, consistent icon accents across the terminal, inventory, and hotbar.
- All eleven runtime sounds import with nonzero duration; offline PCM analysis confirms non-silent levels, consistent footsteps, and no clipping.
- Delivered starters and offshoots retain species-specific silhouettes; variegated stock keeps its mutation palette.
- The pause panel displays saved session time, harvest count, and leaf sales without overlapping controls at compact or standard resolutions.
- Storage rows keep soil on brown lower pads and fertilizer on green upper pads; stored bags lie on individual slots.
- The first-person capsule is blocked by all five exterior wall runs while both the residential-wing opening and greenhouse doorway remain traversable.

## Performance

- GPU benchmark at `1920x1080`: `190.5 FPS` average, `8.477 ms` p95 frame time, `2,664` peak draw calls on an NVIDIA GeForce RTX 4060.
- The renderer remains Godot GL Compatibility for wider Windows support.

## Packaged Candidate

- Local single-file Windows export: `110,557,680` bytes with product name `Isolated Greenhouse`, version `0.1.0.0`, EasyEddi company metadata, and the embedded leaf icon.
- The local packaged executable completes its own headless gameplay smoke path with exit code `0`.
- A clean Linux CI artifact was downloaded through the GitHub API, matched GitHub's reported byte size and SHA-256 digest, and completed the same Windows gameplay smoke path.
- The packaged executable rendered and saved the full supplies-terminal view through the NVIDIA GPU path, confirming that release resources and UI are present outside the editor.

## Release Gate

The release is ready only when the final exported executable also completes the embedded headless smoke path with exit code `0` and the GitHub Actions build succeeds from a clean checkout.
