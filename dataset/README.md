# Dataset inventory

Use the compressed TPC-C downloads below when downloading individual files.
Each `.csv.gz` is below 8 MB and decompresses to the exact original CSV.
The original CSV files are also retained in this directory.

| Dataset | Recommended file | Contents |
| --- | --- | --- |
| TPC-C, labeled | [TPC_C_metrics_with_labels.csv.gz](TPC_C_metrics_with_labels.csv.gz) | 11,611 observations; timestamp + 76 metrics + `label1`/`label2` |
| TPC-C, unlabeled | [TPC_C_metrics.csv.gz](TPC_C_metrics.csv.gz) | 11,611 observations; timestamp + 77 metrics, including `bussiness_time` |
| TPC-C fault events | [TPC_C_fault_timeline.csv](TPC_C_fault_timeline.csv) | Fault-injection event timeline |
| Online Boutique | [BARO_OB_w7T50.mat](BARO_OB_w7T50.mat) | 721 × 58 stored raw matrix; 54 × 700 processed matrix |
| Sock Shop | [BARO_SS_w7T50.mat](BARO_SS_w7T50.mat) | 721 × 59 stored raw matrix; 54 × 700 processed matrix |

From the repository's `src` directory, run `prepare_causample_data` before
`results = CauSample('tpc_c');`. It decompresses the labeled TPC-C input if necessary
and generates `TPC_C_metrics_with_labels.mat`. Both BARO MAT files are already
tracked in the repository; no download or conversion is needed for them.
Run those inputs with `CauSample('online_boutique')` or `CauSample('sock_shop')`.

The labeled trace omits the unlabeled trace's `bussiness_time` metric and
includes two label columns; it is not simply the same metric matrix with
labels appended. The runner imports the labeled trace. The TPC-C plots are
[TPC_C_metrics.png](TPC_C_metrics.png) and
[TPC_C_metrics_with_labels.png](TPC_C_metrics_with_labels.png).

## Naming compatibility

`tpc_c` is the canonical dataset key and is displayed as **TPC-C**. The earlier
runner key `oltp` remains a compatibility alias. Earlier artifact filenames map
to the current names below; the OB/SS filenames are unchanged. These renames
do not change the bundled data or image contents.

| Earlier filename | Current filename |
| --- | --- |
| `combined_metrics_510_608.csv[.gz]` | `TPC_C_metrics.csv[.gz]` |
| `combined_metrics_510_608_with_labels.csv[.gz]` | `TPC_C_metrics_with_labels.csv[.gz]` |
| `fault_timeline_510_608.csv` | `TPC_C_fault_timeline.csv` |
| `mysql_510_608_withLabels.mat` (generated) | `TPC_C_metrics_with_labels.mat` (generated) |
| `time_series_visualization_510_608.png` | `TPC_C_metrics.png` |
| `time_series_visualization_510_608_withLabels.png` | `TPC_C_metrics_with_labels.png` |

## BARO source and preprocessing

The OB/SS metric data originate from the
[BARO FSE 2024 artifact](https://github.com/phamquiluan/baro).
The released files are selected, preprocessed 700-step subsets, each with
54 retained metrics.

Each file includes the raw `dataMatrix`, normalized `X`, self-embedded `X_e`
(54 × 15,400), metric-selection indices, normalization metadata, and Cauchy
anomaly labels. Both use `T=50`, `W=7`, and saved thresholds 0.08/0.92.

The current evaluator uses per-metric Cauchy labels. These are distinct from
the original TPC-C label columns and upstream BARO fault annotations. See
[dataset format and label protocol](../docs/data_format.md) for the exact
dimensions and preprocessing.
