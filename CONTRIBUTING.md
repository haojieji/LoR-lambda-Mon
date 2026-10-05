# Contributing

This project accompanies a research paper. Keep changes reproducible and make the relationship between the paper and implementation clear.

## Before opening a pull request

1. Run the lightweight validation:
   ```matlab
   cd src
   prepare_causample_data
   validate_causample('oltp')
   validate_causample('online_boutique')
   validate_causample('sock_shop')
   test_causample
   ```
2. If you changed the algorithm, run the affected datasets through the public runner and report the dataset and parameters used:
   ```matlab
   results = CauSample('oltp');
   ```
3. Record which checks were actually run and any checks that could not be run. Validation and smoke checks do not establish full experimental results.
4. Update [README.md](README.md), the [component mapping](docs/algorithm_overview.md), or the [source guide](src/README.md) when behavior, inputs, outputs, or parameters change.

## Code style

- Keep shared parameters in [causample_config.m](src/causample_config.m) and dataset-specific settings in [CauSample.m](src/CauSample.m).
- Use descriptive function names aligned with the paper's components. Explain mathematical symbols in function headers or nearby comments.
- Add a short header comment to each new MATLAB function.
- Preserve third-party attribution, copyright, and license notices when changing helper code.
- Avoid committing generated `.mat`, `.fig`, `.log`, or result files.

## Documentation style

Write for readers who are not already familiar with the paper:

- Define symbols before using them.
- Explain whether a script is for reproduction, validation, or data conversion.
- Link code files to the paper concept they implement.
