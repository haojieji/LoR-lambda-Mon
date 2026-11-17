# Contributing

Keep changes traceable to the paper's components and report which checks were run.

- Use `validate_causample`/`test_causample` for input checks. These do not run the full algorithm.
- For algorithm changes, run affected datasets through `CauSample` and report the commit, configuration, random seed, MATLAB environment, and results.
- Keep defaults in `src/causample_config.m` and dataset overrides in `src/causample_dataset_config.m`.
- Explain each function's purpose, important dimensions, and time coordinates briefly; avoid repeating its full signature in comments.
- Keep the three Anomaly Detector entry points separate. Preserve third-party licenses and attribution.
- Update the [source map](src/README.md) or [implementation conventions](algorithm_overview.md) when behavior changes. Do not describe input checks or source cleanup as full experimental validation.
- Do not commit generated MAT files, plots, logs, or local results; the two bundled BARO MAT inputs are intentionally tracked.
