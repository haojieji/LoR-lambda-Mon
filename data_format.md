# Data format and evaluation

The repository includes a TPC-C trace and selected preprocessed Online Boutique (OB) and Sock Shop (SS) traces from the [BARO artifact](https://github.com/phamquiluan/baro). See the [dataset inventory](dataset/README.md) for downloads.

## Preparation

From `src`, run `prepare_causample_data` before `CauSample('tpc_c')`. It imports the labeled CSV into `dataset/TPC_C_metrics_with_labels.mat`, decompressing the gzip first if needed. OB/SS MAT files are already prepared. The canonical keys are `tpc_c`, `online_boutique`, and `sock_shop`; `oltp` is a TPC-C alias.

| Dataset | Stored raw data: time × metrics | Evaluated trace | Default `T`, `w` |
| --- | --- | --- | --- |
| TPC-C | 11,611 × 76, labeled CSV metrics | First 11,600 observations, after filtering | 100, 23 |
| OB | 721 × 58 | 54 retained metrics × 700 observations | 50, 7 |
| SS | 721 × 59 | 54 retained metrics × 700 observations | 50, 7 |

TPC-C's labeled CSV contains a timestamp, 76 numeric metrics, and `label1`/`label2`. The unlabeled CSV instead contains 77 metrics, including `bussiness_time`. The importer preserves `dataMatrix`, `columnNames`, `timestamps`, `label1`, `label2`, and the local `csvPath`; only the metric matrix enters the sampler.

## Preprocessing and timelines

Preprocessing removes metrics that contain NaN, are entirely zero, or are zero in more than half of the supplied raw observations. It selects the configured trace length, derives Cauchy anomaly labels, and normalizes each retained metric. Normalization uses the complete selected trace before the training/online split, as an offline replay preprocessing step.

For OB/SS, `X` is 54 × 700. The first 350 observations form training data. They produce 301 overlapping 50-step segments, followed by seven non-overlapping online batches, giving `X_e` shape 54 × 15,400. Repeated training entries in `X_e` are from self-embedding, not additional physical observations. Online original time and enhanced time differ by `(w_size-w)*T`.

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

## Evaluation labels

The evaluator uses **per-metric Cauchy labels**, not directly the original TPC-C label columns, fault timeline, or upstream BARO fault annotations. It detects anomalies in the reconstructed output and pools TP, FP, and FN across metrics and post-training time points for precision, recall, and F1. Sampling/NMAE are also evaluated after training; NMAE uses the original metric scale.

`params.SPIKE_LIMIT`/`DIP_LIMIT` affect online detection and labels generated from raw TPC-C data. They do not replace the saved OB/SS labels or the evaluator's fixed 0.08/0.92 thresholds. Changing detection settings therefore does not redefine the entire evaluation protocol. The reported sampling ratio also inherits the [retained coordinate limitation](algorithm_overview.md#implementation-conventions-and-retained-limitations).

## Input checks

```matlab
validate_causample('tpc_c')
validate_causample('online_boutique')
validate_causample('sock_shop')
```

These checks load the inputs and verify basic dimensions; they do not run the algorithm or validate a paper result. Data checksums are in [SHA256SUMS](SHA256SUMS). Dataset paths and overrides are shared by the runner and validator through [causample_dataset_config.m](src/causample_dataset_config.m).
