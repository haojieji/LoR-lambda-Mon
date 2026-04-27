# Contributing

Thanks for improving LoRlambda-Mon.  This project accompanies a research paper, so please keep changes reproducible and easy to audit.

## Before opening a pull request

1. Run the lightweight validation:
   ```matlab
   cd src
   validate_lorlambda_mon
   ```
2. If you changed the algorithm, run the full experiment:
   ```matlab
   cd src
   LoRlambda_Mon
   ```
3. Update `README.md` or `docs/` when behavior, inputs, outputs, or parameters change.

## Code style

- Keep experiment constants in `src/config.m`.
- Prefer descriptive variable names for new code; preserve legacy variable names only where they are part of the paper implementation.
- Add a short header comment to each new MATLAB function.
- Avoid committing generated `.mat`, `.fig`, `.log`, or result files.

## Documentation style

Write for readers who are not already familiar with the paper:

- Define symbols before using them.
- Explain whether a script is for reproduction, validation, or data conversion.
- Link code files to the paper concept they implement.
