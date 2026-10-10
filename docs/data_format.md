# Dataset format and preparation

The artifact includes a TPC-C trace and two preprocessed microservice subsets.
The two BARO MAT files are tracked in Git and ready to load. The TPC-C MAT file
is generated locally from the bundled CSV.

From the repository's `src` directory, run:

```matlab
prepare_causample_data
CauSample('tpc_c')
CauSample('online_boutique')
CauSample('sock_shop')
```

`prepare_causample_data` decompresses the labeled TPC-C CSV when necessary and imports
it into `dataset/TPC_C_metrics_with_labels.mat`. For individual downloads, prefer
the `.csv.gz` files linked in [the dataset inventory](../dataset/README.md);
each is below 8 MB. Decompression reproduces the corresponding original CSV
byte for byte. The original CSV files remain available.

## TPC-C

`TPC_C_metrics_with_labels.csv` contains 11,611 observations and
79 columns: a timestamp, 76 numeric metrics, then `label1` and `label2`.
`TPC_C_metrics.csv` contains the same number of observations and 78 columns:
a timestamp and 77 metrics, including `bussiness_time`, which is absent from
the labeled trace. Thus, the labeled file is not merely the unlabeled file
with labels appended. `TPC_C_fault_timeline.csv` records the fault-injection
events. The canonical runner key is `tpc_c`; `oltp` remains a compatibility
alias. The [dataset inventory](../dataset/README.md#naming-compatibility) maps
earlier filenames to these names.

The importer preserves these fields:

| MAT variable | Content |
| --- | --- |
| `dataMatrix` | 11,611 × 76, time by metric; excludes timestamp and labels |
| `columnNames` | CSV header |
| `timestamps` | Original timestamp column |
| `label1`, `label2` | Original label columns |
| `csvPath` | Local import source path |

The TPC-C runner preprocesses the first 11,600 observations with `T=100` and
`w=23`. It filters metrics, constructs per-metric Cauchy anomaly labels,
normalizes each retained metric, and builds the self-embedded matrix `X_e`.
To rebuild the MAT file explicitly, run `import_dataset_from_csv` from `src`.

## Bundled BARO subsets

The OB and SS metric data originate from the
[BARO FSE 2024 artifact](https://github.com/phamquiluan/baro).
The bundled MAT files contain selected, preprocessed 700-step subsets.

| MAT file | `dataMatrix` (time × original metrics) | `X` (retained metrics × time) | `X_e` |
| --- | --- | --- | --- |
| `BARO_OB_w7T50.mat` | 721 × 58 | 54 × 700 | 54 × 15,400 |
| `BARO_SS_w7T50.mat` | 721 × 59 | 54 × 700 | 54 × 15,400 |

Both files store `T=50`, `W=7`, and `W_size=301`. Preprocessing removes metrics
that are entirely zero, contain NaN, or are zero in more than half of the
721 observations. It then uses the first 700 observations and applies
per-metric min-max normalization to obtain `X`.
`X_e` contains 301 overlapping windows of length 50 from the first 350
observations, followed by seven non-overlapping batches of length 50.
Its 15,400 columns include repeated observations introduced by embedding.

| Additional MAT variable | Content |
| --- | --- |
| `Labels_anomalies_X` | 54 × 700 per-metric Cauchy anomaly flags |
| `Omega_Cauchy_large`, `Omega_Cauchy_small` | Spike and dip flags; their logical OR forms the labels |
| `X_min`, `X_max`, `X_max_min` | Per-metric normalization metadata |
| `columnIDX` | One-based indices of the retained metrics |
| `columnNames` | Stored metric names; the runner aligns them using `columnIDX` |
| `SPIKE_LIMIT`, `DIP_LIMIT` | Saved Cauchy thresholds: 0.92 and 0.08 |

## Label protocol

The original TPC-C `label1`/`label2` columns and fault timeline are preserved
for inspection. The current runner evaluates anomaly preservation against
the **per-metric Cauchy labels** in `Labels_anomalies_X`, rather than directly
against those original label columns or upstream BARO fault annotations.
It applies the Cauchy detector to the reconstructed output, then pools TP,
FP, and FN across metrics and post-training time points to compute precision,
recall, and F1. The bundled BARO labels and current evaluator use thresholds
0.08/0.92.

## Validation

```matlab
validate_causample('tpc_c')
validate_causample('online_boutique')
validate_causample('sock_shop')
```

These checks validate file availability and required matrix dimensions. The [public runner](../src/CauSample.m) and validator share dataset keys, paths, and settings through [causample_dataset_config.m](../src/causample_dataset_config.m); [preprocess_metric_data.m](../src/preprocess_metric_data.m) prepares raw TPC-C data, and [evaluate_anomaly_preservation.m](../src/evaluate_anomaly_preservation.m) implements the anomaly evaluation described above.
