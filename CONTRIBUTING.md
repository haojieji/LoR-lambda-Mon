# Contributing

This project accompanies a research paper. Keep changes reproducible and make the relationship between the paper and implementation clear.

## Before opening a pull request

1. Run the lightweight validation:
   ```matlab
   cd src
   prepare_causample_data
   validate_causample('tpc_c')
   validate_causample('online_boutique')
   validate_causample('sock_shop')
   test_causample
   ```
2. If you changed the algorithm, run the affected datasets through the public runner and report the dataset and parameters used:
   ```matlab
   results = CauSample('tpc_c');
   ```
3. Record which checks were actually run and any checks that could not be run. Validation and smoke checks do not establish full experimental results.
4. Update [README.md](README.md), the [component mapping](docs/algorithm_overview.md), or the [source guide](src/README.md) when behavior, inputs, outputs, or parameters change.

## Code style

- Keep shared parameters in [causample_config.m](src/causample_config.m) and dataset-specific keys, paths, sizes, and overrides in [causample_dataset_config.m](src/causample_dataset_config.m), shared by the runner and validator.
- Keep [causample_pipeline.m](src/causample_pipeline.m) focused on orchestration and use the component names recorded in the [paper mapping](docs/algorithm_overview.md). Preserve the three separate Anomaly Detector functions and distinguish offline Anomaly Sampler training from prediction. Explain mathematical symbols in function headers or nearby comments.
- Add a short header comment to each new MATLAB function.
- Preserve third-party attribution, copyright, and license notices when changing helper code.
- Avoid committing generated `.mat`, `.fig`, `.log`, or result files.

## Documentation style

Write for readers who are not already familiar with the paper:

- Define symbols before using them.
- Explain whether a script is for reproduction, validation, or data conversion.
- Link code files to the paper concept they implement.
- Use `tpc_c` in examples and **TPC-C** in prose. Retain `oltp` only as a documented compatibility alias; the [dataset inventory](dataset/README.md#naming-compatibility) records earlier filenames.
- Keep scope and provenance explicit: the bundled BARO traces are selected preprocessed subsets, and validation or refactoring alone does not establish complete paper reproduction.
