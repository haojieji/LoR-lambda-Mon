# Dataset format

The project supports three datasets through the same MATLAB entry point:

```matlab
LoRlambda_Mon                  % OLTP
LoRlambda_Mon('online_boutique')
LoRlambda_Mon('sock_shop')
```

MATLAB `.mat` files are ignored by Git because they can be regenerated or copied locally.

## Supported datasets

| Name | Runner argument | Default MAT file | Format |
| --- | --- | --- | --- |
| OLTP | `oltp` | `dataset/mysql_510_608_withLabels.mat` | Raw metrics plus labels |
| Online Boutique | `online_boutique` | `dataset/BARO_OB_w7T50.mat` | Preprocessed BARO MAT |
| Sock Shop | `sock_shop` | `dataset/BARO_SS_w7T50.mat` | Preprocessed BARO MAT |

## OLTP CSV and MAT format

The OLTP CSV layout is:

1. First column: timestamp.
2. Middle columns: numeric metrics.
3. Last two columns: `label1` and `label2`.

Regenerate the default OLTP MAT file from MATLAB:

```matlab
cd('path/to/LoR-lambda-Mon/src')
import_dataset_from_csv
```

The generated MAT file stores:

| Variable | Shape/type | Description |
| --- | --- | --- |
| `dataMatrix` | time-by-metric numeric matrix | Metric values only; timestamp and labels excluded |
| `columnNames` | string/cell array | Full CSV header or metric names |
| `timestamps` | vector/cell array | Original timestamps |
| `label1` | vector | Fault-injection interval labels |
| `label2` | vector | Anomaly labels |

`data_preprocess.m` then filters metrics, creates Cauchy anomaly labels, normalizes metrics, and builds `X_e`.

## BARO CSV and MAT format

The BARO `simple_data.csv` layout is:

1. First column: timestamp.
2. Remaining columns: numeric metrics.
3. No `label1` / `label2` columns are required.

Convert a BARO CSV to a directly runnable MAT file:

```matlab
import_dataset_from_csv('path/to/simple_data.csv', ...
    '../dataset/BARO_OB_w7T50.mat', ...
    'baro')
```

BARO import uses `T = 50`, `w = 7`, and `max_time_steps = 700` by default. The generated MAT file includes the preprocessed variables required by `LoRlambda_Mon`:

| Variable | Description |
| --- | --- |
| `X` | normalized metric matrix |
| `X_e` | enhanced sliding-window matrix |
| `Labels_anomalies_X` | Cauchy-based anomaly labels |
| `X_min`, `X_max`, `X_max_min` | normalization metadata |
| `columnIDX`, `columnNames` | selected metric indices and labels |
| `dataMatrix`, `timestamps` | original data retained for traceability |

## Validation

Run these checks after adding or regenerating data files:

```matlab
validate_lorlambda_mon('oltp')
validate_lorlambda_mon('online_boutique')
validate_lorlambda_mon('sock_shop')
```

The validator checks file existence, required variables, and key dimensions such as `size(X,1) == numel(columnNames)` and `size(X_e,1) == size(X,1)`.
