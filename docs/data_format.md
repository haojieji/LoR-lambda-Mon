# Dataset format

The repository tracks CSV files because they are readable and diffable.  MATLAB `.mat` files are ignored by Git and can be regenerated.

## Bundled files

| File | Purpose |
| --- | --- |
| `dataset/combined_metrics_510_608.csv` | Raw metric time series without anomaly labels |
| `dataset/combined_metrics_510_608_with_labels.csv` | Metric time series plus `label1` and `label2` |
| `dataset/fault_timeline_510_608.csv` | Fault-injection events used during collection |
| `dataset/*.png` | Dataset/testbed visualizations for the README |

## Required MAT variables

`src/data_preprocess.m` expects these variables after loading `dataset/mysql_510_608_withLabels.mat`:

| Variable | Shape/type | Description |
| --- | --- | --- |
| `dataMatrix` | time-by-metric numeric matrix | Metric values only; timestamp and labels excluded |
| `columnNames` | string/cell array | Either metric names or the full CSV header |
| `timestamps` | vector/cell array | Original timestamps, saved for traceability |
| `label1` | vector | Fault-injection interval labels from the CSV |
| `label2` | vector | Anomaly labels from the CSV |

## Regenerate the MAT file

From MATLAB:

```matlab
cd('path/to/LoR-lambda-Mon/src')
import_dataset_from_csv
```

This reads `../dataset/combined_metrics_510_608_with_labels.csv` and writes `../dataset/mysql_510_608_withLabels.mat`.

## Custom dataset checklist

For a new dataset, keep the same broad layout:

1. First column: timestamp.
2. Middle columns: numeric metrics.
3. Last two columns: labels (use zeros if labels are unavailable).
4. No missing values in metrics you want to keep; preprocessing drops metrics containing `NaN`.
5. At least `T*w` samples, where defaults are `T = 100` and `w = 23`.

Then call:

```matlab
import_dataset_from_csv('path/to/your_labeled_metrics.csv', 'path/to/output.mat')
```

Finally update `dataset.path` in `src/config.m` or pass your own data to `LoR_lambda_Mon` directly.
