# Data format and preprocessing

See the [dataset inventory](dataset/README.md) for input files and their sources, and the [quick start](README.md#quick-start) for preparation and run commands.

## Preparation

`prepare_causample_data` imports the labeled TPC-C CSV into `dataset/TPC_C_metrics_with_labels.mat`, decompressing the gzip first if needed. Online Boutique (OB) and Sock Shop (SS) MAT files are already prepared. Dataset paths are defined in [causample_dataset_config.m](src/causample_dataset_config.m).

| Dataset | Stored raw data: time × metrics | Prepared trace |
| --- | --- | --- |
| TPC-C | 11,611 × 76, labeled CSV metrics | First 11,600 observations, after filtering |
| OB | 721 × 58 | 54 retained metrics × 700 observations |
| SS | 721 × 59 | 54 retained metrics × 700 observations |

TPC-C's labeled CSV contains a timestamp, 76 numeric metrics, and `label1`/`label2`. The unlabeled CSV instead contains 77 metrics, including `bussiness_time`. The importer preserves `dataMatrix`, `columnNames`, `timestamps`, `label1`, `label2`, and the local `csvPath`; only the metric matrix enters the sampler.

## Preprocessing and timelines

Preprocessing removes metrics that contain NaN, are entirely zero, or are zero in more than half of the supplied raw observations. It selects the configured trace length, derives Cauchy anomaly labels, and normalizes each retained metric. Normalization uses the complete selected trace before the training/online split, as an offline replay preprocessing step.

For batch length `T` and training-window size `w`, self-embedding creates `w_size = T*w-T+1` overlapping training segments. Batch-local positions range from 1 to `T`; online original time equals enhanced time minus `(w_size-w)*T`.

For OB/SS, `X` is 54 × 700. The first 350 observations form training data. They produce 301 overlapping 50-step segments, followed by seven non-overlapping online batches, giving `X_e` shape 54 × 15,400. Repeated training entries in `X_e` are from self-embedding, not additional physical observations.

| Prepared variable | Meaning |
| --- | --- |
| `X`, `X_e` | Normalized original-time and enhanced-time metric matrices |
| `Labels_anomalies_X` | Per-metric spike/dip indicators on the original timeline |
| `Omega_Cauchy_large`, `Omega_Cauchy_small` | Spike/dip indicators whose union forms the labels |
| `X_min`, `X_max`, `X_max_min` | Per-metric metadata used to return to the original scale |
| `columnIDX`, `columnNames` | Retained metric indices and names |
| `T`, `W`, `W_size` in BARO MAT files | Saved settings: 50, 7, 301 |
| `SPIKE_LIMIT`, `DIP_LIMIT` in BARO MAT files | Saved thresholds: 0.92, 0.08 |

Raw preprocessing is exposed as `data = preprocess_metric_data(dataMatrix, columnNames, dataset, params)`; it does not modify the caller's variables. The loader aligns names using retained indices. Only complete online batches enter `X_e`; the bundled inputs meet this requirement. Do not change `T`/`w` for prepared MAT files without rebuilding their embedded data.

See the README for [input checks](README.md#input-checks), [parameter settings](README.md#parameters), and [outputs and evaluation](README.md#outputs-and-evaluation).
