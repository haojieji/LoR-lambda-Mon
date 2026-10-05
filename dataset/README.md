# Dataset inventory

Use the compressed OLTP downloads below when downloading individual files.
Each `.csv.gz` is below 8 MB and decompresses to the exact original CSV.
The original CSV files are also retained in this directory.

| Dataset | Recommended file | Contents |
| --- | --- | --- |
| OLTP, labeled | [combined_metrics_510_608_with_labels.csv.gz](combined_metrics_510_608_with_labels.csv.gz) | 11,611 observations; timestamp + 76 metrics + `label1`/`label2` |
| OLTP, unlabeled | [combined_metrics_510_608.csv.gz](combined_metrics_510_608.csv.gz) | Companion raw metric trace |
| OLTP fault events | [fault_timeline_510_608.csv](fault_timeline_510_608.csv) | Fault-injection event timeline |
| Online Boutique | [BARO_OB_w7T50.mat](BARO_OB_w7T50.mat) | 721 × 58 stored raw matrix; 54 × 700 processed matrix |
| Sock Shop | [BARO_SS_w7T50.mat](BARO_SS_w7T50.mat) | 721 × 59 stored raw matrix; 54 × 700 processed matrix |

From the repository's `src` directory, run `prepare_causample_data` before
`results = CauSample('oltp');`. It decompresses the OLTP input if necessary
and generates `mysql_510_608_withLabels.mat`. Both BARO MAT files are already
tracked in the repository; no download or conversion is needed for them.
Run those inputs with `CauSample('online_boutique')` or `CauSample('sock_shop')`.

## BARO source and preprocessing

The OB/SS metric data originate from the
[BARO FSE 2024 artifact](https://github.com/phamquiluan/baro).
The released files are selected, preprocessed 700-step subsets, each with
54 retained metrics.

Each file includes the raw `dataMatrix`, normalized `X`, self-embedded `X_e`
(54 × 15,400), metric-selection indices, normalization metadata, and Cauchy
anomaly labels. Both use `T=50`, `W=7`, and saved thresholds 0.08/0.92.

The current evaluator uses per-metric Cauchy labels. These are distinct from
the original OLTP label columns and upstream BARO fault annotations. See
[dataset format and label protocol](../docs/data_format.md) for the exact
dimensions and preprocessing.
