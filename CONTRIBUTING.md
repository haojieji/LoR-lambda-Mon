# Contributing

Keep changes traceable to the paper's components and report which checks were run.

- Follow the README's [input checks](README.md#input-checks) and report their results.
- For algorithm changes, run affected datasets through `CauSample` and report the commit, configuration, random seed, MATLAB environment, and results.
- Keep configuration changes consistent with the README's [parameter settings](README.md#parameters).
- Explain each function's purpose, important dimensions, and time coordinates briefly; avoid repeating its full signature in comments.
- Keep the three Anomaly Detector entry points separate. Preserve third-party licenses and attribution.
- Keep [output and metric definitions](README.md#outputs-and-evaluation) in the README, data schemas and preprocessing in [data_format.md](data_format.md), implementation conventions in [algorithm_overview.md](algorithm_overview.md), and component mappings in the [source guide](src/README.md). Update the relevant document when behavior changes.
- Do not describe input checks or source cleanup as full experimental validation.
- Do not commit generated MAT files, plots, logs, or local results; the two bundled BARO MAT inputs are intentionally tracked.
